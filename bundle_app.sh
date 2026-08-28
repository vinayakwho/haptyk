#!/bin/bash
set -e

APP_NAME="Haptyk"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building Haptyk.app bundle..."

# Clean and recreate bundle directories
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Build C CoreAudio Static Library
mkdir -p .build/cache .build/obj
clang -c -O3 -fobjc-arc -I Sources/CHaptykAudio/include Sources/CHaptykAudio/HaptykAudioCore.c -o .build/obj/HaptykAudioCore.o
clang -c -O3 -fobjc-arc -I Sources/CHaptykAudio/include Sources/CHaptykAudio/HaptykAudioBridge.m -o .build/obj/HaptykAudioBridge.o
ar rcs .build/libCHaptykAudio.a .build/obj/HaptykAudioCore.o .build/obj/HaptykAudioBridge.o

# Compile Swift sources into executable binary
swiftc -parse-as-library -O \
    -module-cache-path .build/cache \
    -I Sources/CHaptykAudio/include \
    -L .build -lCHaptykAudio \
    -framework Cocoa -framework SwiftUI -framework IOKit -framework Carbon -framework AudioToolbox -framework AudioUnit -framework CoreAudio -framework QuartzCore \
    Sources/Haptyk/App/*.swift \
    Sources/Haptyk/Core/*.swift \
    Sources/Haptyk/UI/*.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

# Copy SoundPacks and AppIcon into Resources
cp -R Sources/Haptyk/Resources/SoundPacks "${RESOURCES_DIR}/"
if [ -f Sources/Haptyk/Resources/AppIcon.icns ]; then
    cp Sources/Haptyk/Resources/AppIcon.icns "${RESOURCES_DIR}/"
fi

# Create Info.plist
cat << 'PLIST' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Haptyk</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.haptyk.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Haptyk</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Haptyk. All rights reserved.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Haptyk needs access to monitor keystroke dynamics and velocity.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign -s - --force --deep "${BUNDLE_DIR}"
echo "✓ Successfully built ${APP_NAME}.app with custom AppIcon!"
