# make-clean-zip.ps1 — build an upload-ready zip of a project on Windows,
# excluding dependencies, build output, caches and secrets.
#
# Usage (PowerShell):
#   .\make-clean-zip.ps1 -Path C:\Users\me\Menutarbo-pro
#   .\make-clean-zip.ps1 -Path C:\Users\me\Menutarbo-pro -Out C:\out.zip
#
#   If blocked by execution policy, run once:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

param(
  [string]$Path = ".",
  [string]$Out  = ""
)

$ErrorActionPreference = "Stop"

$src = (Resolve-Path $Path).Path
if (-not $Out) {
  $Out = Join-Path (Split-Path $src -Parent) ((Split-Path $src -Leaf) + "-clean.zip")
}

# Always excluded, whatever size they are.
$excludeDirs = @(
  'node_modules','bower_components','vendor',
  'dist','build','out','.next','.nuxt','.output','.svelte-kit',
  '.turbo','.parcel-cache','.vite','coverage','target',
  '.git','.cache','__pycache__','.pytest_cache','.mypy_cache','.ruff_cache',
  '.venv','venv','env','.idea'
)
$excludeFiles = @(
  '.DS_Store','Thumbs.db',
  '*.log','*.sqlite','*.sqlite3','*.db',
  '*.mp4','*.mov','*.avi','*.mkv',
  '*.zip','*.rar','*.7z','*.tar','*.gz',
  '.env','.env.local','.env.production'
)

Write-Host "Project : $src"
Write-Host "Output  : $Out"
Write-Host ""

# Report the space being saved before we build anything.
Write-Host "Biggest excluded folders:"
foreach ($d in $excludeDirs) {
  $full = Join-Path $src $d
  if (Test-Path $full) {
    $mb = [math]::Round(((Get-ChildItem $full -Recurse -Force -ErrorAction SilentlyContinue |
           Measure-Object -Property Length -Sum).Sum) / 1MB, 1)
    Write-Host ("  {0,8} MB  {1}" -f $mb, $d)
  }
}
Write-Host ""

if (Test-Path $Out) { Remove-Item $Out -Force }

$files = Get-ChildItem $src -Recurse -Force -File | Where-Object {
  $rel = $_.FullName.Substring($src.Length).TrimStart('\')
  $parts = $rel -split '\\'

  # Any directory segment in the exclude list skips the file.
  $badDir = $false
  foreach ($p in $parts[0..([Math]::Max(0, $parts.Count - 2))]) {
    if ($excludeDirs -contains $p) { $badDir = $true; break }
  }
  if ($badDir) { return $false }

  foreach ($pat in $excludeFiles) {
    if ($_.Name -like $pat) { return $false }
  }
  return $true
}

if (-not $files) { Write-Error "No files matched — check the -Path value."; exit 1 }

Write-Host ("Compressing {0} files..." -f $files.Count)
Compress-Archive -Path $files.FullName -DestinationPath $Out -CompressionLevel Optimal

$size = (Get-Item $Out).Length
$mb = [math]::Round($size / 1MB, 1)
Write-Host ""
Write-Host ("Created {0}  ({1} MB)" -f $Out, $mb)

if ($size -gt 100MB) {
  Write-Host ""
  Write-Host "WARNING: over 100 MB — GitHub rejects this. Find the culprits with:"
  Write-Host "  Get-ChildItem '$src' -Recurse -File | Where-Object Length -gt 5MB | Sort-Object Length -Descending | Select-Object -First 20 FullName,Length"
} elseif ($size -gt 50MB) {
  Write-Host ""
  Write-Host "NOTE: over 50 MB — GitHub will warn. Likely large media assets."
}

Write-Host ""
Write-Host "Now upload $Out"
