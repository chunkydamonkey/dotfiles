#!/usr/bin/env bash
# Omarchy config linker.
#
# Does not replace Omarchy's ~/.bashrc, tmux config, or terminal configs.
# Appends a marked source block and a git include. Links nvim only with --nvim.
# Re-running is safe. Pass --dry-run to print actions without writing.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=0
do_nvim=0
begin="# >>> dotfiles omarchy >>>"
end="# <<< dotfiles omarchy <<<"

usage() {
  echo "usage: $0 [--dry-run] [--nvim]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1; shift ;;
    --nvim) do_nvim=1; shift ;;
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

# upsert_block <file> <block-file>
# Insert or replace the marked region. The block file includes the markers.
upsert_block() {
  local file="$1" block_file="$2" tmp
  if [ ! -e "$file" ]; then
    if [ "$dry_run" -eq 1 ]; then
      say "  DRY-RUN> create $file with dotfiles omarchy block"
      return 0
    fi
    mkdir -p "$(dirname "$file")"
    cp "$block_file" "$file"
    say "create $file"
    return 0
  fi
  if grep -qF "$begin" "$file"; then
    if [ "$dry_run" -eq 1 ]; then
      say "  DRY-RUN> refresh dotfiles omarchy block in $file"
      return 0
    fi
    tmp="$(mktemp)"
    awk -v begin="$begin" -v end="$end" -v block_file="$block_file" '
      $0 == begin {
        while ((getline line < block_file) > 0) print line
        close(block_file)
        skip = 1
        next
      }
      skip && $0 == end { skip = 0; next }
      skip { next }
      { print }
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
    say "refresh $file"
    return 0
  fi
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> append dotfiles omarchy block to $file"
    return 0
  fi
  printf '\n' >>"$file"
  cat "$block_file" >>"$file"
  say "append $file"
}

link_one() {
  local src="$1" dst="$2" current backup
  if [ ! -e "$src" ]; then
    say "SKIP  $dst  (source missing: $src)"
    return 0
  fi
  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      say "ok    $dst  ->  $src"
      return 0
    fi
    say "relink $dst  (was -> $current)"
    run "rm -f \"$dst\""
    run "ln -s \"$src\" \"$dst\""
    return 0
  fi
  if [ -e "$dst" ]; then
    backup="$dst.pre-dotfiles.$(date +%Y%m%d-%H%M%S)"
    say "backup $dst  ->  $backup"
    run "mv \"$dst\" \"$backup\""
    run "ln -s \"$src\" \"$dst\""
    return 0
  fi
  run "mkdir -p \"$(dirname "$dst")\""
  run "ln -s \"$src\" \"$dst\""
  say "link  $dst  ->  $src"
}

snippet="$repo/shell/omarchy.bash"
git_extra="$repo/shell/gitconfig.omarchy"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

say "== Omarchy shell snippet =="
cat >"$work/bashrc.block" <<EOF
$begin
# Personal shell habits from ~/dotfiles. Re-run omarchy/install.sh to refresh.
[ -f "$snippet" ] && . "$snippet"
$end
EOF
upsert_block "$HOME/.bashrc" "$work/bashrc.block"

if ! command -v git-lfs >/dev/null 2>&1; then
  say "warn  git-lfs is not installed; shell/gitconfig.omarchy marks the LFS filter required"
fi

say "== Omarchy git include =="
cat >"$work/git.block" <<EOF
$begin
[include]
	path = $git_extra
$end
EOF
if [ ! -e "$HOME/.config/git/config" ] && [ "$dry_run" -eq 0 ]; then
  mkdir -p "$HOME/.config/git"
fi
upsert_block "$HOME/.config/git/config" "$work/git.block"

say "== nvim =="
if [ "$do_nvim" -eq 1 ]; then
  link_one "$repo/nvim" "$HOME/.config/nvim"
else
  say "skip  ~/.config/nvim (pass --nvim to replace LazyVim with the repo config)"
fi

say "skip  tmux (Omarchy keeps ~/.config/tmux/tmux.conf)"

say "== hyprland =="
if [ "$dry_run" -eq 0 ]; then
  mkdir -p "$HOME/.config/hypr"
fi
link_one "$repo/omarchy/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
link_one "$repo/omarchy/hypr/input.lua" "$HOME/.config/hypr/input.lua"

say "== wezterm =="
link_one "$repo/wezterm" "$HOME/.config/wezterm"
if [ "$dry_run" -eq 0 ]; then
  mkdir -p "$HOME/.local/share/applications"
fi
link_one "$repo/omarchy/org.wezfurlong.wezterm.desktop" \
  "$HOME/.local/share/applications/org.wezfurlong.wezterm.desktop"
desktop_id="org.wezfurlong.wezterm.desktop"
list="$HOME/.config/xdg-terminals.list"
first=""
if [ -f "$list" ]; then
  first="$(awk 'NF && $1 !~ /^#/ { print; exit }' "$list")"
fi
if [ "$first" = "$desktop_id" ]; then
  say "ok    $list starts with $desktop_id"
else
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> write $list with $desktop_id first"
  else
    cat >"$list" <<EOF
# Terminal emulator preference order for xdg-terminal-exec
# Written by omarchy/install.sh. The first found and valid terminal is used.
$desktop_id
EOF
    say "write $list"
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/xdg-terminal-exec"
  fi
fi

say "== browser =="
browser_id="google-chrome.desktop"
current_browser="$(env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings get default-web-browser 2>/dev/null || true)"
if [ "$current_browser" = "$browser_id" ]; then
  say "ok    default browser is $browser_id"
else
  if [ "$dry_run" -eq 1 ]; then
    say "  DRY-RUN> set default browser to $browser_id"
  else
    if command -v xdg-settings >/dev/null 2>&1; then
      env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings set default-web-browser "$browser_id"
      say "set   default browser to $browser_id"
    fi
  fi
fi

say ""
if [ "$dry_run" -eq 1 ]; then
  say "Dry run complete — no changes made."
else
  say "Done. Open a new terminal so the shell snippet loads."
fi
