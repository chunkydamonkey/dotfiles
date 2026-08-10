---
name: setup-env
description: >
  Set up this dotfiles repo on the current machine: detect Linux (Ubuntu/Debian),
  WSL2, Windows, or macOS, ask the user about optional steps, then run the matching
  bootstrap/link scripts (setup.sh, install.sh, install.ps1, tools, SSH, WezTerm).
  Use when the user asks to set up the environment, bootstrap a new machine, install
  dotfiles, run setup, "fresh install", link configs, or invokes /setup-env.
---

# setup-env

Drive a full or partial setup of **this** repository (`chunkydamonkey/dotfiles`) for the machine the agent is running on.

Do **not** invent install steps. Prefer the scripts already in the repo. Re-reads of `README.md`, `setup.sh`, `install.sh`, `install.ps1`, and `ubuntu/*` beat memory if anything looks out of date.

## Goals

1. Detect OS / WSL / shell context accurately.
2. Confirm optional steps with the user before changing the system.
3. Run the correct entrypoint with the right flags.
4. Handle interactive pieces (git identity, `gh auth`, tool logins) that scripts cannot do non-interactively.
5. Report what ran, what was skipped, and what the user should do next.

## Hard rules

- **Never** commit secrets, tokens, private keys, or `~/.gitconfig.local`.
- **Never** store SSH private keys in the repo.
- Prefer **idempotent** re-runs; scripts already backup real files before linking.
- On WSL: do **not** put the Linux clone under `/mnt/c` (DrvFs perf/symlink issues). Prefer `~/dotfiles`.
- WezTerm on Windows is installed by **`install.ps1` on the Windows host**. From WSL, the agent **can and should** run it via `powershell.exe` interop when the user wants the Windows half (see below). Do not use Linux `install.sh` for WezTerm on WSL.
- Do not run destructive git commands. Setup does not need force-push, reset --hard, etc.
- Ask before `sudo`-heavy full bootstraps if the user only wanted config links.

---

## Step 0 — Find the repo root

1. Prefer the workspace / git root that contains both `setup.sh` and `install.sh`.
2. If missing, look for `~/dotfiles` or `$HOME\dotfiles`.
3. If still missing, ask whether to clone:

   ```bash
   git clone https://github.com/chunkydamonkey/dotfiles.git ~/dotfiles
   ```

   On Windows (PowerShell), after `gh`/`git` exist:

   ```powershell
   gh repo clone chunkydamonkey/dotfiles "$HOME\dotfiles"
   ```

4. All following commands run from that repo root unless noted.

---

## Step 1 — Detect environment

Run detection commands and record a small profile. Do not guess.

### Kernel / OS

```bash
uname -s
uname -m
```

On Linux also:

```bash
cat /etc/os-release 2>/dev/null | head -20
# WSL?
grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && echo WSL=yes || echo WSL=no
```

On Windows (PowerShell):

```powershell
[System.Environment]::OSVersion.VersionString
$PSVersionTable.PSVersion
wsl -l -v   # if present; ignore failure
```

### Classify into exactly one primary path

| Detection | Path ID | Primary scripts |
|-----------|---------|-----------------|
| Linux + Ubuntu/Debian family + **not** WSL | `linux-native` | `./setup.sh` (full) or `./install.sh` (link only) |
| Linux + Ubuntu/Debian + **WSL** | `wsl` | `./setup.sh` for Linux side; remind user about Windows `install.ps1` for WezTerm |
| Linux but not Debian/Ubuntu | `linux-other` | `./install.sh` only (bootstrap apt scripts will refuse) |
| Darwin / macOS | `macos` | `./install.sh` only (no `setup.sh` apt bootstrap) |
| Windows (PowerShell / cmd / win32 agent host) | `windows` | winget tools + `install.ps1` |
| Unknown | stop and ask | — |

Also note:

- Is the agent shell already inside the repo?
- Does `~/.gitconfig.local` exist?
- Does `~/.ssh/id_ed25519` (or other default key) exist?
- Are `git`, `curl`, `gh`, `nvim`, `wezterm` on PATH?

Print a short detection summary to the user before asking options.

---

## Step 2 — Ask the user (optional steps)

Ask **once**, in one structured question batch when possible. Defaults below match script defaults for a **fresh machine**.

### Always clarify intent

- **Full setup** (packages + tools + link + identity/SSH) — default on new machines
- **Configs only** (link/symlink/junction — no package installers)
- **Dry-run first** (preview, no changes)
- **Custom** (pick options below)

### Options by path

#### `linux-native` / `wsl` (uses `./setup.sh` → `ubuntu/bootstrap.sh`)

| Option | Flag / action | Default for full setup |
|--------|----------------|------------------------|
| apt update/upgrade + `ubuntu/packages.txt` | always on for full; only step for `--packages-only` | on |
| Third-party tools (`ubuntu/tools.sh`: herdr, claude, codex, grok, treehouse) | omit → install; `--no-tools` to skip | **ask** (recommended on) |
| WezTerm apt install | omit → install; `--no-wezterm` to skip; **auto-skipped on WSL** by script | on for native; N/A on WSL |
| Link configs (`install.sh`) | part of full setup; skip with `--packages-only` | on |
| Git identity (`~/.gitconfig.local`) | script prompts if TTY; agent should collect if missing | on if missing |
| SSH key + optional GitHub upload | omit → run; `--no-ssh-key` to skip | **ask** (recommended on) |
| Dry-run | `--dry-run` | off unless user wants preview |

On **WSL**, after Linux setup, ask whether they also want the **Windows WezTerm** half. Prefer running it from WSL via Windows interop (no separate Windows clone required):

```bash
# From WSL when powershell.exe is on PATH (normal with WSL interop)
REPO_WIN="$(wslpath -w "$PWD")"   # or wslpath -w ~/dotfiles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${REPO_WIN}\\install.ps1"
```

`install.ps1` targets the WSL repo over `\\wsl.localhost\...` (symlink if Developer Mode/elevated; otherwise copies `wezterm/`). Also pins Windows `%USERPROFILE%` to Explorer Quick Access.

#### `macos` / `linux-other`

| Option | Action | Default |
|--------|--------|---------|
| Link configs | `./install.sh` | on |
| Dry-run | `./install.sh --dry-run` | off |
| Git identity | write `~/.gitconfig.local` if missing | ask if missing |
| SSH key | `./ubuntu/setup-ssh.sh` if present/usable, else guide manually | ask |
| Brew/apt package install | **not** provided by this repo’s setup.sh | do not invent |

#### `windows`

| Option | Action | Default for full setup |
|--------|--------|------------------------|
| Install Git | `winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements` | on if missing |
| Install GitHub CLI | `winget install --id GitHub.cli -e` | on if missing |
| Install WezTerm | `winget install --id wez.wezterm -e` | on if missing |
| Link WezTerm config | `powershell -ExecutionPolicy Bypass -File .\install.ps1` | on |
| `gh auth login` | interactive; agent starts or instructs | ask if not authed |
| WSL distro / Linux dotfiles | separate WSL clone + `./setup.sh` inside WSL | **ask** if WSL present |

### Collect git identity yourself when needed

If `~/.gitconfig.local` is missing and the user wants identity set, ask for **name** and **email**, then write:

```ini
[user]
	name  = <name>
	email = <email>
```

to `~/.gitconfig.local` with mode `600` if possible. Do not commit this file.

Prefer doing this **before** `./setup.sh` when the agent has no TTY for `read` prompts (bootstrap skips identity without a TTY).

---

## Step 3 — Execute by path

Confirm the plan in one short bullet list, then run.

### A. `linux-native` or `wsl` — full setup

Build flags from user answers:

```bash
cd "<repo-root>"
./setup.sh [--dry-run] [--packages-only] [--no-tools] [--no-wezterm] [--no-ssh-key]
```

Notes:

- Needs network + `sudo` for apt. If sudo fails, stop and tell the user.
- Vendor tool installers may take a while; do not background them unless the user asks.
- SSH step may offer `gh auth login` interactively — if non-interactive, generate key (if requested) and print the `.pub` + instructions for GitHub.
- After success: remind `exec bash -l` (or open a new shell).

Configs only:

```bash
./install.sh
# or
./install.sh --dry-run
```

Tools only:

```bash
./ubuntu/tools.sh
```

SSH only:

```bash
./ubuntu/setup-ssh.sh
```

### B. `macos` / `linux-other`

```bash
cd "<repo-root>"
./install.sh          # or --dry-run
```

WezTerm links on macOS/native Linux via `install.sh` (skipped only on WSL).

Optional:

```bash
./ubuntu/setup-ssh.sh   # if user wants SSH helper
```

Do **not** run `./setup.sh` on non-Debian/Ubuntu; it will error by design.

### C. `windows`

From a Windows shell (or when the agent host is Windows), roughly:

```powershell
# 1. Tools (skip any already installed)
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e

# 2. Auth (interactive)
gh auth login

# 3. WezTerm config — Windows clone:
powershell -ExecutionPolicy Bypass -File .\install.ps1
# Or WSL-only clone (no second git clone):
powershell -ExecutionPolicy Bypass -File ("$((wsl -e bash -lc 'wslpath -w ~/dotfiles').Trim())\install.ps1")
```

Then: launch WezTerm (or Ctrl+Shift+R if already open).

### D. Dual setup (Windows host + WSL) — agent on WSL can do both

Preferred layout (single Linux-FS clone is enough for day-to-day):

```
~/dotfiles in WSL
  ./setup.sh / install.sh     → shell, nvim, tmux, git
  powershell.exe + install.ps1 → Windows WezTerm + Explorer pin
```

When path ID is `wsl` and the user wants the Windows half:

1. Confirm `command -v powershell.exe` works.
2. Run:

   ```bash
   REPO_WIN="$(wslpath -w "$(cd "$(dirname "$0")" && pwd)" 2>/dev/null || wslpath -w "$HOME/dotfiles")"
   # from repo root:
   REPO_WIN="$(wslpath -w "$PWD")"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${REPO_WIN}\\install.ps1"
   ```

3. Report symlink vs copy mode from the script output.

Optional second Windows clone under `%USERPROFILE%\dotfiles` is fine but **not required**. Never put the WSL clone under `/mnt/c`.

---

## Step 4 — Verify

After applying changes (skip heavy checks on dry-run):

| Check | Command / expectation |
|-------|------------------------|
| Shell linked | `readlink ~/.bashrc` → repo `shell/bashrc` (Unix) |
| Git config include | `git config --get user.name` works if local identity set |
| nvim | `readlink ~/.config/nvim` → repo `nvim` (Unix) |
| WezTerm (native Linux/mac) | `readlink ~/.config/wezterm` → repo `wezterm` |
| WezTerm (Windows) | `$HOME\.config\wezterm` is a junction to repo `wezterm` |
| WezTerm (WSL) | **not** linked on Linux side — expected |
| Tools (if requested) | `command -v herdr claude codex grok treehouse` as applicable |
| SSH | `ls -l ~/.ssh/id_*.pub` if key step ran |

Fix obvious link failures by re-running `install.sh` / `install.ps1`. Do not delete user backups (`*.pre-dotfiles.*`).

---

## Step 5 — Report to the user

End with:

1. **Environment** detected (path ID + distro/WSL).
2. **What ran** (commands/flags).
3. **What was skipped** and why.
4. **Next interactive steps** they may still need:
   - `exec bash -l`
   - `gh auth login` / `ssh` test to GitHub
   - first-run logins for `claude` / `codex` / `grok`
   - first `nvim` launch (lazy.nvim bootstrap needs network once)
   - on WSL: Windows `install.ps1` if WezTerm not linked yet
5. **Day-two** reminder: `git pull` in the clone updates linked configs; re-run install only when new managed paths are added.

---

## Quick reference — script map

| Script | Role |
|--------|------|
| `setup.sh` | Ubuntu/Debian entry → `ubuntu/bootstrap.sh` |
| `ubuntu/bootstrap.sh` | apt, wezterm, tools, link, git identity, ssh |
| `ubuntu/packages.txt` | apt package list |
| `ubuntu/install-wezterm.sh` | WezTerm apt (skips WSL) |
| `ubuntu/tools.sh` | third-party CLI installers |
| `ubuntu/setup-ssh.sh` | ed25519 key + optional `gh` upload |
| `install.sh` | symlink configs (Linux/macOS; WezTerm skipped on WSL) |
| `install.ps1` | Windows junction for WezTerm only |

Flags for `setup.sh` / `bootstrap.sh`:

```
--dry-run          preview only
--packages-only    apt only (no wezterm, tools, link, ssh)
--no-tools         skip ubuntu/tools.sh
--no-wezterm       skip WezTerm apt install
--no-ssh-key       skip ubuntu/setup-ssh.sh
```

---

## Failure playbook

| Symptom | Likely fix |
|---------|------------|
| `setup.sh` errors “targets Ubuntu/Debian” | Use `install.sh` only; wrong path ID |
| WezTerm still cmd on Windows | Re-run `install.ps1`; fully quit WezTerm; confirm junction + WSL domain in `wezterm.lua` |
| WSL setup linked WezTerm unexpectedly | Should not happen; `install.sh` skips WezTerm on WSL — check `is_wsl` |
| No TTY → git identity skipped | Agent writes `~/.gitconfig.local` after asking user |
| `sudo` password / winget elevation | User must approve; do not loop |
| Tool installer failed | Continue other steps; re-run `./ubuntu/tools.sh` later |
| Clone on `/mnt/c` under WSL | Move/reclone to `~/dotfiles` on Linux FS |

---

## Example agent flow (condensed)

1. Detect → `wsl` + Debian.
2. Summary to user + ask: full setup? tools? ssh? also Windows WezTerm?
3. If git identity missing, collect name/email → write `~/.gitconfig.local`.
4. `./setup.sh` with agreed flags (e.g. default full, or `--no-tools`).
5. Verify symlinks; report; remind `exec bash -l` and optional Windows `install.ps1`.
