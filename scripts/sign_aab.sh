#!/bin/bash
# Sign the release AAB downloaded from GitHub Actions CI.
# Usage:  bash scripts/sign_aab.sh /path/to/app-release.aab /path/to/upload-keystore.jks
# Output: app-release-signed.aab  (ready to upload to Play Console)

set -e

AAB="${1:-app-release.aab}"
KEYSTORE="${2:-upload-keystore.jks}"
ALIAS="upload"
OUT="app-release-signed.aab"

if [ ! -f "$AAB" ]; then
  echo "ERROR: AAB not found: $AAB"
  echo "Download it from GitHub Actions → your latest master run → quran-app-release artifact"
  exit 1
fi

if [ ! -f "$KEYSTORE" ]; then
  echo "ERROR: Keystore not found: $KEYSTORE"
  exit 1
fi

# jarsigner is bundled with the JDK (java must be installed)
jarsigner \
  -verbose \
  -keystore "$KEYSTORE" \
  -storepass "QuranApp@2025#Secure" \
  -keypass  "QuranApp@2025#Secure" \
  -signedjar "$OUT" \
  "$AAB" \
  "$ALIAS"

echo ""
echo "Signed AAB: $OUT"
echo "Upload this file to Google Play Console → Production → Create new release"
