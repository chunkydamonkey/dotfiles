#!/usr/bin/env bash
# Install third-party CLI tools via their official installers.
#
# These are NOT apt packages — each vendor ships a curl|bash (or sh) installer
# that drops a binary under ~/.local, ~/.grok, etc. Auth is interactive and is
# never automated here (no secrets in the repo).
#
# Safe: skips tools already on PATH. Re-run anytime to fill gaps / update via
# the vendor installer.
#
# Usage:
#   ./ubuntu/tools.sh
#   ./ubuntu/tools.sh --dry-run
# Called automatically from setup.sh / ubuntu/bootstrap.sh unless --no-tools.
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

# name|binary|install command
# binary = command checked on PATH to decide "already installed"
tools=(
  "herdr|herdr|curl -fsSL https://herdr.dev/install.sh | sh"
  "Claude Code|claude|curl -fsSL https://claude.ai/install.sh | bash"
  "Codex|codex|curl -fsSL https://chatgpt.com/codex/install.sh | sh"
  "Grok Build|grok|curl -fsSL https://x.ai/cli/install.sh | bash"
  # Kun Chen: worktree pool CLI (firstmate uses this for isolated agent checkouts)
  "treehouse|treehouse|curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh"
)

# Vendor installers often put binaries in these places; ensure they exist and
# are on PATH for this script's "already installed?" checks.
export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
mkdir -p "$HOME/.local/bin"

say "== third-party tools =="
if [ "$dry_run" -eq 1 ]; then
  say "(dry-run — no installers will run)"
fi

installed=0
skipped=0
failed=0

for entry in "${tools[@]}"; do
  IFS='|' read -r name bin cmd <<< "$entry"
  if command -v "$bin" >/dev/null 2>&1; then
    ver="$("$bin" --version 2>/dev/null | head -n1 || true)"
    if [ -n "$ver" ]; then
      say "ok    $name ($bin) — already installed: $ver"
    else
      say "ok    $name ($bin) — already on PATH"
    fi
    skipped=$((skipped + 1))
    continue
  fi

  say "install $name → $bin"
  say "  $cmd"
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> skipped"
    continue
  fi

  # shellcheck disable=SC2086
  if eval "$cmd"; then
    # re-check PATH after install
    export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
    if command -v "$bin" >/dev/null 2>&1; then
      say "  done  $bin -> $(command -v "$bin")"
      installed=$((installed + 1))
    else
      say "  warn  installer finished but '$bin' not on PATH yet"
      say "        open a new shell or: export PATH=\"\$HOME/.local/bin:\$HOME/.grok/bin:\$PATH\""
      installed=$((installed + 1))
    fi
  else
    say "  FAIL  $name install failed (network / vendor script). Continue with others."
    failed=$((failed + 1))
  fi
done

# firstmate is a clone-based “agent distro”, not a single binary on PATH.
fm_dir="${FIRSTMATE_HOME:-$HOME/firstmate}"
say ""
say "== firstmate (kunchenguid/firstmate) =="
if [ -d "$fm_dir/.git" ]; then
  say "ok    $fm_dir already cloned"
  if [ "$dry_run" -eq 0 ]; then
    git -C "$fm_dir" pull --ff-only 2>/dev/null \
      && say "      pulled latest" \
      || say "      leave as-is (pull skipped / dirty)"
  fi
  skipped=$((skipped + 1))
elif [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> git clone https://github.com/kunchenguid/firstmate.git $fm_dir"
else
  say "clone  https://github.com/kunchenguid/firstmate.git → $fm_dir"
  if git clone https://github.com/kunchenguid/firstmate.git "$fm_dir"; then
    say "  done  $fm_dir"
    installed=$((installed + 1))
  else
    say "  FAIL  firstmate clone failed"
    failed=$((failed + 1))
  fi
fi

say ""
say "tools summary: installed=$installed skipped=$skipped failed=$failed"
say "Login is per-tool and interactive (not stored in this repo):"
say "  herdr          # first launch / account as needed"
say "  claude         # browser auth"
say "  codex          # ChatGPT / API auth"
say "  grok           # browser auth (or XAI_API_KEY)"
say "  treehouse      # worktree pool: cd <repo> && treehouse"
say "  firstmate      # cd ~/firstmate && claude   # or: grok --trust / pi"
