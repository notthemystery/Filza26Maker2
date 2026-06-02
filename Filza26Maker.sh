#!/bin/bash
set -eo pipefail

DEB_URL="${1:-https://tigisoftware.com/cydia/com.tigisoftware.filza_4.0.1-2_iphoneos-arm.deb}"

WORKDIR="$(mktemp -d)"
DEB_LOCAL="$WORKDIR/filza.deb"
IPA_NAME="Filza-Jailed-26-UncleTyrone.ipa"

echo "[ i ] Working dir: $WORKDIR"

# Detect environment
IS_WSL=false
IS_GITHUB=false

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  IS_GITHUB=true
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

echo "[ i ] WSL: $IS_WSL | GitHub: $IS_GITHUB"

# Download or copy DEB
if [[ -f "$1" && "$1" != "$DEB_URL" ]]; then
  echo "[ i ] Using local file"
  cp "$1" "$DEB_LOCAL"
else
  echo "[ i ] Downloading DEB..."
  curl -L --fail -o "$DEB_LOCAL" "$DEB_URL"
fi

cd "$WORKDIR"

echo "[ i ] Extracting .deb..."
ar -x "$DEB_LOCAL"

DATA_TAR="$(ls data.tar.* 2>/dev/null | head -n1 || true)"

if [[ -z "$DATA_TAR" ]]; then
  echo "[-] Missing data.tar"
  exit 1
fi

mkdir data_extracted
tar -xf "$DATA_TAR" -C data_extracted

FILZA_APP_PATH="$(find data_extracted -type d -iname 'Filza.app' | head -n1 || true)"

if [[ -z "$FILZA_APP_PATH" ]]; then
  echo "[-] Filza.app not found"
  exit 1
fi

echo "[ + ] Found: $FILZA_APP_PATH"

mkdir -p Payload
cp -R "$FILZA_APP_PATH" Payload/

rm -rf Payload/Filza.app/_CodeSignature 2>/dev/null || true
rm -f Payload/Filza.app/embedded.mobileprovision 2>/dev/null || true

zip -r "$IPA_NAME" Payload > /dev/null

# Output handling
if $IS_WSL; then
  WIN_DESKTOP="/mnt/c/Users/$USER/Desktop"
  echo "[ i ] Copying to Windows Desktop"
  cp -f "$IPA_NAME" "$WIN_DESKTOP/" || true
elif $IS_GITHUB; then
  echo "[ i ] GitHub Actions detected - keeping artifact in workspace"
else
  echo "[ i ] Local Linux build complete"
fi

rm -rf "$WORKDIR"

echo "[ + ] Done: $IPA_NAME"
