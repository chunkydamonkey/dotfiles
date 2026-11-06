#!/usr/bin/env bash
# Install Tailscale on native Ubuntu/Debian.
# https://tailscale.com/download/linux
#
# Skips:
#   - WSL (run Tailscale on the Windows host via install.ps1)
#   - when the `tailscale` CLI is already present
#
# After install, enable the daemon. Login is left to you:
#   sudo tailscale up
#
# Usage:
#   ./ubuntu/install-tailscale.sh
#   ./ubuntu/install-tailscale.sh --dry-run
# Called from setup.sh / ubuntu/bootstrap.sh (always-on, not optional).
set -euo pipefail

dry_run=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
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

say "== Tailscale =="

if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  say "skip  WSL — install Tailscale on Windows (winget / install.ps1), not inside the distro"
  exit 0
fi

if command -v tailscale >/dev/null 2>&1; then
  ver="$(tailscale version 2>/dev/null | head -n1 || true)"
  say "ok    already installed${ver:+: $ver}"
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-enabled --quiet tailscaled.service 2>/dev/null; then
      say "ok    tailscaled enabled"
    else
      run "sudo systemctl enable --now tailscaled.service"
    fi
  fi
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  say "error: curl is required to install Tailscale"
  exit 1
fi

# Official one-shot installer (adds the apt repo and the package).
run "curl -fsSL https://tailscale.com/install.sh | sh"

if [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> sudo systemctl enable --now tailscaled.service"
  say "Dry run complete — Tailscale not installed."
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  say "error: install finished but 'tailscale' is not on PATH"
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  run "sudo systemctl enable --now tailscaled.service"
fi

say "done  $(tailscale version 2>/dev/null | head -n1)"
say "Next:  sudo tailscale up"
