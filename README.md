# dotfiles

Cross-platform dotfiles. Scaffolded from Kun Chen's
[`dotfiles-mac-nix`](https://github.com/kunchenguid/dotfiles-mac-nix), but
swapped from Nix (macOS/Linux only) to a plain git repo + bootstrap scripts so
it works natively on **Windows** and **WSL2** too.

## Layout

```
dotfiles/
├── wezterm/            # WezTerm config (Windows/macOS host terminal)
│   ├── wezterm.lua     # cross-platform, OS-aware at runtime
│   └── fonts/          # Hack Nerd Font, bundled (self-contained)
├── shell/              # Linux / WSL2 shell environment
│   ├── bashrc          # → ~/.bashrc
│   ├── profile         # → ~/.profile
│   └── gitconfig       # → ~/.gitconfig (identity via ~/.gitconfig.local)
├── install.ps1         # Windows bootstrap (junction, no admin) — WezTerm
├── install.sh          # Linux/macOS bootstrap (symlinks) — shell + WezTerm
└── README.md
```

`wezterm.lua` detects the OS at runtime and loads fonts from
`wezterm.config_dir/fonts` — no hardcoded paths. `install.sh` is **backup-first,
idempotent, and OS-guarded**: any real file in the way is moved to
`<target>.pre-dotfiles.<timestamp>` before it symlinks (it never deletes real
data), and re-running is safe. Use `./install.sh --dry-run` to preview.

## Setup on a fresh machine

**Windows** (WezTerm on the host) — PowerShell:

```powershell
git clone https://github.com/chunkydamonkey/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**WSL2 / Linux / macOS** (shell environment):

```bash
git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # preview — shows what it would back up/link
./install.sh             # apply (backs up any existing files first)
exec bash -l             # reload the shell
```

Then set your git identity in an untracked `~/.gitconfig.local` (the tracked
gitconfig `include`s it, so no personal/work email lives in the repo):

```ini
[user]
    name  = Your Name
    email = you@example.com
```

## WSL2 note & sync model

WezTerm runs on the Windows host, so under WSL `install.sh` **skips** the WezTerm
link (nothing reads it there) and only manages the shell configs.

There are two working copies of this one repo. Keep the WSL clone on the Linux
filesystem (`~/dotfiles`), never under `/mnt/c` (DrvFs symlink/perf issues):

```
        GitHub: chunkydamonkey/dotfiles (origin/main)
           ▲                                   ▲
   C:\Users\...\dotfiles  (Windows)     ~/dotfiles  (WSL native FS)
   drives WezTerm (install.ps1)         drives Linux shell (install.sh)
```

Edit/commit/push in one; `git pull` in the other before editing there
(`pull.rebase=true` is the default). After pulling shell-config changes you need
NOT re-run `install.sh` — the targets are symlinks into the repo, so a pull
updates them live. Re-run only when adding a NEW managed file.

## Adding more configs later

Drop the app's config under a new top-level folder (e.g. `nvim/`) and add a
matching pair to the link loop in `install.sh` (and `install.ps1` if it also
applies on Windows). Same pattern as `shell/` and `wezterm/`.
