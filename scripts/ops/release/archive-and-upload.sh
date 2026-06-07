#!/usr/bin/env bash
# Archive → export → TestFlight upload using ASC API key from GCP Secret Manager.
#
# Usage: scripts/ops/release/archive-and-upload.sh
#
# Requires:
#   - macOS with Xcode 26+ installed
#   - gcloud authenticated for project cycle-journal
#   - Local.xcconfig with DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER
#   - GCP Secret Manager secrets: app-store-connect-{api-key,key-id,issuer-id}

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GCP_PROJECT="${GCP_PROJECT:-cycle-journal}"
SCHEME="${SCHEME:-Cycle}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
ARCHIVE_PATH="${BUILD_DIR}/Cycle.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
PRIVATE_KEYS_DIR="${HOME}/.appstoreconnect/private_keys"

echo "→ fetch ASC API credentials from Secret Manager"
KEY_ID=$(gcloud secrets versions access latest --secret=app-store-connect-key-id --project="${GCP_PROJECT}" 2>/dev/null)
ISSUER_ID=$(gcloud secrets versions access latest --secret=app-store-connect-issuer-id --project="${GCP_PROJECT}" 2>/dev/null)
P8_PATH="${PRIVATE_KEYS_DIR}/AuthKey_${KEY_ID}.p8"
mkdir -p "${PRIVATE_KEYS_DIR}"
gcloud secrets versions access latest --secret=app-store-connect-api-key --project="${GCP_PROJECT}" 2>/dev/null > "${P8_PATH}"
chmod 600 "${P8_PATH}"

cleanup() {
  echo "→ cleanup: remove ${P8_PATH}"
  rm -f "${P8_PATH}"
}
trap cleanup EXIT

TEAM_ID_OVERRIDE=$(grep -E '^DEVELOPMENT_TEAM' "${PROJECT_ROOT}/Local.xcconfig" | awk '{print $3}')
echo "→ DEVELOPMENT_TEAM=${TEAM_ID_OVERRIDE}"

echo "→ resolve packages"
xcodebuild \
  -project "${PROJECT_ROOT}/ios/Cycle.xcodeproj" \
  -scheme "${SCHEME}" \
  -resolvePackageDependencies

mkdir -p "${BUILD_DIR}"

echo "→ archive (${SCHEME} ${CONFIGURATION})"
xcodebuild archive \
  -project "${PROJECT_ROOT}/ios/Cycle.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${P8_PATH}" \
  -authenticationKeyID "${KEY_ID}" \
  -authenticationKeyIssuerID "${ISSUER_ID}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${TEAM_ID_OVERRIDE}" \
  MARKETING_VERSION="${MARKETING_VERSION:-1.0.1}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-$(date +%s)}" \
  | xcbeautify 2>/dev/null || \
xcodebuild archive \
  -project "${PROJECT_ROOT}/ios/Cycle.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${P8_PATH}" \
  -authenticationKeyID "${KEY_ID}" \
  -authenticationKeyIssuerID "${ISSUER_ID}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${TEAM_ID_OVERRIDE}" \
  MARKETING_VERSION="${MARKETING_VERSION:-1.0.1}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-$(date +%s)}"

echo "→ generate ExportOptions.plist"
EXPORT_PLIST="${BUILD_DIR}/ExportOptions.plist"
TEAM_ID=$(grep -E '^DEVELOPMENT_TEAM' "${PROJECT_ROOT}/Local.xcconfig" | awk '{print $3}')
cat > "${EXPORT_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadSymbols</key>
  <true/>
  <key>destination</key>
  <string>upload</string>
</dict>
</plist>
EOF

echo "→ exportArchive + upload"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${EXPORT_PLIST}" \
  -exportPath "${EXPORT_DIR}" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "${P8_PATH}" \
  -authenticationKeyID "${KEY_ID}" \
  -authenticationKeyIssuerID "${ISSUER_ID}"

echo "✓ uploaded. TestFlight will process in 5-15 minutes."
echo "  Watch ASC → TestFlight → iOS Builds for processing status."
