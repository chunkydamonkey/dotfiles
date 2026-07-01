#!/usr/bin/env bash
# Bootstrap the WezTerm config on macOS / Linux via a symlink.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/wezterm"
dst="$HOME/.config/wezterm"

# Remove legacy configs that would shadow ~/.config/wezterm.
rm -f "$HOME/.wezterm.lua"
rm -rf "$HOME/.wezfonts"

mkdir -p "$HOME/.config"

# Remove an existing link or directory at the destination (rm on a symlink
# removes only the link).
if [ -e "$dst" ] || [ -L "$dst" ]; then
  rm -rf "$dst"
fi

ln -s "$src" "$dst"
echo "Linked $dst  ->  $src"
echo "Launch WezTerm (or press Ctrl+Shift+R) to load it."
