#!/usr/bin/env bash
# Install the private, pinned cross-harness skill registry.
# Existing repositories must be clean and use the expected GitHub remote.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_file="$repo_root/agent-skills.lock"
dry_run=0
home_dir="$HOME"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1; shift ;;
    --home)
      [ "$#" -ge 2 ] || { echo "error: --home requires a path" >&2; exit 2; }
      home_dir="$2"
      shift 2
      ;;
    -h|--help)
      echo "usage: $0 [--dry-run] [--home PATH]"
      exit 0
      ;;
    *) echo "usage: $0 [--dry-run] [--home PATH]" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { say "error: $*" >&2; exit 1; }

[ -f "$lock_file" ] || die "lock file missing: $lock_file"
repo_url="$(sed -n 's/^repo=//p' "$lock_file")"
locked_ref="$(sed -n 's/^ref=//p' "$lock_file")"
[ "$(grep -c '^repo=' "$lock_file")" -eq 1 ] || die "lock must contain exactly one repo entry"
[ "$(grep -c '^ref=' "$lock_file")" -eq 1 ] || die "lock must contain exactly one ref entry"
[ -n "$repo_url" ] || die "lock repo is empty"
[ "${#locked_ref}" -eq 40 ] || die "lock ref must be a full 40-character commit"
case "$locked_ref" in *[!0-9a-f]*) die "lock ref must be lowercase hexadecimal" ;; esac

checkout="$home_dir/agent-skills"
backup_root="$home_dir/.local/state/agent-skills/backups/$(date +%Y%m%d-%H%M%S)"

normalize_remote() {
  case "$1" in
    git@github.com:*) value="github.com/${1#git@github.com:}" ;;
    https://github.com/*) value="github.com/${1#https://github.com/}" ;;
    *) value="$1" ;;
  esac
  printf '%s\n' "${value%.git}"
}

github_slug() {
  case "$1" in
    git@github.com:*.git) printf '%s\n' "${1#git@github.com:}" | sed 's/\.git$//' ;;
    https://github.com/*.git) printf '%s\n' "${1#https://github.com/}" | sed 's/\.git$//' ;;
    *) return 1 ;;
  esac
}

ssh_key_present() {
  local key
  for key in id_ed25519 id_rsa id_ecdsa id_ed25519_sk; do
    [ -f "$HOME/.ssh/$key" ] && return 0
  done
  return 1
}

use_gh_clone() {
  github_slug "$repo_url" >/dev/null \
    && ! ssh_key_present \
    && command -v gh >/dev/null 2>&1 \
    && gh auth status >/dev/null 2>&1
}

say "== personal agent skills =="
if [ ! -e "$checkout" ]; then
  if [ "$dry_run" -eq 1 ]; then
    if use_gh_clone; then
      say "PLAN  gh repo clone $(github_slug "$repo_url") $checkout"
    else
      say "PLAN  git clone $repo_url $checkout"
    fi
    say "PLAN  check out pinned commit $locked_ref"
    say "PLAN  link skills into harness discovery roots and run doctor"
    exit 0
  fi
  if use_gh_clone; then
    gh repo clone "$(github_slug "$repo_url")" "$checkout"
  else
    git clone "$repo_url" "$checkout"
  fi
elif [ ! -d "$checkout/.git" ]; then
  die "$checkout exists but is not a Git repository"
fi

actual_remote="$(git -C "$checkout" remote get-url origin 2>/dev/null || true)"
[ -n "$actual_remote" ] || die "$checkout has no origin remote"
[ "$(normalize_remote "$actual_remote")" = "$(normalize_remote "$repo_url")" ] ||
  die "$checkout origin is $actual_remote; expected $repo_url"

if [ -n "$(git -C "$checkout" status --porcelain)" ]; then
  die "$checkout has local changes; commit or move them before installing the pinned version"
fi

current_ref="$(git -C "$checkout" rev-parse HEAD)"
if [ "$current_ref" != "$locked_ref" ]; then
  if [ "$dry_run" -eq 1 ]; then
    say "PLAN  move $checkout from $current_ref to pinned commit $locked_ref"
  else
    git -C "$checkout" fetch origin "$locked_ref"
    git -C "$checkout" checkout --detach "$locked_ref"
  fi
else
  say "ok    pinned commit $locked_ref"
fi

[ -x "$checkout/bin/skills" ] || die "$checkout/bin/skills is missing or not executable"
if [ "$dry_run" -eq 1 ]; then
  "$checkout/bin/skills" link --home "$home_dir" --backup-existing "$backup_root"
  say "Dry run complete — no skill links changed."
  exit 0
fi

resolved_ref="$(git -C "$checkout" rev-parse HEAD)"
[ "$resolved_ref" = "$locked_ref" ] || die "checkout did not resolve to locked commit"
"$checkout/bin/skills" link --home "$home_dir" --apply --backup-existing "$backup_root"
"$checkout/bin/skills" doctor --home "$home_dir"
