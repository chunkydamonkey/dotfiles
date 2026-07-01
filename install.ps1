# Bootstrap the WezTerm config on Windows. No admin required (uses a junction).
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $repo "wezterm"
$dst  = Join-Path $HOME ".config\wezterm"

# Remove any legacy single-file config that would shadow ~/.config/wezterm.
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".wezterm.lua")
# Old per-user font folder is no longer needed (fonts now live in the repo).
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME ".wezfonts")

New-Item -ItemType Directory -Force -Path (Join-Path $HOME ".config") | Out-Null

# Clear an existing link/dir at the destination. Deleting a junction removes
# only the link, never the target's contents.
if (Test-Path $dst) {
  $item = Get-Item $dst -Force
  if ($item.LinkType) { $item.Delete() } else { Remove-Item -Recurse -Force $dst }
}

New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
Write-Host "Linked $dst  ->  $src"
Write-Host "Launch WezTerm (or press Ctrl+Shift+R) to load it."
