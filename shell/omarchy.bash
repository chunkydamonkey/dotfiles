# Personal shell habits for Omarchy.
# Sourced from the bottom of ~/.bashrc by omarchy/install.sh.
# That file stays Omarchy's. Nothing here replaces Starship or Omarchy aliases.

[[ $- != *i* ]] && return

# ── History ──────────────────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=erasedups:ignoredups:ignorespace
HISTTIMEFORMAT="%F %T  "
shopt -s histappend
shopt -s cmdhist
shopt -s checkwinsize
shopt -s globstar
shopt -s autocd
shopt -s cdspell

# ── Editor and clipboard ─────────────────────────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim

if command -v wl-copy >/dev/null 2>&1; then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
fi

# Git shortcuts Omarchy does not already define (g and gcm stay Omarchy's).
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -v'
alias gpl='git pull --rebase'
alias glog='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gcb='git checkout -b'
alias grb='git rebase'
alias gst='git stash'
alias gstp='git stash pop'

mkdirg() { mkdir -p "$1" && cd "$1"; }

up() {
  local d
  for ((i = 0; i < ${1:-1}; i++)); do d="../$d"; done
  cd "${d:-.}"
}

extract() {
  local f
  for f in "$@"; do
    if [[ ! -f "$f" ]]; then
      echo "'$f' is not a file"
      continue
    fi
    case "$f" in
      *.tar.bz2 | *.tbz2) tar xvjf "$f" ;;
      *.tar.gz | *.tgz) tar xvzf "$f" ;;
      *.tar.xz) tar xvJf "$f" ;;
      *.tar) tar xvf "$f" ;;
      *.bz2) bunzip2 "$f" ;;
      *.gz) gunzip "$f" ;;
      *.zip) unzip "$f" ;;
      *.7z) 7z x "$f" ;;
      *.rar) unrar x "$f" ;;
      *) echo "Don't know how to extract '$f'" ;;
    esac
  done
}

# ed25519 only. A missing key must not hang the shell.
_ssh_agent_env="$HOME/.ssh/agent.env"
_ssh_add_keys() {
  local key="$HOME/.ssh/id_ed25519"
  [[ -f "$key" ]] && ssh-add "$key" 2>/dev/null
}
_start_agent() {
  mkdir -p "$HOME/.ssh"
  ssh-agent >"$_ssh_agent_env"
  chmod 600 "$_ssh_agent_env"
  # shellcheck disable=SC1090
  . "$_ssh_agent_env" >/dev/null
  _ssh_add_keys
}
if [[ -f "$_ssh_agent_env" ]]; then
  # shellcheck disable=SC1090
  . "$_ssh_agent_env" >/dev/null
  if ! kill -0 "${SSH_AGENT_PID:-}" 2>/dev/null; then
    _start_agent
  else
    _ssh_add_keys
  fi
else
  _start_agent
fi
unset _ssh_agent_env
