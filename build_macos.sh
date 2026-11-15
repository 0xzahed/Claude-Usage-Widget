#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "Compiling status line bridge..."
(cd bridge && dart pub get && dart compile exe bin/usage_bridge.dart -o usage_bridge)

echo "Building macOS application..."
flutter build macos --release

APP="build/macos/Build/Products/Release/claude_usage_widget.app"
echo "Copying bridge executable into app bundle..."
cp bridge/usage_bridge "$APP/Contents/MacOS/"

echo "Signing application..."
codesign --force --deep --sign - "$APP"

echo "Build complete: $APP"
