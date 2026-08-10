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
#   2. installs packages from ubuntu/packages.txt (curl, git, ssh, nvim, …)
#   3. installs WezTerm (native Linux; skipped on WSL)
#   4. installs third-party CLIs (herdr, Claude Code, Codex, Grok Build)
#   5. links shell / WezTerm configs via install.sh
#   6. prompts for git name/email if ~/.gitconfig.local is missing
#   7. SSH key for this machine (generate if missing; optional gh upload)
#   8. clones and links the pinned private agent-skills repository
#
# Flags: ./setup.sh --dry-run --no-tools --no-wezterm --no-ssh-key --no-skills
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo/ubuntu/bootstrap.sh" "$@"
