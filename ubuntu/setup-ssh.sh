#!/usr/bin/env bash
# One-shot SSH key for this machine (never committed to the repo).
#
#   1. If no default key → generate ~/.ssh/id_ed25519 (ed25519, no passphrase)
#   2. Ensure ssh-agent can load it (best-effort)
#   3. If gh is authenticated → upload public key (idempotent by title/fingerprint)
#   4. Else if TTY → offer gh auth login, then upload
#
# Private keys stay in $HOME only (.gitignore already blocks .ssh/ and id_*).
#
# Usage:
#   ./ubuntu/setup-ssh.sh
#   ./ubuntu/setup-ssh.sh --dry-run
# Called from setup.sh / ubuntu/bootstrap.sh unless --no-ssh-key.
set -euo pipefail

dry_run=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--dry-run]" >&2
      exit 2
      ;;
  esac
done

say() { printf '%s\n' "$*"; }

key_path="$HOME/.ssh/id_ed25519"
pub_path="${key_path}.pub"

# Prefer email from machine-local git identity (set earlier in bootstrap).
ssh_comment=""
if command -v git >/dev/null 2>&1; then
  ssh_comment="$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || true)"
  if [ -z "$ssh_comment" ]; then
    ssh_comment="$(git config user.email 2>/dev/null || true)"
  fi
fi
if [ -z "$ssh_comment" ]; then
  ssh_comment="$(whoami)@$(hostname -s 2>/dev/null || hostname)"
fi

host_title="$(hostname -s 2>/dev/null || hostname)-$(date +%Y%m%d)"

say "== ssh key (this machine only) =="

# Already have any default key?
existing=""
for cand in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_rsa"; do
  if [ -f "$cand" ]; then
    existing="$cand"
    break
  fi
done

if [ -n "$existing" ]; then
  say "ok    found $existing"
  key_path="$existing"
  pub_path="${existing}.pub"
elif [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> ssh-keygen -t ed25519 -f $key_path -C \"$ssh_comment\" -N \"\""
else
  say "create $key_path (ed25519, empty passphrase — disk encryption recommended)"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$key_path" -C "$ssh_comment" -N "" -q
  chmod 600 "$key_path"
  chmod 644 "$pub_path"
  say "wrote $key_path"
  say "      $pub_path"
fi

if [ "$dry_run" -eq 1 ]; then
  say "  DRY-RUN> would ensure agent + optional gh ssh-key add --title $host_title"
  exit 0
fi

if [ ! -f "$pub_path" ]; then
  say "warn  no public key at $pub_path — skip GitHub upload"
  exit 0
fi

# Best-effort: load into agent if one is available
if command -v ssh-add >/dev/null 2>&1; then
  ssh-add "$key_path" 2>/dev/null || true
fi

say "pubkey:"
sed 's/^/  /' "$pub_path"

gh_ready=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh_ready=1
fi

if [ "$gh_ready" -eq 0 ] && command -v gh >/dev/null 2>&1 && [ -t 0 ]; then
  say ""
  say "GitHub CLI is not logged in. Log in now to register this key? [Y/n]"
  printf "  > "
  read -r ans || ans=n
  case "${ans:-Y}" in
    n|N|no|NO) say "skip  gh auth — add the pubkey on GitHub later if you want SSH git" ;;
    *)
      # HTTPS is enough for gh; SSH protocol can use the new key after upload.
      if gh auth login; then
        gh_ready=1
      else
        say "warn  gh auth login failed — key is local only for now"
      fi
      ;;
  esac
fi

if [ "$gh_ready" -eq 1 ]; then
  # Idempotent: compare material (type + key) to keys already on the account.
  already=0
  pub_body="$(awk '{print $1" "$2}' "$pub_path")"
  if gh api user/keys --jq '.[].key' 2>/dev/null | grep -Fqx "$pub_body"; then
    already=1
  fi

  if [ "$already" -eq 1 ]; then
    say "ok    this public key is already on your GitHub account"
  else
    say "upload to GitHub as: $host_title"
    if gh ssh-key add "$pub_path" --title "$host_title"; then
      say "ok    registered with GitHub"
    else
      say "warn  gh ssh-key add failed — paste $pub_path into GitHub → Settings → SSH keys"
    fi
  fi
elif ! command -v gh >/dev/null 2>&1; then
  say "tip   install gh (packages.txt) then: gh auth login && gh ssh-key add $pub_path --title \"$host_title\""
else
  say "tip   later: gh auth login && gh ssh-key add $pub_path --title \"$host_title\""
fi
