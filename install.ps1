# Bootstrap the Windows host half of these dotfiles. No admin required
# when the repo is on a Windows drive (junction). From a WSL clone use a
# symlink (needs Developer Mode or an elevated shell once).
#
# Run from a Windows clone:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# Run using the WSL clone (no second Windows git clone needed):
#   powershell -ExecutionPolicy Bypass -File ("$((wsl -e bash -lc 'wslpath -w ~/dotfiles').Trim())\install.ps1")
#
#   1. Link WezTerm config into ~/.config/wezterm
#   2. Pin the user home folder to File Explorer Quick Access (left nav)
#   3. Install Tailscale via winget when missing (may prompt for admin)
#   4. Link agents/AGENTS.md for Claude Code, Grok and Codex (copy without symlink rights)
$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $repo "wezterm"
$dst  = Join-Path $HOME ".config\wezterm"

if (-not (Test-Path -LiteralPath $src)) {
  throw "WezTerm config not found: $src"
}

# Remove any legacy single-file config that would shadow ~/.config/wezterm.
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".wezterm.lua")
# Old per-user font folder is no longer needed (fonts now live in the repo).
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".wezfonts")

New-Item -ItemType Directory -Force -Path (Join-Path $HOME ".config") | Out-Null

# Clear an existing link/dir at the destination. Deleting a junction/symlink
# removes only the link, never the target's contents.
if (Test-Path -LiteralPath $dst) {
  $item = Get-Item -LiteralPath $dst -Force
  if ($item.LinkType) { $item.Delete() } else { Remove-Item -LiteralPath $dst -Recurse -Force }
}

# Junctions only work on local Win32 paths. A repo under \\wsl$\... / \\wsl.localhost\...
# needs a directory symlink (Developer Mode or elevated once). If that fails, copy
# the folder so a WSL-only clone still works without admin (re-run after config edits).
$isUnc = $src.StartsWith("\\")
$linkType = if ($isUnc) { "SymbolicLink" } else { "Junction" }
$mode = $null
try {
  New-Item -ItemType $linkType -Path $dst -Target $src | Out-Null
  $mode = $linkType
} catch {
  if (-not $isUnc) { throw }
  Write-Host "warn   $linkType failed (need Developer Mode or elevated PowerShell): $_"
  Write-Host "warn   falling back to a copy of wezterm/ (re-run install.ps1 after config changes)"
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
  $mode = "Copy"
}
Write-Host "Installed ($mode) $dst  <-  $src"

# One rules file for every coding agent run from PowerShell: Claude Code,
# Grok, Codex. A file symlink needs Developer Mode or an elevated shell; without
# either, the file is copied (re-run install.ps1 after editing agents/AGENTS.md).
# A real file already at a target is renamed, never deleted.
function Install-AgentRules {
  $rules = Join-Path $repo "agents\AGENTS.md"
  if (-not (Test-Path -LiteralPath $rules)) {
    Write-Host "warn   agent rules not found: $rules"
    return
  }
  $targets = @(
    (Join-Path $HOME ".claude\CLAUDE.md"),
    (Join-Path $HOME ".grok\rules\AGENTS.md"),
    (Join-Path $HOME ".codex\AGENTS.md")
  )
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  foreach ($target in $targets) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    if (Test-Path -LiteralPath $target) {
      $item = Get-Item -LiteralPath $target -Force
      if ($item.LinkType) {
        $item.Delete()
      } elseif ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $rules).Hash) {
        $backup = "$target.pre-dotfiles.$stamp"
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "backup $target  ->  $backup"
      } else {
        Remove-Item -LiteralPath $target -Force
      }
    }
    try {
      New-Item -ItemType SymbolicLink -Path $target -Target $rules | Out-Null
      Write-Host "link   $target  ->  $rules"
    } catch {
      Copy-Item -LiteralPath $rules -Destination $target -Force
      Write-Host "copy   $target  <-  $rules  (no symlink rights; re-run after editing the rules)"
    }
  }
}

Install-AgentRules

# Pin %USERPROFILE% to File Explorer Quick Access (left sidebar).
# pintohome toggles - only invoke when not already pinned.
function Test-QuickAccessPinned {
  param([Parameter(Mandatory)][string]$Path)
  $full = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
  $shell = New-Object -ComObject Shell.Application
  # Quick Access namespace (also surfaces as Home favorites on Win11)
  $qa = $shell.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
  if (-not $qa) { return $false }
  foreach ($item in @($qa.Items())) {
    try {
      $p = [string]$item.Path
      if (-not $p) { continue }
      if ($p.TrimEnd('\') -ieq $full) { return $true }
    } catch { }
  }
  return $false
}

function Add-QuickAccessPin {
  param([Parameter(Mandatory)][string]$Path)
  $full = (Resolve-Path -LiteralPath $Path).Path
  if (Test-QuickAccessPinned -Path $full) {
    Write-Host "ok     Quick Access already pins $full"
    return
  }
  $shell = New-Object -ComObject Shell.Application
  $folder = $shell.Namespace($full)
  if (-not $folder) {
    Write-Host "warn   could not open shell namespace for $full"
    return
  }
  $folder.Self.InvokeVerb("pintohome")
  Write-Host "pinned Quick Access <- $full"
}

Add-QuickAccessPin -Path $HOME

# Tailscale covers this Windows host (and therefore WSL). Install when missing.
function Install-Tailscale {
  $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
  $tailscaleExe = Join-Path $env:ProgramFiles "Tailscale\tailscale.exe"
  if ($tailscaleCmd -or (Test-Path -LiteralPath $tailscaleExe)) {
    Write-Host "ok     Tailscale already installed"
    return
  }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "warn   winget missing — install Tailscale from https://tailscale.com/download/windows"
    return
  }
  Write-Host "Installing Tailscale (may prompt for admin)..."
  winget install -e --id Tailscale.Tailscale --accept-package-agreements --accept-source-agreements
  Write-Host "Open the Tailscale app and sign in."
}

Install-Tailscale

Write-Host "Launch WezTerm (or press Ctrl+Shift+R) to load it."
Write-Host "Open File Explorer - your home folder should be on the left (Quick Access / Home)."
