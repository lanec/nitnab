#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage: ./scripts/release/validate_notarized_artifact.sh <zip-path>

Example:
  ./scripts/release/validate_notarized_artifact.sh ./build/release/1.0.4/NitNab-1.0.4-macOS-universal-notarized.zip
EOF
}

die() {
  printf '[validate] ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage
  die "Zip path is required."
fi

ZIP_PATH="$1"
[[ -f "$ZIP_PATH" ]] || die "File not found: $ZIP_PATH"

for cmd in codesign spctl xcrun ditto shasum; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
done

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ditto -x -k "$ZIP_PATH" "$TMP_DIR"
APP_PATH="$(find "$TMP_DIR" -maxdepth 2 -type d -name 'NitNab.app' | head -n 1)"
[[ -n "$APP_PATH" ]] || die "NitNab.app not found in archive."

echo "[validate] App bundle: $APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -vvv --type exec "$APP_PATH"

echo "[validate] SHA-256:"
shasum -a 256 "$ZIP_PATH"
echo "[validate] OK"

