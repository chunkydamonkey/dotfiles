#!/usr/bin/env bash
# Install WezTerm on native Ubuntu/Debian via the official apt repo.
# https://wezterm.org/install/linux.html
#
# Skips:
#   - WSL (WezTerm runs on the Windows host; use install.ps1 there)
#   - when `wezterm` is already on PATH
#
# Usage:
#   ./ubuntu/install-wezterm.sh
#   ./ubuntu/install-wezterm.sh --dry-run
# Called from setup.sh / ubuntu/bootstrap.sh.
set -euo pipefail

dry_run=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run]" >&2
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

say "== WezTerm =="

# WSL: host terminal, not the distro
if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  say "skip  WSL — install WezTerm on Windows (winget / install.ps1), not inside the distro"
  exit 0
fi

if command -v wezterm >/dev/null 2>&1; then
  ver="$(wezterm --version 2>/dev/null | head -n1 || true)"
  say "ok    already installed${ver:+: $ver}"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  say "error: apt-get not found — install WezTerm manually: https://wezterm.org/install/linux.html"
  exit 1
fi

keyring="/usr/share/keyrings/wezterm-fury.gpg"
list="/etc/apt/sources.list.d/wezterm.list"

say "install via official apt repo (apt.fury.io/wez)"
if [ ! -f "$keyring" ]; then
  run "curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o \"$keyring\""
else
  say "ok    keyring present: $keyring"
fi

if [ ! -f "$list" ]; then
  run "echo 'deb [signed-by=$keyring] https://apt.fury.io/wez/ * *' | sudo tee \"$list\" >/dev/null"
else
  say "ok    apt source present: $list"
fi

run "sudo apt-get update"
run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wezterm"

if [ "$dry_run" -eq 1 ]; then
  say "Dry run complete — WezTerm not installed."
  exit 0
fi

if command -v wezterm >/dev/null 2>&1; then
  say "done  $(wezterm --version 2>/dev/null | head -n1)"
  say "      Launch from Activities, or: wezterm"
  say "      Pin to dock: right-click icon → Pin to Dash"
else
  say "warn  apt finished but 'wezterm' not on PATH yet — open a new shell and try again"
fi
