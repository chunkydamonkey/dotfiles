#!/usr/bin/env bash
# Omarchy setup. Package install plus the safe linker.
#
# Leaves Omarchy's bashrc, tmux, Neovim, and terminals in place unless
# --nvim is passed. Does not generate an SSH key and does not run apt.
#
# Usage:
#   ./setup.sh
#   ./setup.sh --dry-run
#   ./setup.sh --nvim
#   ./setup.sh --no-skills
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=0
do_skills=1
install_args=()

usage() {
  echo "usage: $0 [--dry-run] [--nvim] [--no-skills]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1; install_args+=(--dry-run); shift ;;
    --nvim) install_args+=(--nvim); shift ;;
    --no-skills) do_skills=0; shift ;;
    -h|--help) usage ;;
    *) usage ;;
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

if [ ! -f /etc/os-release ]; then
  say "error: /etc/os-release missing."
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != "omarchy" ]; then
  say "error: this script targets Omarchy (got ID=${ID:-unknown})."
  exit 1
fi
if ! command -v omarchy >/dev/null 2>&1; then
  say "error: omarchy command not found."
  exit 1
fi

say "== Omarchy setup (${PRETTY_NAME:-omarchy}) =="
if [ "$dry_run" -eq 1 ]; then
  say "(dry-run mode — no changes will be made)"
fi
say ""

# git-lfs is included because shell/gitconfig.omarchy marks the LFS filter required.
# wezterm is the Omarchy default terminal (see playbooks/omarchy.md).
say "== packages (git, github-cli, git-lfs, wezterm) =="
run "omarchy pkg add git github-cli git-lfs wezterm"

say ""
say "== tailscale =="
if [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> omarchy-install-service-tailscale"
elif omarchy-installed-service-tailscale >/dev/null 2>&1; then
  say "ok    tailscale"
else
  say "Tailscale will ask you to log in."
  omarchy-install-service-tailscale
fi

say ""
say "== link dotfiles (omarchy/install.sh) =="
# shellcheck disable=SC2086
"$repo/omarchy/install.sh" ${install_args[@]+"${install_args[@]}"}

say ""
say "== git identity =="
if git config --global user.name >/dev/null 2>&1; then
  say "ok    user.name already set"
else
  say "skip  no global user.name. Set it in ~/.config/git/config if new shells need one."
fi

if [ "$do_skills" -eq 1 ]; then
  say ""
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ]; then
      "$repo/ubuntu/install-agent-skills.sh" --dry-run
    else
      "$repo/ubuntu/install-agent-skills.sh"
    fi
  else
    say "skip  gh is not logged in."
    say "Next:  gh auth login"
    say "Then:  $repo/ubuntu/install-agent-skills.sh"
  fi
fi

say ""
if [ "$dry_run" -eq 1 ]; then
  say "Dry run complete — no changes made."
else
  say "Done."
  say "Open a new terminal so the shell snippet loads."
fi
