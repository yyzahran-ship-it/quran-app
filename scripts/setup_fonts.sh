#!/usr/bin/env bash
# setup_fonts.sh — Download the KFGQPC Uthmanic Script HAFS font
#
# The King Fahad Quran Printing Complex font is the official font used in the
# printed Madinah Mushaf. It renders Tanzil Uthmani Unicode text correctly and
# matches the visual style of the King Fahad Mushaf exactly.
#
# Usage:  bash scripts/setup_fonts.sh
# Run once, then rebuild the app.

set -euo pipefail

DEST="assets/fonts/UthmanicHafs.ttf"
FALLBACK="assets/fonts/AmiriQuran.ttf"

echo "=== KFGQPC Uthmanic Script HAFS Font Setup ==="

is_valid_font() {
  python3 -c "
import struct, sys
try:
    data = open('$1','rb').read(4)
    sys.exit(0 if data[:4] in [b'\\x00\\x01\\x00\\x00', b'OTTO', b'true'] else 1)
except:
    sys.exit(1)
" 2>/dev/null
}

try_download() {
  local url="$1"
  echo "  Trying: $url"
  if curl -fsSL --max-time 30 "$url" -o "$DEST" 2>/dev/null && is_valid_font "$DEST"; then
    SIZE=$(du -sh "$DEST" | cut -f1)
    echo "  ✓ Downloaded: $DEST ($SIZE)"
    return 0
  fi
  return 1
}

if [ -f "$DEST" ] && is_valid_font "$DEST"; then
  SIZE=$(du -sh "$DEST" | cut -f1)
  echo "Font already present: $DEST ($SIZE) — skipping download."
  exit 0
fi

echo "Downloading KFGQPC font..."

try_download "https://fonts.qurancomplex.gov.sa/wp02/uploads/2019/08/UthmanicHafs1Ver18.ttf" ||
try_download "https://www.qurancomplex.gov.sa/quran/fonts/UthmanicHafs1Ver18.ttf" ||
try_download "https://quran.ksu.edu.sa/fonts/hafs/UthmanicHafs1Ver18.ttf" ||
{
  echo ""
  echo "  Automatic download failed. Manual options:"
  echo ""
  echo "  Option 1 — King Fahad Complex official site:"
  echo "    https://fonts.qurancomplex.gov.sa"
  echo "    Download 'KFGQPC Uthmanic Script HAFS' and save as:"
  echo "    assets/fonts/UthmanicHafs.ttf"
  echo ""
  echo "  Option 2 — Use AmiriQuran as a placeholder (good quality, not identical):"
  echo "    cp assets/fonts/AmiriQuran.ttf assets/fonts/UthmanicHafs.ttf"
  echo ""
  echo "Using AmiriQuran placeholder for now..."
  cp "$FALLBACK" "$DEST"
  echo "  Placeholder copied. Replace with real font when available."
}

echo ""
echo "Done. Run 'flutter pub get && flutter run' to rebuild."
