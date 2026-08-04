#!/usr/bin/env bash
# dotfiles bootstrap — backup-first, idempotent, OS-guarded.
#
# Links repo configs into $HOME. It NEVER deletes a real (non-symlink) file:
# anything real in the way is moved to "<target>.pre-dotfiles.<timestamp>".
# Re-running is safe (idempotent). Pass --dry-run to preview with no changes.
# Portable: works on bash 3.2 (macOS default) — no associative arrays.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts="$(date +%Y%m%d-%H%M%S)"
dry_run=0
case "${1:-}" in
  -n|--dry-run) dry_run=1 ;;
  "") ;;
  *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

os="unknown"
case "$(uname -s)" in
  Linux*)  os="linux" ;;
  Darwin*) os="macos" ;;
esac

is_wsl=0
if [ "$os" = "linux" ] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  is_wsl=1
fi

say() { printf '%s\n' "$*"; }
run() { if [ "$dry_run" -eq 1 ]; then say "  DRY-RUN> $*"; else eval "$*"; fi; }

# link_one <source-in-repo> <target-in-home>
#   already-correct symlink -> skip; wrong symlink -> relink;
#   REAL file/dir -> move to backup then link; rm only ever touches a symlink.
link_one() {
  src="$1"; dst="$2"
  if [ ! -e "$src" ]; then say "SKIP  $dst  (source missing: $src)"; return 0; fi
  parent="$(dirname "$dst")"
  [ -d "$parent" ] || run "mkdir -p \"$parent\""
  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then say "ok    $dst  ->  $src"; return 0; fi
    say "relink $dst  (was -> $current)"
    run "rm -f \"$dst\""; run "ln -s \"$src\" \"$dst\""; say "link  $dst  ->  $src"; return 0
  fi
  if [ -e "$dst" ]; then
    backup="$dst.pre-dotfiles.$ts"
    say "backup $dst  ->  $backup"
    run "mv \"$dst\" \"$backup\""; run "ln -s \"$src\" \"$dst\""; say "link  $dst  ->  $src"; return 0
  fi
  run "ln -s \"$src\" \"$dst\""; say "link  $dst  ->  $src"
}

if [ "$os" = "linux" ] || [ "$os" = "macos" ]; then
  say "== shell configs ($os) =="
  for pair in \
    "shell/bashrc|.bashrc" \
    "shell/profile|.profile" \
    "shell/gitconfig|.gitconfig" \
    "tmux/tmux.conf|.tmux.conf"
  do
    s="${pair%%|*}"; t="${pair#*|}"
    link_one "$repo/$s" "$HOME/$t"
  done

  say "== nvim =="
  link_one "$repo/nvim" "$HOME/.config/nvim"
else
  say "== shell configs: skipped (unsupported OS: $(uname -s)) =="
fi

if { [ "$os" = "linux" ] || [ "$os" = "macos" ]; } && [ "$is_wsl" -eq 0 ]; then
  say "== wezterm ($os) =="
  link_one "$repo/wezterm" "$HOME/.config/wezterm"
elif [ "$is_wsl" -eq 1 ]; then
  say "== wezterm: skipped (WSL — WezTerm runs on the Windows host via install.ps1) =="
fi

say ""
if [ "$dry_run" -eq 1 ]; then
  say "Dry run complete — no changes made."
else
  say "Done. Backups (if any) are alongside targets as *.pre-dotfiles.$ts"
  say "Reload your shell:  exec bash -l"
fi
