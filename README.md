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
| 2 | Install packages from `ubuntu/packages.txt` (curl, git, openssh-client, nvim, tmux, …) |
| 3 | Install **WezTerm** via official apt repo (`ubuntu/install-wezterm.sh`; skipped on WSL) |
| 4 | Install third-party CLIs via official installers (`ubuntu/tools.sh`) |
| 5 | Link configs via `install.sh` (shell, git, tmux, nvim, WezTerm) |
| 6 | Prompt for git name/email → `~/.gitconfig.local` if missing |
| 7 | Remind if no SSH key is present (does not generate or commit keys) |

You do **not** need to run `install.sh` yourself on a new machine — `setup.sh`
calls it.

### Third-party tools (not apt)

These are installed with each vendor’s official script (same as their docs).
The repo only records **how** to install them — not API keys or login state.

| Tool | Binary | Installer |
|------|--------|-----------|
| [Herdr](https://herdr.dev/) | `herdr` | `curl -fsSL https://herdr.dev/install.sh \| sh` |
| [Claude Code](https://code.claude.com/) | `claude` | `curl -fsSL https://claude.ai/install.sh \| bash` |
| [Codex](https://github.com/openai/codex) | `codex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` |
| [Grok Build](https://x.ai/cli) | `grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` |

Already-installed tools are skipped. Auth is always interactive on first run
(`claude`, `codex`, `grok`, …) — keep tokens out of git.

```bash
./ubuntu/tools.sh             # install / refresh tools only
./ubuntu/tools.sh --dry-run
```

### Useful flags

```bash
./setup.sh --dry-run          # preview only, change nothing
./setup.sh --packages-only    # apt packages only (no WezTerm, tools, or linking)
./setup.sh --no-tools         # skip herdr/claude/codex/grok installers
./setup.sh --no-wezterm       # skip WezTerm apt install
```

Re-running `./setup.sh` is safe (apt is idempotent; tools skip if present;
configs are backup-first).

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
│   ├── bootstrap.sh         # guts of setup.sh (apt + wezterm + tools + link)
│   ├── packages.txt         # apt packages always installed on Ubuntu
│   ├── install-wezterm.sh   # official WezTerm apt repo + package
│   └── tools.sh             # herdr, Claude Code, Codex, Grok Build installers
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
- **SSH keys** are never generated or committed; setup only reminds you if none exist.
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
