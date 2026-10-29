#!/usr/bin/env bash
# fetch-resources.sh — restore the large binary assets that are excluded from
# this repository (fonts + background music, ~206 MB).
#
# The app needs these at runtime to render subtitles and pick background music.
# They come from the upstream project at the exact commit this source matches.
#
# Usage:
#   bash scripts/fetch-resources.sh
#
# Requires: curl + tar (present on macOS and most Linux distributions).

set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM="harry0703/MoneyPrinterTurbo"
COMMIT="dd5ee71a0fbbb2c06401a7a4401bc83830a7c4d1"
ARCHIVE="https://codeload.github.com/${UPSTREAM}/tar.gz/${COMMIT}"

echo "This will download ~206 MB from ${UPSTREAM} @ ${COMMIT:0:7}"
echo "Into: $(pwd)/resource/{fonts,songs}"
echo

have=$( { ls resource/fonts/*.ttc resource/songs/*.mp3; } 2>/dev/null | wc -l | tr -d ' ')
if [ "$have" -ge 33 ]; then
  echo "Resources already present ($have files). Nothing to do."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading archive..."
if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 --progress-bar -o "$tmp/src.tar.gz" "$ARCHIVE"
else
  wget -q --show-progress -O "$tmp/src.tar.gz" "$ARCHIVE"
fi

echo "Extracting fonts and songs..."
mkdir -p resource/fonts resource/songs
tar -xzf "$tmp/src.tar.gz" -C "$tmp" \
    --wildcards \
    --strip-components=1 \
    'MoneyPrinterTurbo-*/resource/fonts/*.ttc' \
    'MoneyPrinterTurbo-*/resource/songs/*.mp3' 2>/dev/null || \
tar -xzf "$tmp/src.tar.gz" -C "$tmp" \
    --strip-components=1 \
    --include='*/resource/fonts/*.ttc' \
    --include='*/resource/songs/*.mp3'

if [ -d "$tmp/resource" ]; then
  cp -f "$tmp"/resource/fonts/*.ttc resource/fonts/ 2>/dev/null || true
  cp -f "$tmp"/resource/songs/*.mp3 resource/songs/ 2>/dev/null || true
else
  echo "error: expected folders not found in archive" >&2
  echo "Extract contents of $ARCHIVE manually into resource/" >&2
  exit 1
fi

fonts=$(ls resource/fonts/*.ttc 2>/dev/null | wc -l | tr -d ' ')
songs=$(ls resource/songs/*.mp3 2>/dev/null | wc -l | tr -d ' ')
echo
echo "Done: $fonts font files (.ttc), $songs songs (.mp3)"
echo "Total resource size: $(du -sh resource | cut -f1)"
