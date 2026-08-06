#!/usr/bin/env bash
# Ubuntu bootstrap — full post-install setup for a fresh machine.
#
# Default (no flags) does everything:
#   1. apt update + upgrade
#   2. Install packages listed in ubuntu/packages.txt
#   3. Install WezTerm (native Linux; skipped on WSL)
#   4. Install third-party CLIs (herdr, Claude Code, Codex, Grok Build)
#   5. Link dotfiles via ../install.sh
#   6. Prompt for git identity if ~/.gitconfig.local is missing
#   7. SSH key for this machine (generate if missing; optional gh upload)
#
# Safe: idempotent packages; install.sh backs up real files before linking.
# Tool installers are vendor curl|bash scripts; auth is never automated.
# SSH private keys are never stored in the repo.
#
# Usage:
#   ./setup.sh                      # preferred entry point (same as this)
#   ./ubuntu/bootstrap.sh           # everything
#   ./ubuntu/bootstrap.sh --dry-run # print plan, change nothing
#   ./ubuntu/bootstrap.sh --packages-only   # skip wezterm, tools, linking, ssh
#   ./ubuntu/bootstrap.sh --no-tools        # skip herdr/claude/codex/grok
#   ./ubuntu/bootstrap.sh --no-wezterm      # skip WezTerm apt install
#   ./ubuntu/bootstrap.sh --no-ssh-key      # skip SSH key generate/upload
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkg_file="$repo/ubuntu/packages.txt"
dry_run=0
do_link=1    # default: do everything
do_tools=1
do_wezterm=1
do_ssh=1

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)       dry_run=1 ;;
    --packages-only)    do_link=0; do_tools=0; do_wezterm=0; do_ssh=0 ;;
    --no-tools)         do_tools=0 ;;
    --no-wezterm)       do_wezterm=0 ;;
    --no-ssh-key)       do_ssh=0 ;;
    --link)             do_link=1 ;;  # kept for older docs / habits
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run] [--packages-only] [--no-tools] [--no-wezterm] [--no-ssh-key]" >&2
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

# Drop names that are not in any configured apt suite (e.g. Ubuntu-only on Debian).
# One missing package must not abort the whole install.
if [ "${#packages[@]}" -gt 0 ] && [ "$dry_run" -eq 0 ]; then
  available=()
  missing=()
  for pkg in "${packages[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    say "warning: not in apt cache (skipped):"
    printf '  - %s\n' "${missing[@]}"
  fi
  packages=("${available[@]}")
fi

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

# ── 3. WezTerm (official apt repo; native Linux only) ────────────────────────
if [ "$do_wezterm" -eq 1 ]; then
  say ""
  if [ "$dry_run" -eq 1 ]; then
    "$repo/ubuntu/install-wezterm.sh" --dry-run
  else
    set +e
    "$repo/ubuntu/install-wezterm.sh"
    set -e
  fi
fi

# ── 4. Third-party tools (official installers) ───────────────────────────────
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

# ── 5. Link configs (default on) ─────────────────────────────────────────────
if [ "$do_link" -eq 1 ]; then
  say ""
  say "== link dotfiles (install.sh) =="
  if [ "$dry_run" -eq 1 ]; then
    "$repo/install.sh" --dry-run
  else
    "$repo/install.sh"
  fi
fi

# ── 6. Git identity (once per machine) ───────────────────────────────────────
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

# ── 7. SSH key for this machine (never committed) ────────────────────────────
if [ "$do_ssh" -eq 1 ]; then
  say ""
  if [ "$dry_run" -eq 1 ]; then
    "$repo/ubuntu/setup-ssh.sh" --dry-run
  else
    set +e
    "$repo/ubuntu/setup-ssh.sh"
    set -e
  fi
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
  say "  claude / codex / grok   # each opens its own login on first use"
  say "  # gh auth: offered during SSH step if not already logged in"
fi
