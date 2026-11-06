#!/usr/bin/env bash
# One-shot machine setup.
#
# Omarchy (ID=omarchy) runs omarchy/bootstrap.sh.
# Ubuntu and Debian run ubuntu/bootstrap.sh.
#
# After a fresh Ubuntu install:
#   sudo apt update && sudo apt install -y git curl
#   git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
#   cd ~/dotfiles && ./setup.sh
#
# ubuntu/bootstrap.sh:
#   1. apt update + upgrade
#   2. core packages from ubuntu/packages.txt (always)
#   3. optional tools — interactive Y/n (Docker, WezTerm, AI CLIs, …)
#   4. link configs via install.sh
#   5. git identity if ~/.gitconfig.local is missing
#   6. SSH key for this machine (generate if missing; optional gh upload)
#   7. clones and links the pinned private agent-skills repository
#
# Omarchy flags:
#   ./setup.sh --dry-run
#   ./setup.sh --nvim             # replace LazyVim with the repo nvim config
#   ./setup.sh --no-skills
#
# Ubuntu flags:
#   ./setup.sh --dry-run
#   ./setup.sh --yes              # auto-accept recommended optionals
#   ./setup.sh --no-optional      # core + link + git/ssh only
#   ./setup.sh --packages-only
#   ./setup.sh --no-ssh-key
#   ./setup.sh --no-skills        # skip the private personal skills repository
# Re-prompt optionals later:  ./ubuntu/optional.sh
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" = "omarchy" ]; then
    exec "$repo/omarchy/bootstrap.sh" "$@"
  fi
fi

exec "$repo/ubuntu/bootstrap.sh" "$@"
