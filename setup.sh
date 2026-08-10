#!/usr/bin/env bash
# One-shot machine setup for Ubuntu.
#
# After a fresh install:
#   sudo apt update && sudo apt install -y git curl
#   git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
#   cd ~/dotfiles && ./setup.sh
#
# This runs ubuntu/bootstrap.sh, which:
#   1. apt update + upgrade
#   2. core packages from ubuntu/packages.txt (always)
#   3. optional tools — interactive Y/n (Docker, WezTerm, AI CLIs, …)
#   4. link configs via install.sh
#   5. git identity if ~/.gitconfig.local is missing
#   6. SSH key for this machine (generate if missing; optional gh upload)
#
# Flags:
#   ./setup.sh --dry-run
#   ./setup.sh --yes              # auto-accept recommended optionals
#   ./setup.sh --no-optional      # core + link + git/ssh only
#   ./setup.sh --packages-only
#   ./setup.sh --no-ssh-key
# Re-prompt optionals later:  ./ubuntu/optional.sh
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo/ubuntu/bootstrap.sh" "$@"
