#!/usr/bin/env bash
# make-clean-zip.sh — build an upload-ready zip of a project, excluding
# dependencies, build output, caches and secrets.
#
# Usage:
#   bash make-clean-zip.sh /path/to/project            -> project-clean.zip
#   bash make-clean-zip.sh /path/to/project out.zip
#
# Works on macOS and Linux. Keeps dot-files (.gitignore, .env.example, .github/).

set -euo pipefail

SRC="${1:-.}"
OUT="${2:-$(basename "$(cd "$SRC" && pwd)")-clean.zip}"

if [ ! -d "$SRC" ]; then
  echo "error: '$SRC' is not a directory" >&2
  exit 1
fi
SRC=$(cd "$SRC" && pwd)

EXCLUDES=(
  'node_modules' 'bower_components' 'vendor'
  'dist' 'build' 'out' '.next' '.nuxt' '.output' '.svelte-kit'
  '.turbo' '.parcel-cache' '.vite' 'coverage' 'target'
  '.git' '.cache' '__pycache__' '.pytest_cache' '.mypy_cache' '.ruff_cache'
  '.venv' 'venv' 'env' '.env' '.env.local' '.env.production'
  '.DS_Store' 'Thumbs.db' '.idea'
  '*.log' '*.sqlite' '*.sqlite3' '*.db'
  '*.mp4' '*.mov' '*.avi' '*.mkv'
  '*.zip' '*.rar' '*.7z' '*.tar' '*.gz'
)

echo "Project : $SRC"
echo "Output  : $OUT"
echo

# Show what is being left out, largest first, so the saving is visible.
echo "Biggest excluded folders:"
for d in node_modules dist build .next out .venv venv .git; do
  [ -d "$SRC/$d" ] && printf '  %8s  %s\n' "$(du -sh "$SRC/$d" 2>/dev/null | cut -f1)" "$d"
done
echo

rm -f "$OUT"

# Build -x patterns as a real array. Each entry needs four forms: zip treats
# directories and their contents as separate cases, so `-x node_modules` alone
# excludes nothing. Quoting matters — do not unquote.
XARGS=()
for e in "${EXCLUDES[@]}"; do
  XARGS+=( -x "$e" -x "*/$e" -x "$e/*" -x "*/$e/*" )
done

# -X drops extra attributes for smaller, portable zips.
( cd "$SRC" && zip -r -q -X "$OUT" . "${XARGS[@]}" ) || {
      echo "error: zip failed" >&2; exit 1; }

SIZE=$(du -h "$OUT" | cut -f1)
COUNT=$(unzip -l "$OUT" | tail -1 | awk '{print $2}')
echo "Created $OUT  ($SIZE, $COUNT entries)"

# Guard the two limits that actually block uploads.
BYTES=$(wc -c < "$OUT")
if [ "$BYTES" -gt 100000000 ]; then
  echo
  echo "WARNING: over 100 MB — GitHub rejects this. Find the culprits with:"
  echo "  find \"$SRC\" -type f -size +5M -not -path '*/node_modules/*'"
elif [ "$BYTES" -gt 50000000 ]; then
  echo
  echo "NOTE: over 50 MB — GitHub will warn. Likely large media assets."
fi

echo
echo "Now upload $OUT"
