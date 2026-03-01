#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage: ./scripts/release/notarize_and_release.sh <tag>

Example:
  ./scripts/release/notarize_and_release.sh 1.0.4

Required environment variables:
  RELEASE_BUNDLE_ID
  APPLE_TEAM_ID
  DEVELOPER_ID_APPLICATION
  APPLE_DEVELOPER_ID_P12_BASE64
  APPLE_DEVELOPER_ID_P12_PASSWORD
  APPLE_KEY_ID
  APPLE_ISSUER_ID
  APPLE_API_PRIVATE_KEY_P8_BASE64
EOF
}

log() {
  printf '[release] %s\n' "$*"
}

die() {
  printf '[release] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "Missing required environment variable: $name"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

decode_base64_env_to_file() {
  local env_name="$1"
  local target="$2"
  /usr/bin/python3 - "$env_name" "$target" <<'PY'
import base64
import os
import sys

env_name = sys.argv[1]
target = sys.argv[2]
payload = os.environ.get(env_name, "")
if not payload:
    raise SystemExit(f"Missing environment variable: {env_name}")

with open(target, "wb") as fh:
    fh.write(base64.b64decode(payload))
PY
}

read_notary_json() {
  local json_path="$1"
  local key="$2"
  /usr/bin/python3 - "$json_path" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
value = data.get(key, "")
print(value)
PY
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage
  die "Tag argument is required."
fi

TAG="$1"
if [[ ! "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "Tag must look like semantic version without prefix, e.g. 1.0.4"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

require_cmd git
require_cmd gh
require_cmd xcodebuild
require_cmd codesign
require_cmd security
require_cmd xcrun
require_cmd ditto
require_cmd shasum
require_cmd spctl
require_cmd sed
require_cmd awk

require_env RELEASE_BUNDLE_ID
require_env APPLE_TEAM_ID
require_env DEVELOPER_ID_APPLICATION
require_env APPLE_DEVELOPER_ID_P12_BASE64
require_env APPLE_DEVELOPER_ID_P12_PASSWORD
require_env APPLE_KEY_ID
require_env APPLE_ISSUER_ID
require_env APPLE_API_PRIVATE_KEY_P8_BASE64

if ! git diff --quiet || ! git diff --cached --quiet; then
  die "Working tree is not clean. Commit or stash changes before cutting a release."
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  die "Tag $TAG already exists locally."
fi

if git ls-remote --tags origin "refs/tags/$TAG" | grep -q .; then
  die "Tag $TAG already exists on origin."
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  die "Release $TAG already exists on GitHub."
fi

WORK_DIR="$ROOT_DIR/build/release/$TAG"
mkdir -p "$WORK_DIR"
TMP_DIR="$(mktemp -d "$WORK_DIR/tmp.XXXXXX")"

ARCHIVE_PATH="$WORK_DIR/NitNab-${TAG}.xcarchive"
EXPORT_DIR="$WORK_DIR/export"
PRE_NOTARY_ZIP="$WORK_DIR/NitNab-${TAG}-macOS-universal-pre-notary.zip"
FINAL_ZIP="$WORK_DIR/NitNab-${TAG}-macOS-universal-notarized.zip"
CHECKSUM_PATH="${FINAL_ZIP}.sha256"
NOTARY_SUBMIT_JSON="$WORK_DIR/notary-submit.json"
NOTARY_LOG_JSON="$WORK_DIR/notary-log.json"

P12_PATH="$TMP_DIR/developer_id.p12"
P8_PATH="$TMP_DIR/AuthKey_${APPLE_KEY_ID}.p8"
RELEASE_XCCONFIG="$TMP_DIR/release-overrides.xcconfig"
EXPORT_OPTIONS_PLIST="$TMP_DIR/ExportOptions-DeveloperID.plist"
KEYCHAIN_PATH="$TMP_DIR/release-signing.keychain-db"
KEYCHAIN_PASSWORD="$(
  /usr/bin/python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
)"

ORIGINAL_DEFAULT_KEYCHAIN=""
ORIGINAL_KEYCHAINS=()

cleanup() {
  if [[ -n "$ORIGINAL_DEFAULT_KEYCHAIN" ]]; then
    security default-keychain -d user -s "$ORIGINAL_DEFAULT_KEYCHAIN" >/dev/null 2>&1 || true
  fi

  if [[ "${#ORIGINAL_KEYCHAINS[@]}" -gt 0 ]]; then
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
  fi

  if [[ -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi

  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

while IFS= read -r keychain_line; do
  [[ -n "$keychain_line" ]] || continue
  ORIGINAL_KEYCHAINS+=("$keychain_line")
done < <(security list-keychains -d user | sed 's/^[[:space:]]*//; s/^"//; s/"$//')
ORIGINAL_DEFAULT_KEYCHAIN="$(security default-keychain -d user | sed 's/^"//; s/"$//')"

log "Decoding signing and notarization credentials into temporary workspace."
decode_base64_env_to_file APPLE_DEVELOPER_ID_P12_BASE64 "$P12_PATH"
decode_base64_env_to_file APPLE_API_PRIVATE_KEY_P8_BASE64 "$P8_PATH"

log "Creating temporary keychain and importing Developer ID certificate."
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$P12_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$APPLE_DEVELOPER_ID_P12_PASSWORD" \
  -f pkcs12 \
  -A \
  -t cert
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" "${ORIGINAL_KEYCHAINS[@]}"
security default-keychain -d user -s "$KEYCHAIN_PATH"

if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -Fq "$DEVELOPER_ID_APPLICATION"; then
  die "Imported keychain does not contain expected identity: $DEVELOPER_ID_APPLICATION"
fi

log "Generating release-time Xcode signing override and export options."
sed \
  -e "s/__RELEASE_BUNDLE_ID__/$(escape_sed_replacement "$RELEASE_BUNDLE_ID")/g" \
  -e "s/__APPLE_TEAM_ID__/$(escape_sed_replacement "$APPLE_TEAM_ID")/g" \
  -e "s/__DEVELOPER_ID_APPLICATION__/$(escape_sed_replacement "$DEVELOPER_ID_APPLICATION")/g" \
  "$ROOT_DIR/scripts/release/release-overrides.xcconfig.template" > "$RELEASE_XCCONFIG"

sed \
  -e "s/__APPLE_TEAM_ID__/$(escape_sed_replacement "$APPLE_TEAM_ID")/g" \
  "$ROOT_DIR/scripts/release/ExportOptions-DeveloperID.plist" > "$EXPORT_OPTIONS_PLIST"

log "Building release archive."
xcodebuild \
  -project NitNab/NitNab.xcodeproj \
  -scheme NitNab \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -xcconfig "$RELEASE_XCCONFIG" \
  clean archive

log "Exporting signed app bundle."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_DIR/NitNab.app"
[[ -d "$APP_PATH" ]] || die "Expected app bundle not found at $APP_PATH"

log "Running pre-notarization signature verification."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vvv --type exec "$APP_PATH"

log "Creating pre-notarization zip archive."
rm -f "$PRE_NOTARY_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"

log "Submitting pre-notary archive to Apple notary service."
xcrun notarytool submit "$PRE_NOTARY_ZIP" \
  --key "$P8_PATH" \
  --key-id "$APPLE_KEY_ID" \
  --issuer "$APPLE_ISSUER_ID" \
  --wait \
  --output-format json > "$NOTARY_SUBMIT_JSON"

NOTARY_STATUS="$(read_notary_json "$NOTARY_SUBMIT_JSON" status)"
NOTARY_ID="$(read_notary_json "$NOTARY_SUBMIT_JSON" id)"

if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
  if [[ -n "$NOTARY_ID" ]]; then
    xcrun notarytool log "$NOTARY_ID" \
      --key "$P8_PATH" \
      --key-id "$APPLE_KEY_ID" \
      --issuer "$APPLE_ISSUER_ID" > "$NOTARY_LOG_JSON" || true
  fi
  die "Notarization failed with status '$NOTARY_STATUS'. See $NOTARY_SUBMIT_JSON and $NOTARY_LOG_JSON"
fi

log "Stapling notarization ticket to app."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -vvv --type exec "$APP_PATH"

log "Creating final notarized zip archive."
rm -f "$FINAL_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP" > "$CHECKSUM_PATH"

log "Creating immutable Git tag and publishing GitHub release."
git tag -a "$TAG" -m "Version $TAG"
git push origin "$TAG"
gh release create "$TAG" "$FINAL_ZIP" "$CHECKSUM_PATH" \
  --title "Version $TAG" \
  --notes "Notarized public binary release."

log "Release complete."
log "Artifact: $FINAL_ZIP"
log "Checksum: $CHECKSUM_PATH"
