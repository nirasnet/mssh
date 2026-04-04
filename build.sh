#!/bin/bash
# mSSH Build Script
# Run from the project root: ./build.sh

set -e

echo "=== mSSH Build ==="
echo ""

# Step 1: Generate Xcode project
echo "1/3 Regenerating Xcode project..."
if command -v xcodegen &> /dev/null; then
    xcodegen generate
    echo "    ✓ Project generated"
else
    echo "    ✗ xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

# Step 2: Build for simulator first (fast check)
echo ""
echo "2/3 Building for iOS Simulator..."
xcodebuild build \
    -project mssh.xcodeproj \
    -scheme mssh \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES \
    2>&1 | tail -20

echo ""
echo "    ✓ Simulator build succeeded"

# Step 3: Check for connected devices
echo ""
echo "3/3 Checking for connected devices..."
DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep -E "^\s" | grep -v "Simulator" | head -1 | awk '{print $NF}' || true)

if [ -n "$DEVICE_ID" ]; then
    echo "    Found device: $DEVICE_ID"
    echo ""
    echo "    Building for device..."
    xcodebuild build \
        -project mssh.xcodeproj \
        -scheme mssh \
        -destination "id=$DEVICE_ID" \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM=CC24ZA67DK \
        2>&1 | tail -20
    echo ""
    echo "    ✓ Device build succeeded"
    echo ""
    echo "    Installing on device..."
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphoneos/mssh.app -maxdepth 0 2>/dev/null | head -1)
    if [ -n "$APP_PATH" ]; then
        xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
        echo "    ✓ Installed"
        echo ""
        echo "    Launching..."
        xcrun devicectl device process launch --device "$DEVICE_ID" com.m4ck.mssh
        echo "    ✓ Launched"
    fi
else
    echo "    No physical device found. Simulator build completed."
    echo "    Connect a device and re-run to build + install."
fi

echo ""
echo "=== Build Complete ==="
