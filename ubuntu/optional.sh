#!/usr/bin/env bash
# Interactive optional installs for a fresh (or existing) Ubuntu machine.
#
# Always-on packages stay in packages.txt / bootstrap. This script only offers
# extras: Docker, WezTerm, AI CLIs, herdr, treehouse, firstmate, wl-clipboard.
#
# For each item: if already installed → skip; else prompt Y/n (defaults shown).
#
# Usage:
#   ./ubuntu/optional.sh              # ask about missing tools (needs TTY)
#   ./ubuntu/optional.sh --yes        # install all recommended defaults (no ask)
#   ./ubuntu/optional.sh --dry-run    # show what would be offered / installed
#   ./ubuntu/optional.sh --no-prompt  # skip anything missing (CI / non-interactive)
#
# Env:
#   SETUP_ASSUME_YES=1   same as --yes
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=0
assume_yes=0
no_prompt=0

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)   dry_run=1 ;;
    -y|--yes)       assume_yes=1 ;;
    --no-prompt)    no_prompt=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run] [--yes] [--no-prompt]" >&2
      exit 2
      ;;
  esac
done

if [ "${SETUP_ASSUME_YES:-0}" = "1" ]; then
  assume_yes=1
fi

say() { printf '%s\n' "$*"; }
run() {
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> $*"
  else
    eval "$@"
  fi
}

export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"

# ask_yn "prompt" default_y_or_n  → 0=yes 1=no
ask_yn() {
  local prompt="$1" default="${2:-n}" ans
  if [ "$assume_yes" -eq 1 ]; then
    # Only auto-yes when the recommended default is Y
    if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
      say "  → yes ( --yes / recommended )"
      return 0
    fi
    say "  → no  ( --yes only auto-accepts [Y] defaults )"
    return 1
  fi
  if [ "$no_prompt" -eq 1 ]; then
    say "  → skip ( --no-prompt / non-interactive )"
    return 1
  fi
  if [ ! -t 0 ]; then
    say "  → skip (no TTY)"
    return 1
  fi
  if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
    printf "  %s [Y/n] " "$prompt"
  else
    printf "  %s [y/N] " "$prompt"
  fi
  read -r ans || ans=""
  ans="${ans:-$default}"
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

is_wsl=0
if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  is_wsl=1
fi

say "== optional tools (interactive) =="
say "Core packages already handled by packages.txt. Choose extras below."
say "Already installed items are skipped. Private keys/tokens never go in the repo."
if [ "$dry_run" -eq 1 ]; then
  say "(dry-run — will not install)"
fi
say ""

# ── Docker ───────────────────────────────────────────────────────────────────
say "Docker — containers, compose-friendly daemon, start on boot"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  say "ok    docker already installed and running"
elif command -v docker >/dev/null 2>&1; then
  say "ok    docker binary present ($(command -v docker))"
  if ask_yn "Enable and start docker.service on boot?" "y"; then
    run "sudo systemctl enable --now docker"
  fi
else
  if ask_yn "Install Docker (docker.io) and enable on boot?" "y"; then
    run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io"
    run "sudo systemctl enable --now docker"
    if [ "$dry_run" -eq 0 ]; then
      sudo usermod -aG docker "$USER" 2>/dev/null \
        && say "      added $USER to group 'docker' (log out/in for it to apply)" \
        || true
    else
      say "  DRY-RUN> usermod -aG docker \$USER"
    fi
  else
    say "skip  docker"
  fi
fi
say ""

# ── wl-clipboard ─────────────────────────────────────────────────────────────
say "wl-clipboard — wl-copy / wl-paste (Wayland; powers pbcopy/pbpaste on Linux)"
if command -v wl-copy >/dev/null 2>&1; then
  say "ok    wl-copy already installed"
elif ask_yn "Install wl-clipboard?" "y"; then
  run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wl-clipboard"
else
  say "skip  wl-clipboard"
fi
say ""

# ── WezTerm ──────────────────────────────────────────────────────────────────
say "WezTerm — GPU terminal (config already in this repo)"
if [ "$is_wsl" -eq 1 ]; then
  say "skip  WSL — install WezTerm on the Windows host instead"
elif command -v wezterm >/dev/null 2>&1; then
  say "ok    wezterm already installed: $(wezterm --version 2>/dev/null | head -n1)"
elif ask_yn "Install WezTerm (official apt repo)?" "y"; then
  if [ "$dry_run" -eq 1 ]; then
    "$repo/ubuntu/install-wezterm.sh" --dry-run
  else
    set +e
    "$repo/ubuntu/install-wezterm.sh"
    set -e
  fi
else
  say "skip  wezterm"
fi
say ""

# ── Vendor CLIs (curl installers) ────────────────────────────────────────────
# name|bin|default|install cmd
vendor_tools=(
  "herdr|herdr|y|curl -fsSL https://herdr.dev/install.sh | sh"
  "Claude Code|claude|y|curl -fsSL https://claude.ai/install.sh | bash"
  "Codex|codex|y|curl -fsSL https://chatgpt.com/codex/install.sh | sh"
  "Grok Build|grok|y|curl -fsSL https://x.ai/cli/install.sh | bash"
  "treehouse (git worktree pool)|treehouse|y|curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh"
)

say "Agent / coding CLIs"
for entry in "${vendor_tools[@]}"; do
  IFS='|' read -r name bin def cmd <<< "$entry"
  if command -v "$bin" >/dev/null 2>&1; then
    ver="$("$bin" --version 2>/dev/null | head -n1 || true)"
    say "ok    $name ($bin)${ver:+ — $ver}"
    continue
  fi
  if ask_yn "Install $name?" "$def"; then
    say "install $name"
    say "  $cmd"
    if [ "$dry_run" -eq 1 ]; then
      say "  DRY-RUN> skipped"
      continue
    fi
    set +e
    eval "$cmd"
    st=$?
    set -e
    export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
    if [ "$st" -eq 0 ] && command -v "$bin" >/dev/null 2>&1; then
      say "  done  $bin -> $(command -v "$bin")"
    elif [ "$st" -eq 0 ]; then
      say "  warn  installer finished; open a new shell if '$bin' is missing from PATH"
    else
      say "  FAIL  $name install failed"
    fi
  else
    say "skip  $name"
  fi
done
say ""

# ── firstmate (clone) ────────────────────────────────────────────────────────
fm_dir="${FIRSTMATE_HOME:-$HOME/firstmate}"
say "firstmate — Kun Chen agent distro (clone → $fm_dir)"
if [ -d "$fm_dir/.git" ]; then
  say "ok    already at $fm_dir"
  if [ "$dry_run" -eq 0 ] && ask_yn "git pull --ff-only in firstmate?" "n"; then
    git -C "$fm_dir" pull --ff-only || say "      pull failed / dirty tree"
  fi
elif ask_yn "Clone firstmate to $fm_dir?" "y"; then
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> git clone https://github.com/kunchenguid/firstmate.git $fm_dir"
  else
    git clone https://github.com/kunchenguid/firstmate.git "$fm_dir" \
      && say "  done  cd $fm_dir && claude   # or grok --trust / pi" \
      || say "  FAIL  clone failed"
  fi
else
  say "skip  firstmate"
fi

say ""
say "optional tools done."
say "Auth (when you use them): gh auth login · claude · codex · grok · herdr"
