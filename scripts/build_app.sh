#!/bin/bash
set -e

APP_NAME="SubAndCast"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building $APP_NAME in Release mode..."
swift build -c release --product "$APP_NAME"

echo "📦 Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp Sources/SubAndCastKit/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
cp -R "$BUILD_DIR/"*.bundle "$CONTENTS_DIR/" 2>/dev/null || true
cp -R "$BUILD_DIR/"*.bundle "$RESOURCES_DIR/" 2>/dev/null || true

cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.khoa.subandcast</string>
    <key>CFBundleName</key>
    <string>Sub &amp; Cast</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Sub &amp; Cast requires screen capture access to perform OCR on dialogue boxes in your games.</string>
</dict>
</plist>
EOF

echo "✨ Successfully created $APP_BUNDLE!"
echo "To run: open $APP_BUNDLE"
