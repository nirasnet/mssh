#!/bin/bash
# mSSH v1.0.1 — Build, Archive, and Export for App Store
# Run from the project root: bash build_and_archive.sh

set -e

PROJECT="mssh.xcodeproj"
SCHEME="mSSH"
ARCHIVE_PATH="/tmp/mSSH_v1.0.1.xcarchive"
EXPORT_PATH="/tmp/mSSH_v1.0.1_export"
EXPORT_OPTIONS="build/ExportOptions.plist"

echo "=== mSSH v1.0.1 Build + Archive ==="
echo ""

# ── 1. Clean build ──────────────────────────────────────────────────────────
echo "1/4  Clean build (Release, generic/platform=iOS)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -configuration Release \
    clean build \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=CC24ZA67DK \
    2>&1 | tee /tmp/mssh_build.log | grep -E "error:|warning:|BUILD|Compiling|Linking" || true

if grep -q "BUILD SUCCEEDED" /tmp/mssh_build.log; then
    echo "    ✓ Build succeeded"
else
    echo "    ✗ Build FAILED — full log at /tmp/mssh_build.log"
    exit 1
fi

# ── 2. Archive ───────────────────────────────────────────────────────────────
echo ""
echo "2/4  Archiving to $ARCHIVE_PATH..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=iOS' \
    -configuration Release \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=CC24ZA67DK \
    2>&1 | tee /tmp/mssh_archive.log | grep -E "error:|warning:|ARCHIVE|Compiling|Linking" || true

if [ -d "$ARCHIVE_PATH" ]; then
    echo "    ✓ Archive created: $ARCHIVE_PATH"
else
    echo "    ✗ Archive FAILED — full log at /tmp/mssh_archive.log"
    exit 1
fi

# ── 3. Export (upload to App Store Connect) ──────────────────────────────────
echo ""
echo "3/4  Exporting for App Store Connect..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    2>&1 | tee /tmp/mssh_export.log | grep -E "error:|warning:|EXPORT|Upload" || true

if [ -d "$EXPORT_PATH" ]; then
    echo "    ✓ Export complete: $EXPORT_PATH"
else
    echo "    ✗ Export FAILED — full log at /tmp/mssh_export.log"
    echo "    (If upload already happened inline, this directory may be empty — check App Store Connect.)"
fi

# ── 4. Upload via xcrun altool (if not uploaded during export) ───────────────
IPA_PATH=$(find "$EXPORT_PATH" -name "*.ipa" 2>/dev/null | head -1)
if [ -n "$IPA_PATH" ]; then
    echo ""
    echo "4/4  Uploading $IPA_PATH to App Store Connect..."
    echo "     (You may be prompted for your Apple ID / app-specific password)"
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey "$APP_STORE_API_KEY" \
        --apiIssuer "$APP_STORE_API_ISSUER" \
        2>&1 || echo "     Note: set APP_STORE_API_KEY and APP_STORE_API_ISSUER env vars, or use Transporter."
else
    echo ""
    echo "4/4  No .ipa found in $EXPORT_PATH"
    echo "     The ExportOptions.plist uses destination=upload, so the IPA was"
    echo "     likely submitted directly during export. Check App Store Connect."
fi

echo ""
echo "=== Done ==="
