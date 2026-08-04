#!/usr/bin/env bash
# Ubuntu bootstrap — full post-install setup for a fresh machine.
#
# Default (no flags) does everything:
#   1. apt update + upgrade
#   2. Install packages listed in ubuntu/packages.txt
#   3. Install third-party CLIs (herdr, Claude Code, Codex, Grok Build)
#   4. Link dotfiles via ../install.sh
#   5. Prompt for git identity if ~/.gitconfig.local is missing
#
# Safe: idempotent packages; install.sh backs up real files before linking.
# Tool installers are vendor curl|bash scripts; auth is never automated.
#
# Usage:
#   ./setup.sh                      # preferred entry point (same as this)
#   ./ubuntu/bootstrap.sh           # everything
#   ./ubuntu/bootstrap.sh --dry-run # print plan, change nothing
#   ./ubuntu/bootstrap.sh --packages-only   # skip config linking
#   ./ubuntu/bootstrap.sh --no-tools        # skip herdr/claude/codex/grok
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkg_file="$repo/ubuntu/packages.txt"
dry_run=0
do_link=1    # default: do everything
do_tools=1

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)       dry_run=1 ;;
    --packages-only)    do_link=0; do_tools=0 ;;
    --no-tools)         do_tools=0 ;;
    --link)             do_link=1 ;;  # kept for older docs / habits
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run] [--packages-only] [--no-tools]" >&2
      exit 2
      ;;
  esac
done

say() { printf '%s\n' "$*"; }
run() {
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> $*"
  else
    eval "$@"
  fi
}

# ── Guard: Ubuntu / Debian family only ───────────────────────────────────────
if [ ! -f /etc/os-release ]; then
  say "error: /etc/os-release missing — not a Linux distro we know how to bootstrap."
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
  ubuntu:*|debian:*|*:ubuntu*|*:debian*) ;;
  *)
    say "error: this script targets Ubuntu/Debian (got ID=${ID:-unknown})."
    exit 1
    ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
  say "error: apt-get not found."
  exit 1
fi

say "== Ubuntu setup ($PRETTY_NAME) =="
if [ "$dry_run" -eq 1 ]; then
  say "(dry-run mode — no changes will be made)"
fi
say ""

# ── 1. Update + upgrade ──────────────────────────────────────────────────────
say "== apt update =="
run "sudo apt-get update"

say ""
say "== apt upgrade =="
run "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

# ── 2. Packages from packages.txt ────────────────────────────────────────────
say ""
say "== install packages ($pkg_file) =="
if [ ! -f "$pkg_file" ]; then
  say "error: package list missing: $pkg_file"
  exit 1
fi

mapfile -t packages < <(
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$pkg_file" \
    | grep -v '^$'
)

if [ "${#packages[@]}" -eq 0 ]; then
  say "warning: package list is empty — skipping install."
else
  say "packages (${#packages[@]}):"
  printf '  - %s\n' "${packages[@]}"
  # shellcheck disable=SC2086
  run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${packages[*]}"
fi

# fd-find installs as `fdfind` on Debian/Ubuntu; offer a user-local `fd` name
if [ "$dry_run" -eq 1 ]; then
  say ""
  say "== symlink fdfind -> ~/.local/bin/fd (if needed) =="
  say "  DRY-RUN> mkdir -p \"\$HOME/.local/bin\" && ln -sf \$(command -v fdfind) \"\$HOME/.local/bin/fd\""
elif command -v fdfind >/dev/null 2>&1 && [ ! -e "$HOME/.local/bin/fd" ]; then
  say ""
  say "== symlink fdfind -> ~/.local/bin/fd =="
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# ── 3. Third-party tools (official installers) ───────────────────────────────
if [ "$do_tools" -eq 1 ]; then
  say ""
  if [ "$dry_run" -eq 1 ]; then
    "$repo/ubuntu/tools.sh" --dry-run
  else
    # Don't abort the whole bootstrap if one vendor script fails.
    set +e
    "$repo/ubuntu/tools.sh"
    set -e
  fi
fi

# ── 4. Link configs (default on) ─────────────────────────────────────────────
if [ "$do_link" -eq 1 ]; then
  say ""
  say "== link dotfiles (install.sh) =="
  if [ "$dry_run" -eq 1 ]; then
    "$repo/install.sh" --dry-run
  else
    "$repo/install.sh"
  fi
fi

# ── 5. Git identity (once per machine) ───────────────────────────────────────
gitconfig_local="$HOME/.gitconfig.local"
if [ -f "$gitconfig_local" ]; then
  say ""
  say "== git identity =="
  say "ok    $gitconfig_local already exists"
elif [ "$dry_run" -eq 1 ]; then
  say ""
  say "== git identity =="
  say "  DRY-RUN> would prompt for name/email -> $gitconfig_local"
elif [ -t 0 ]; then
  say ""
  say "== git identity =="
  say "Create $gitconfig_local (not committed to the repo)."
  printf "  Your name:  "
  read -r git_name
  printf "  Your email: "
  read -r git_email
  if [ -n "$git_name" ] && [ -n "$git_email" ]; then
    cat > "$gitconfig_local" << EOF
[user]
	name  = $git_name
	email = $git_email
EOF
    say "wrote $gitconfig_local"
  else
    say "skipped (empty name or email). Create it later with:"
    say "  [user]"
    say "      name  = Your Name"
    say "      email = you@example.com"
  fi
else
  say ""
  say "== git identity =="
  say "skip  no TTY — create $gitconfig_local manually when you can"
fi

# ── 6. SSH key reminder (never generate/commit keys here) ────────────────────
say ""
say "== ssh keys =="
ssh_key=""
for cand in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_rsa"; do
  if [ -f "$cand" ]; then
    ssh_key="$cand"
    break
  fi
done
if [ -n "$ssh_key" ]; then
  say "ok    found $ssh_key"
elif [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> would remind to create ~/.ssh/id_ed25519 if missing"
else
  say "none  no default SSH private key found."
  say "      Create one when you want GitHub SSH / remote login:"
  say "        ssh-keygen -t ed25519 -C \"you@example.com\""
  say "        eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
  say "        gh auth login   # or paste ~/.ssh/id_ed25519.pub into GitHub"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
say ""
if [ "$dry_run" -eq 1 ]; then
  say "Dry run complete — no changes made."
  say "Apply with:  $repo/setup.sh"
else
  say "Done. Everything this repo manages is set up."
  say ""
  say "Reload your shell:"
  say "  exec bash -l"
  say ""
  say "First nvim launch bootstraps plugins (lazy.nvim) — needs network once."
  say ""
  say "Optional next (interactive — never put tokens in this repo):"
  say "  gh auth login"
  say "  claude / codex / grok   # each opens its own login on first use"
fi
