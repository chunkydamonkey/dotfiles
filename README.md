# dotfiles

Cross-platform personal configs (shell, git, WezTerm) plus a **one-command Ubuntu
setup**. Plain git + bootstrap scripts — works on **Ubuntu**, **WSL2**, and
**Windows**.

Scaffolded from Kun Chen's
[`dotfiles-mac-nix`](https://github.com/kunchenguid/dotfiles-mac-nix) / maintained
[`dotfiles`](https://github.com/kunchenguid/dotfiles) (Neovim), then adapted away
from Nix so Windows/WSL2 work natively.

---

## Fresh Ubuntu (desktop or WSL2)

You're on a new machine. Open Terminal and run:

```bash
# 1. Just enough to clone
sudo apt update && sudo apt install -y git curl

# 2. Clone this repo
git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 3. One script — does everything
./setup.sh

# 4. Reload the shell
exec bash -l
```

Optional after that:

```bash
gh auth login    # GitHub login + git credential helper
```

### What `./setup.sh` does

| Step | Action |
|------|--------|
| 1 | `apt update` + `apt upgrade` |
| 2 | **Core** packages from `ubuntu/packages.txt` (always) |
| 3 | **Optional** tools — interactive Y/n if missing (`ubuntu/optional.sh`) |
| 4 | Link configs via `install.sh` (shell, git, tmux, nvim, WezTerm) |
| 5 | Prompt for git name/email → `~/.gitconfig.local` if missing |
| 6 | **SSH key for this machine** — generate if missing; offer `gh` upload |

You do **not** need to run `install.sh` yourself on a new machine — `setup.sh`
calls it.

### Core vs optional

**Core** (no questions): git, curl, ssh client, build tools, nvim, tmux, rg, gh, …

**Optional** (asks if not installed; skips if already present):

| Optional | Default prompt | Notes |
|----------|----------------|--------|
| Docker (`docker.io`) | **Y** | enable on boot + add user to `docker` group |
| wl-clipboard | **Y** | Wayland `pbcopy` / `pbpaste` |
| WezTerm | **Y** | skipped on WSL |
| herdr, Claude Code, Codex, Grok, treehouse | **Y** | official curl installers |
| firstmate | **Y** | clones `~/firstmate` |

Already installed → printed as `ok` and not re-asked.  
Auth stays interactive later (`claude`, `gh auth login`, …) — no tokens in git.

```bash
./ubuntu/optional.sh            # re-run prompts anytime
./ubuntu/optional.sh --yes      # install all recommended defaults
./ubuntu/tools.sh               # non-interactive bulk vendor CLIs (legacy/helper)
```

### Useful flags

```bash
./setup.sh --dry-run          # preview only
./setup.sh --yes              # auto-accept recommended optionals (no Y/n)
./setup.sh --no-optional      # core + link + git/ssh only
./setup.sh --packages-only    # core apt only
./setup.sh --no-ssh-key       # skip SSH key step
```

Re-running is safe (apt idempotent; optionals skip installed; configs backup-first).

### SSH keys (per machine)

Private keys are **never** in the repo (see `.gitignore`). On a new box, step 7:

1. Creates `~/.ssh/id_ed25519` if you have no default key (empty passphrase)
2. Comment uses email from `~/.gitconfig.local` when set
3. If `gh` is logged in, uploads the pubkey (`hostname-YYYYMMDD` title)
4. If not logged in, offers `gh auth login` then upload

SSH-only re-run:

```bash
./ubuntu/setup-ssh.sh
```

---

## Fresh Windows (WezTerm)

```powershell
# 1. Install tools
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e

# 2. New terminal, then authenticate
gh auth login

# 3. Clone + link WezTerm config
gh repo clone chunkydamonkey/dotfiles "$HOME\dotfiles"
powershell -ExecutionPolicy Bypass -File "$HOME\dotfiles\install.ps1"

# 4. Launch WezTerm — config + Hack Nerd Font come from the repo
```

---

## Layout

```
dotfiles/
├── setup.sh            # ONE script for a new Ubuntu machine
├── install.sh          # Linux/macOS: symlink configs only (called by setup.sh)
├── install.ps1         # Windows: junction WezTerm config (no admin)
├── ubuntu/
│   ├── bootstrap.sh         # guts of setup.sh
│   ├── packages.txt         # core apt packages (always)
│   ├── optional.sh          # interactive Docker / WezTerm / AI CLIs / …
│   ├── install-wezterm.sh   # WezTerm apt repo helper
│   ├── setup-ssh.sh         # per-machine ed25519 key + optional gh upload
│   └── tools.sh             # non-interactive bulk vendor CLI helper
├── shell/
│   ├── bashrc          # → ~/.bashrc
│   ├── profile         # → ~/.profile
│   └── gitconfig       # → ~/.gitconfig (identity via ~/.gitconfig.local)
├── nvim/               # → ~/.config/nvim  (from kunchenguid/dotfiles)
├── tmux/
│   └── tmux.conf       # → ~/.tmux.conf
└── wezterm/
    ├── wezterm.lua     # OS-aware; fonts loaded from this folder
    └── fonts/          # Hack Nerd Font (bundled)
```

### Neovim

Adapted from [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles):

- **lazy.nvim** plugin manager (bootstraps on first `nvim` launch — needs network once)
- **rose-pine moon** theme
- **oil.nvim** file browser (`<leader>e`), **snacks** picker (`<leader>f` / `s` / `b`)
- **neogit** + gitsigns (`<leader>g`)
- Space is leader; Esc saves; system clipboard; relative numbers

### tmux

Same link pattern as nvim/wezterm. Small config for long sessions: mouse, large
history, path-aware splits, vi keys. Prefix stays `C-b` (herdr-friendly).

### Safety notes

- **`install.sh`** never deletes real files. Anything in the way is moved to
  `*.pre-dotfiles.<timestamp>`, then replaced with a symlink. Re-running is safe.
- **`~/.gitconfig.local`** holds your name/email and is **not** committed (so the
  public repo stays free of personal identity).
- **SSH keys** are generated per machine under `~/.ssh/` and never committed;
  setup can upload the **public** key via `gh` after you log in.
- Shell config is WSL-aware: Windows interop only under WSL. Optional WSL service
  auto-start is **off** unless you set `WSL_AUTO_START_SERVICES=1` (e.g. in
  `~/.bashrc.local`).

---

## Day to day

| Goal | What to do |
|------|------------|
| Pull latest configs | `cd ~/dotfiles && git pull` |
| Always install a new package on fresh machines | Add it to `ubuntu/packages.txt`, commit, then `./setup.sh` (or `./setup.sh --packages-only`) |
| Manage a new app config | Add a folder, wire it in `install.sh` (and `install.ps1` if Windows), run `./install.sh` once |
| Configs only (packages already OK) | `./install.sh` then `exec bash -l` |
| SSH key for GitHub | `ssh-keygen -t ed25519 -C "you@example.com"` then `gh auth login` or add the `.pub` on GitHub |

After the first setup, **pulling** updates live configs (they are symlinks into the
repo). Re-run `install.sh` only when you add a **new** managed path.

---

## WSL2 + Windows together

WezTerm runs on the **Windows host**. Under WSL, `install.sh` skips the WezTerm
link and only manages shell configs.

Keep two clones of the same repo — never put the WSL clone under `/mnt/c`
(DrvFs symlink/perf issues):

```
              GitHub: chunkydamonkey/dotfiles
                 ▲                     ▲
   C:\Users\…\dotfiles          ~/dotfiles   (Linux FS)
   install.ps1 → WezTerm        setup.sh / install.sh → shell
```

Edit and push on one side; `git pull` on the other before editing there
(`pull.rebase=true` is set in the shared gitconfig).

---

## Git identity

Created by `./setup.sh` when missing, or manually:

```ini
# ~/.gitconfig.local  (not tracked)
[user]
    name  = Your Name
    email = you@example.com
```

The tracked `shell/gitconfig` includes this file; a missing include is ignored
until you create it.
