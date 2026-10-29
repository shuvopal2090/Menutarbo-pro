#!/usr/bin/env bash
# setup.sh — one command to get this app running from a fresh clone.
#
#   bash scripts/setup.sh                  # full setup
#   bash scripts/setup.sh --skip-resources # skip the 206 MB asset download
#   bash scripts/setup.sh --force          # rebuild the venv from scratch
#
# Steps: python check -> venv -> dependencies -> config -> assets -> preflight.
# Safe to re-run: every step is skipped when it is already satisfied.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)

SKIP_RESOURCES=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --skip-resources) SKIP_RESOURCES=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

VENV="$ROOT/.venv"
PY=""

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m%s\033[0m\n' "$1"; }
warn() { printf '    \033[33m%s\033[0m\n' "$1"; }
die()  { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- 1. python
say "Checking Python"
for cand in python3.13 python3.12 python3.11 python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then
    if "$cand" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,11) else 1)' 2>/dev/null; then
      PY=$(command -v "$cand")
      break
    fi
  fi
done
[ -n "$PY" ] || die "Python 3.11+ not found. Install it from https://www.python.org/downloads/"
ok "$("$PY" --version) at $PY"

# ------------------------------------------------------------------- 2. venv
say "Virtual environment"
if [ "$FORCE" = "1" ] && [ -d "$VENV" ]; then
  warn "removing existing .venv (--force)"
  rm -rf "$VENV"
fi
if [ ! -d "$VENV" ]; then
  "$PY" -m venv "$VENV"
  ok "created .venv"
else
  ok ".venv already exists"
fi
VPY="$VENV/bin/python"
[ -x "$VPY" ] || VPY="$VENV/Scripts/python.exe"
[ -x "$VPY" ] || die "venv python not found in $VENV"

# ------------------------------------------------------------ 3. dependencies
say "Dependencies"
"$VPY" -m pip install --quiet --upgrade pip
if ! "$VPY" -c 'import streamlit, fastapi, moviepy, faster_whisper, edge_tts, imageio_ffmpeg' 2>/dev/null; then
  "$VPY" -m pip install -r requirements.txt
  ok "installed from requirements.txt"
else
  # Already satisfied; still reconcile in case the pins changed.
  "$VPY" -m pip install --quiet -r requirements.txt
  ok "already satisfied"
fi

# ---------------------------------------------------------------- 4. config
say "Configuration"
if [ -f "$ROOT/config.toml" ]; then
  ok "config.toml exists (left untouched)"
else
  cp "$ROOT/config.example.toml" "$ROOT/config.toml"
  ok "created config.toml from config.example.toml"
fi

# ---------------------------------------------------------------- 5. assets
say "Runtime assets"
if [ "$SKIP_RESOURCES" = "1" ]; then
  warn "skipped (--skip-resources); subtitles and BGM will be limited"
else
  bash scripts/fetch-resources.sh || warn "asset download failed — re-run: bash scripts/fetch-resources.sh"
fi

# -------------------------------------------------------------- 6. preflight
say "Preflight check"
set +e
"$VPY" scripts/doctor.py
status=$?
set -e

printf '\n'
if [ "$status" -eq 0 ]; then
  printf '\033[32mReady.\033[0m Start the app with:\n\n'
  printf '  %s scripts/run.py web     # WebUI  http://localhost:8501\n' "$VPY"
  printf '  %s scripts/run.py api     # API    http://localhost:8080/docs\n\n' "$VPY"
else
  printf '\033[33mSetup finished with blocking issues — see the FAIL lines above.\033[0m\n'
fi
exit "$status"
