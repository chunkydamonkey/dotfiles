#!/usr/bin/env bash
# Ubuntu bootstrap — full post-install setup for a fresh machine.
#
# Flow:
#   1. apt update + upgrade
#   2. Core packages from ubuntu/packages.txt (always)
#   3. Optional tools — interactive prompts (Docker, WezTerm, AI CLIs, …)
#   4. Link configs via ../install.sh
#   5. Git identity if ~/.gitconfig.local is missing
#   6. SSH key for this machine (generate if missing; optional gh upload)
#
# Safe: idempotent packages; install.sh backs up real files before linking.
# Optional installs never force; missing + no TTY → skip (use --yes to auto-accept
# recommended defaults). SSH private keys are never stored in the repo.
#
# Usage:
#   ./setup.sh                         # preferred entry point
#   ./ubuntu/bootstrap.sh --dry-run
#   ./ubuntu/bootstrap.sh --yes        # auto-yes recommended optionals
#   ./ubuntu/bootstrap.sh --no-optional
#   ./ubuntu/bootstrap.sh --packages-only
#   ./ubuntu/bootstrap.sh --no-ssh-key
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkg_file="$repo/ubuntu/packages.txt"
dry_run=0
do_link=1
do_optional=1
do_ssh=1
optional_args=()

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)
      dry_run=1
      optional_args+=(--dry-run)
      ;;
    -y|--yes)
      optional_args+=(--yes)
      ;;
    --no-optional|--no-tools|--no-wezterm)
      # --no-tools / --no-wezterm kept as aliases for older muscle memory
      do_optional=0
      ;;
    --packages-only)
      do_link=0
      do_optional=0
      do_ssh=0
      ;;
    --no-ssh-key) do_ssh=0 ;;
    --link)       do_link=1 ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run] [--yes] [--no-optional] [--packages-only] [--no-ssh-key]" >&2
      exit 2
      ;;
  esac
done

# Non-interactive (no TTY): don't block on prompts unless --yes was passed
if [ "$do_optional" -eq 1 ] && [ ! -t 0 ] && [ "${SETUP_ASSUME_YES:-0}" != "1" ]; then
  has_yes=0
  for a in "${optional_args[@]+"${optional_args[@]}"}"; do
    [ "$a" = "--yes" ] && has_yes=1
  done
  if [ "$has_yes" -eq 0 ]; then
    optional_args+=(--no-prompt)
  fi
fi

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

# ── 2. Core packages ─────────────────────────────────────────────────────────
say ""
say "== core packages ($pkg_file) =="
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

# ── 3. Optional tools (interactive) ──────────────────────────────────────────
if [ "$do_optional" -eq 1 ]; then
  say ""
  set +e
  # shellcheck disable=SC2086
  "$repo/ubuntu/optional.sh" ${optional_args[@]+"${optional_args[@]}"}
  set -e
fi

# ── 4. Link configs ──────────────────────────────────────────────────────────
if [ "$do_link" -eq 1 ]; then
  say ""
  say "== link dotfiles (install.sh) =="
  if [ "$dry_run" -eq 1 ]; then
    "$repo/install.sh" --dry-run
  else
    "$repo/install.sh"
  fi
fi

# ── 5. Git identity ──────────────────────────────────────────────────────────
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

# ── 6. SSH key ───────────────────────────────────────────────────────────────
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
  say "Done."
  say ""
  say "Reload your shell:  exec bash -l"
  say "First nvim launch bootstraps plugins (lazy.nvim) — needs network once."
  say "Re-run optionals anytime:  $repo/ubuntu/optional.sh"
fi
