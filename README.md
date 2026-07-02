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

Everything (config + fonts) is in the repo, so a new machine only needs a few
tools, one auth, a clone, and one script.

### Fresh Windows machine (WezTerm)

```powershell
# 1. Install tools (Windows Terminal is preinstalled on Win11)
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e

# 2. Open a NEW terminal (so git/gh land on PATH), then authenticate
gh auth login                    # GitHub.com → HTTPS → login with browser

# 3. Clone the private repo (gh provides auth) + bootstrap
gh repo clone chunkydamonkey/dotfiles "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File "$HOME\dotfiles\install.ps1"

# 4. Launch WezTerm — config + Hack font come from the repo.
```

### WSL2 / Linux / macOS (shell environment)

On a fresh Windows box, first run `wsl --install` (installs WSL2 + Ubuntu),
reboot, and create your Linux user. Then inside the distro:

```bash
sudo apt update && sudo apt install -y git gh   # gh via apt on recent Ubuntu; else cli.github.com
gh auth login
git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # preview — shows what it would back up/link
./install.sh             # apply (backs up any existing files first)
exec bash -l             # reload the shell
```

Finally set your git identity in an untracked `~/.gitconfig.local` (the tracked
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
