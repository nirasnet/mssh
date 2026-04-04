#!/bin/bash
# mSSH v1.0.0 — Automated Build & Deploy
# This script builds the app and installs it on your connected iPhone.
set -euo pipefail
cd "$(dirname "$0")"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    mSSH v1.0.0 — Build & Deploy     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: xcodegen
echo "▸ [1/5] Generating Xcode project..."
if ! command -v xcodegen &> /dev/null; then
    echo "  ✗ xcodegen not found. Installing..."
    brew install xcodegen
fi
xcodegen generate 2>&1 | sed 's/^/  /'
echo "  ✓ Project generated"
echo ""

# Step 2: Resolve packages
echo "▸ [2/5] Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project mssh.xcodeproj -scheme mssh 2>&1 | grep -E "(Resolved|Fetching|Checking)" | sed 's/^/  /' || true
echo "  ✓ Packages resolved"
echo ""

# Step 3: Build for simulator (fast compilation check)
echo "▸ [3/5] Building for Simulator (compilation check)..."
SIM_BUILD_EXIT=0
SIM_BUILD=$(xcodebuild build \
    -project mssh.xcodeproj \
    -scheme mssh \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES 2>&1) || SIM_BUILD_EXIT=$?

if [ "$SIM_BUILD_EXIT" -eq 0 ] && echo "$SIM_BUILD" | grep -q "BUILD SUCCEEDED"; then
    echo "  ✓ Simulator build succeeded"
else
    echo "  ✗ Build failed! (exit code: $SIM_BUILD_EXIT)"
    echo ""
    echo "  Errors:"
    echo "$SIM_BUILD" | grep -E "error:" | head -30 | sed 's/^/    /'
    echo ""
    echo "  Full log saved to build_errors.log"
    echo "$SIM_BUILD" > "$(dirname "$0")/build_errors.log"
    exit 1
fi
echo ""

# Step 4: Find connected device and build
echo "▸ [4/5] Looking for connected device..."
DEVICE_LIST=$(xcrun devicectl list devices 2>/dev/null || true)
echo "$DEVICE_LIST" | head -20 | sed 's/^/  /'

# Try to extract device UUID - prefer available (paired) iPhone, then iPad
DEVICE_ID=$(echo "$DEVICE_LIST" | grep -i "iphone" | grep -v "unavailable" | grep -i "available" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(echo "$DEVICE_LIST" | grep -i "ipad" | grep -v "unavailable" | grep -i "available" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
fi
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(echo "$DEVICE_LIST" | grep -i "iphone\|ipad" | grep -v "unavailable" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
fi

if [ -z "$DEVICE_ID" ]; then
    echo ""
    echo "  ⚠ No physical device found."
    echo "  Connect your iPhone via USB/WiFi and ensure it's trusted."
    echo ""
    echo "  Simulator build succeeded - you can test in Simulator."
    echo "  To launch simulator: open -a Simulator"
    echo ""

    # Try to install on simulator instead
    echo "  Installing on Simulator..."
    SIM_APP=$(find ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphonesimulator/mssh.app -maxdepth 0 2>/dev/null | head -1 || true)
    if [ -n "$SIM_APP" ]; then
        xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
        xcrun simctl install "iPhone 17 Pro" "$SIM_APP" 2>/dev/null || true
        xcrun simctl launch "iPhone 17 Pro" com.m4ck.mssh 2>/dev/null || true
        echo "  ✓ Launched on Simulator"
    fi
    exit 0
fi

echo ""
echo "  Found device: $DEVICE_ID"
echo "  Building for device..."

DEVICE_BUILD_EXIT=0
DEVICE_BUILD=$(xcodebuild build \
    -project mssh.xcodeproj \
    -scheme mssh \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=CC24ZA67DK 2>&1) || DEVICE_BUILD_EXIT=$?

if [ "$DEVICE_BUILD_EXIT" -eq 0 ] && echo "$DEVICE_BUILD" | grep -q "BUILD SUCCEEDED"; then
    echo "  ✓ Device build succeeded"
else
    echo "  ✗ Device build failed! (exit code: $DEVICE_BUILD_EXIT)"
    echo "$DEVICE_BUILD" | grep -E "error:" | head -30 | sed 's/^/    /'
    echo ""
    echo "  Full log saved to build_errors.log"
    echo "$DEVICE_BUILD" > "$(dirname "$0")/build_errors.log"
    exit 1
fi
echo ""

# Step 5: Install & Launch
echo "▸ [5/5] Installing on device..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphoneos/mssh.app -maxdepth 0 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>&1 | sed 's/^/  /'
    echo "  ✓ Installed"
    echo ""
    echo "  Launching mSSH..."
    xcrun devicectl device process launch --device "$DEVICE_ID" com.m4ck.mssh 2>&1 | sed 's/^/  /' || true
    echo "  ✓ Launched!"
else
    echo "  ✗ Could not find built app"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   mSSH v1.0.0 — Deploy Complete!    ║"
echo "╚══════════════════════════════════════╝"
echo ""
