# Omarchy playbook

Use this when `/etc/os-release` has `ID=omarchy`. Run `./setup.sh`. It dispatches to `omarchy/bootstrap.sh`. Do not run `ubuntu/bootstrap.sh`. Do not run the Ubuntu symlink list in `install.sh`.

## Never

- Replace `~/.bashrc`. The linker appends a marked block that sources `shell/omarchy.bash`.
- Create `~/.tmux.conf`. tmux would ignore `~/.config/tmux/tmux.conf`.
- Run `apt`, or install WezTerm from the Ubuntu apt repo. On Omarchy the package is `wezterm` from Arch.
- Generate an SSH key.
- Write `~/.gitconfig.local` when `git config --global user.name` is already set.

## Always

- `omarchy pkg add git github-cli git-lfs wezterm` for anything missing. `git-lfs` is required because `shell/gitconfig.omarchy` marks the LFS filter required.
- Install Tailscale with `omarchy-install-service-tailscale` when `omarchy-installed-service-tailscale` fails. That is Omarchy's own installer: the package, `tailscaled`, `tailscale up` (the user logs in), the menu bar plugin, and Taildrop into `~/Downloads`. Do not use the old `tsui` sudoers grant.
- Append the shell snippet and the git include (`core.editor`, `gh` credential helper, LFS). Name and email stay in Omarchy's `~/.config/git/config`.
- Link `wezterm/` to `~/.config/wezterm`, install `omarchy/org.wezfurlong.wezterm.desktop` so Super+Return can pass a working directory, and put that desktop id first in `~/.config/xdg-terminals.list`. `omarchy default terminal` cannot name WezTerm; this list is how Omarchy launches it.
- Set Google Chrome as default browser (`google-chrome.desktop`) via `xdg-settings` / `omarchy default browser chrome`.
- Link `omarchy/hypr/bindings.lua` and `omarchy/hypr/input.lua` into `~/.config/hypr/` (vim-style Super+h/j/k/l focus and swap, Super+M full width, Windows-style recent Super+Tab and Alt+Tab, three-finger workspace swipe). After `omarchy refresh hyprland`, re-run `omarchy/install.sh` so the links come back.

## Ask first

Defaults are skip.

| Question | If yes |
|----------|--------|
| Replace LazyVim with the repo Neovim config? | `./setup.sh --nvim` |
| Install herdr? | `curl -fsSL https://herdr.dev/install.sh \| sh` |
| Install Claude Code? | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Install Codex? | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` |
| Install treehouse? | `curl -fsSL https://kunchenguid.github.io/treehouse/install.sh \| sh` |

Grok is already the harness. Do not install it again. WezTerm is installed by the package step above, not by `ubuntu/install-wezterm.sh`.

If `gh auth status` fails, stop after the safe linker and tell the user to run `gh auth login`, then `./ubuntu/install-agent-skills.sh`. Do not clone `agent-skills` before that login.

## Flags

```
./setup.sh                 # packages, safe links, agent-skills if gh is logged in
./setup.sh --dry-run
./setup.sh --nvim          # also back up ~/.config/nvim and link the repo config
./setup.sh --no-skills
```

## Verify

- `~/.bashrc` is still a regular file and contains `# >>> dotfiles omarchy >>>`.
- `~/.config/git/config` includes `shell/gitconfig.omarchy`. `git config --global user.name` is unchanged.
- `~/.tmux.conf` does not exist because of this run.
- `readlink ~/.config/wezterm` points at the repo `wezterm/` directory.
- `xdg-terminal-exec --print-id` prints `org.wezfurlong.wezterm.desktop`.
- `omarchy-cmd-default-browser` (or `xdg-settings get default-web-browser`) prints `google-chrome.desktop`.
- `readlink ~/.config/hypr/bindings.lua` and `input.lua` point at the repo `omarchy/hypr/` files.
- `readlink ~/.config/nvim` points at the repo only when `--nvim` was passed.
- `gh auth status` succeeds before `~/agent-skills` is expected.
