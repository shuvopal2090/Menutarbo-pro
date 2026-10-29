# fetch-resources.ps1 — restore the large binary assets excluded from this
# repository (fonts + background music, ~206 MB).
#
# Usage (PowerShell, from the repo root):
#   .\scripts\fetch-resources.ps1
#
# If blocked by execution policy:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$ErrorActionPreference = "Stop"

$Upstream = "harry0703/MoneyPrinterTurbo"
$Commit   = "dd5ee71a0fbbb2c06401a7a4401bc83830a7c4d1"
$Archive  = "https://codeload.github.com/$Upstream/zip/$Commit"

Set-Location (Join-Path $PSScriptRoot "..")

$existing = @()
$existing += Get-ChildItem "resource/fonts" -Filter *.ttc -ErrorAction SilentlyContinue
$existing += Get-ChildItem "resource/songs" -Filter *.mp3 -ErrorAction SilentlyContinue
if ($existing.Count -ge 33) {
  Write-Host "Resources already present ($($existing.Count) files). Nothing to do."
  return
}

Write-Host "This will download ~206 MB from $Upstream @ $($Commit.Substring(0,7))"
Write-Host "Into: $((Get-Location).Path)\resource\{fonts,songs}"
Write-Host ""

$tmp = Join-Path $env:TEMP ("mpt-res-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
  $zip = Join-Path $tmp "src.zip"
  Write-Host "Downloading archive..."
  Invoke-WebRequest -Uri $Archive -OutFile $zip -UseBasicParsing

  Write-Host "Extracting..."
  Expand-Archive -Path $zip -DestinationPath $tmp -Force

  $root = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like "MoneyPrinterTurbo-*" } | Select-Object -First 1
  if (-not $root) { throw "Unexpected archive layout — extract $Archive manually into resource/" }

  New-Item -ItemType Directory -Path "resource/fonts" -Force | Out-Null
  New-Item -ItemType Directory -Path "resource/songs" -Force | Out-Null

  $fonts = Join-Path $root.FullName "resource/fonts"
  $songs = Join-Path $root.FullName "resource/songs"

  if (Test-Path $fonts) { Copy-Item (Join-Path $fonts "*.ttc") "resource/fonts/" -Force }
  if (Test-Path $songs) { Copy-Item (Join-Path $songs "*.mp3") "resource/songs/" -Force }

  $f = (Get-ChildItem "resource/fonts" -Filter *.ttc -ErrorAction SilentlyContinue).Count
  $s = (Get-ChildItem "resource/songs" -Filter *.mp3 -ErrorAction SilentlyContinue).Count
  $mb = [math]::Round(((Get-ChildItem "resource" -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)

  Write-Host ""
  Write-Host "Done: $f font files (.ttc), $s songs (.mp3)" -ForegroundColor Green
  Write-Host "Total resource size: $mb MB"
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
