# setup.ps1 — one command to get this app running from a fresh clone on Windows.
#
#   .\scripts\setup.ps1                   # full setup
#   .\scripts\setup.ps1 -SkipResources     # skip the 206 MB asset download
#   .\scripts\setup.ps1 -Force             # rebuild the venv from scratch
#
# If PowerShell blocks scripts:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

param(
  [switch]$SkipResources,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root
$Venv = Join-Path $Root ".venv"

function Say  ($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor White }
function Ok   ($m) { Write-Host "    $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Die  ($m) { Write-Host ""; Write-Host "error: $m" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. python
Say "Checking Python"

$PythonExe = $null
$PythonArgs = @()
foreach ($cand in @("python", "python3", "py")) {
  $cmd = Get-Command $cand -ErrorAction SilentlyContinue
  if (-not $cmd) { continue }

  $base = if ($cand -eq "py") { @("-3") } else { @() }
  $probe = $base + @("-c", "import sys;print(sys.version_info[0],sys.version_info[1])")

  try {
    $out = & $cmd.Source @probe 2>$null
    if ($LASTEXITCODE -ne 0) { continue }
    $parts = (($out -join " ").Trim() -split "\s+")
    if ($parts.Count -ge 2 -and [int]$parts[0] -ge 3 -and [int]$parts[1] -ge 11) {
      $PythonExe = $cmd.Source
      $PythonArgs = $base
      break
    }
  } catch { continue }
}

if (-not $PythonExe) {
  Die "Python 3.11+ not found. Install from https://www.python.org/downloads/ and tick 'Add python.exe to PATH'."
}
Ok (& $PythonExe @PythonArgs --version 2>&1)

# ------------------------------------------------------------------- 2. venv
Say "Virtual environment"
if ($Force -and (Test-Path $Venv)) {
  Warn "removing existing .venv (-Force)"
  Remove-Item $Venv -Recurse -Force
}
if (-not (Test-Path $Venv)) {
  & $PythonExe @PythonArgs -m venv $Venv
  if ($LASTEXITCODE -ne 0) { Die "could not create the virtual environment" }
  Ok "created .venv"
} else {
  Ok ".venv already exists"
}

$Vpy = Join-Path $Venv "Scripts\python.exe"
if (-not (Test-Path $Vpy)) { Die "venv python not found at $Vpy" }

# ------------------------------------------------------------ 3. dependencies
Say "Dependencies"
& $Vpy -m pip install --quiet --upgrade pip

& $Vpy -c "import streamlit, fastapi, moviepy, faster_whisper, edge_tts, imageio_ffmpeg" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "    installing requirements.txt (this takes a few minutes)..."
  & $Vpy -m pip install -r requirements.txt
  if ($LASTEXITCODE -ne 0) { Die "dependency install failed" }
  Ok "installed from requirements.txt"
} else {
  & $Vpy -m pip install --quiet -r requirements.txt
  Ok "already satisfied"
}

# ---------------------------------------------------------------- 4. config
Say "Configuration"
$Cfg = Join-Path $Root "config.toml"
if (Test-Path $Cfg) {
  Ok "config.toml exists (left untouched)"
} else {
  Copy-Item (Join-Path $Root "config.example.toml") $Cfg
  Ok "created config.toml from config.example.toml"
}

# ---------------------------------------------------------------- 5. assets
Say "Runtime assets"
if ($SkipResources) {
  Warn "skipped (-SkipResources); subtitles and BGM will be limited"
} else {
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fetch-resources.ps1")
    if ($LASTEXITCODE -ne 0) { Warn "asset download failed — run .\scripts\fetch-resources.ps1 again" }
  } catch {
    Warn "asset download failed: $($_.Exception.Message)"
  }
}

# -------------------------------------------------------------- 6. preflight
Say "Preflight check"
& $Vpy (Join-Path $PSScriptRoot "doctor.py")
$status = $LASTEXITCODE

Write-Host ""
if ($status -eq 0) {
  Write-Host "Ready. Start the app with:" -ForegroundColor Green
  Write-Host ""
  Write-Host "  .\.venv\Scripts\python.exe scripts\run.py web     # WebUI  http://localhost:8501"
  Write-Host "  .\.venv\Scripts\python.exe scripts\run.py api     # API    http://localhost:8080/docs"
  Write-Host ""
} else {
  Write-Host "Setup finished with blocking issues — see the FAIL lines above." -ForegroundColor Yellow
}
exit $status
