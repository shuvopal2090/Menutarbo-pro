#!/usr/bin/env bash
# verify-import.sh — sanity-check that a project was imported completely.
# Usage: bash scripts/verify-import.sh
# Read-only: reports problems, changes nothing.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

pass=0; warn=0

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; pass=$((pass+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; warn=$((warn+1)); }

echo "=============================================="
echo " Import check: $(basename "$PWD")"
echo "=============================================="

# ---------------------------------------------------------------- tracked files
tracked=$(git ls-files | wc -l | tr -d ' ')
echo
echo "[1] Files git will actually keep"
if [ "$tracked" -le 1 ]; then
  warn "only $tracked tracked file(s) — the project was probably not imported yet"
elif [ "$tracked" -lt 5 ]; then
  warn "$tracked tracked files — that seems small for a full project"
else
  ok "$tracked tracked files"
fi

# ------------------------------------------------------------ ignored-but-present
echo
echo "[2] Important files git is IGNORING (these vanish from the repo)"
ignored_hits=$(git status --ignored --porcelain 2>/dev/null | grep '^!!' | sed 's/^!! //' \
  | grep -Ev '^\.git/$' || true)
if [ -n "$ignored_hits" ]; then
  echo "$ignored_hits" | head -25 | sed 's/^/        /'
  warn "$(echo "$ignored_hits" | wc -l | tr -d ' ') ignored path(s) — expected for node_modules/dist, a problem for source files"
else
  ok "no ignored paths"
fi

# ------------------------------------------------------------------ empty folders
echo
echo "[3] Empty directories (git cannot store these)"
empties=$(find . -type d -empty -not -path './.git/*' -not -name '.git' 2>/dev/null)
if [ -n "$empties" ]; then
  echo "$empties" | head -20 | sed 's/^/        /'
  warn "empty folders found — add a .gitkeep or they will not survive"
else
  ok "no empty directories"
fi

# --------------------------------------------------------------------- big files
echo
echo "[4] Files over 5 MB (common upload/commit failures)"
big=$(find . -type f -size +5M -not -path './.git/*' -not -path './node_modules/*' 2>/dev/null)
if [ -n "$big" ]; then
  echo "$big" | while read -r f; do
    printf '        %6s  %s\n' "$(du -h "$f" | cut -f1)" "$f"
  done
  warn "large files above — move them to asset hosting or Git LFS"
else
  ok "no oversized files"
fi

# ------------------------------------------------------------------- dot-files
echo
echo "[5] Dot-files (often lost on drag-and-drop)"
dots=$(find . -maxdepth 2 -name '.*' -not -path './.git*' -not -name '.' 2>/dev/null | wc -l | tr -d ' ')
ok "$dots hidden file(s) present at root / depth 1"
for f in .gitignore .env.example .editorconfig; do
  [ -e "$f" ] && ok "$f present" || warn "$f missing"
done

# -------------------------------------------------------------------- entrypoints
echo
echo "[6] Project entrypoints detected"
found=0
for f in package.json index.html vite.config.js vite.config.ts next.config.js \
         tsconfig.json requirements.txt pyproject.toml manage.py Dockerfile \
         composer.json Gemfile go.mod Cargo.toml; do
  if [ -e "$f" ]; then ok "$f"; found=$((found+1)); fi
done
[ "$found" -eq 0 ] && warn "no known entrypoint found — is the source in a subfolder?"

# -------------------------------------------------------------- secrets check
echo
echo "[7] Secrets must not be committed"
leaked=$(git ls-files | grep -E '(^|/)\.env($|\.)' || true)
if [ -n "$leaked" ]; then
  echo "$leaked" | sed 's/^/        /'
  warn "env file is tracked — remove its real values before pushing"
else
  ok "no tracked .env files"
fi

# ----------------------------------------------------------------------- verdict
echo
echo "=============================================="
printf ' %d passed, %d warning(s)\n' "$pass" "$warn"
echo "=============================================="
[ "$warn" -eq 0 ] && echo "Looks complete." || echo "Review the warnings above."
exit 0
