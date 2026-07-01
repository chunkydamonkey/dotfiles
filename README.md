# dotfiles

Cross-platform dotfiles. Scaffolded from Kun Chen's
[`dotfiles-mac-nix`](https://github.com/kunchenguid/dotfiles-mac-nix), but
swapped from Nix (macOS/Linux only) to a plain git repo + bootstrap scripts so
it works natively on **Windows** too.

## Layout

```
dotfiles/
├── wezterm/
│   ├── wezterm.lua     # cross-platform WezTerm config (OS-aware at runtime)
│   └── fonts/          # Hack Nerd Font, bundled so the repo is self-contained
├── install.ps1         # Windows bootstrap (directory junction, no admin)
├── install.sh          # macOS / Linux bootstrap (symlink)
└── README.md
```

The WezTerm config is a single `wezterm.lua` that detects the OS at runtime via
`wezterm.target_triple` and loads its fonts from `wezterm.config_dir/fonts` — so
there are no hardcoded user paths and nothing to install system-wide.

## Setup on a fresh machine

Clone, then run the bootstrap for your OS. Both scripts link
`~/.config/wezterm` → `<repo>/wezterm` and remove any legacy config.

**Windows** (PowerShell):

```powershell
git clone https://github.com/<you>/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**macOS / Linux**:

```bash
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then launch WezTerm (or press `Ctrl+Shift+R` to reload).

## Adding more configs later

Drop the app's config under a new top-level folder (e.g. `nvim/`, `zsh/`) and
add a matching link line to `install.ps1` / `install.sh`. Same pattern as
`wezterm/`.
