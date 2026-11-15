#!/usr/bin/env bash
# Install (or --uninstall) Claude Usage Widget on macOS.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Claude Usage Widget.app"
DEST_APP="/Applications/$APP_NAME"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/dev.usagewidget.claude-usage-widget.plist"

if [[ "${1:-}" == "--uninstall" ]]; then
  echo "Uninstalling Claude Usage Widget..."
  killall claude_usage_widget 2>/dev/null || true
  if [[ -f "$LAUNCH_AGENT" ]]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT"
  fi
  rm -rf "$DEST_APP" "$HOME/Applications/$APP_NAME"
  rm -f "$BIN_DIR/claude-usage-widget"
  echo "Uninstalled Claude Usage Widget."
  echo "(If you enabled Status Line, restore your previous status line in Claude Code settings if needed.)"
  exit 0
fi

# Find the app bundle
SRC=""
for c in \
  "$HERE/build/macos/Build/Products/Release/claude_usage_widget.app" \
  "$HERE/build/macos/Build/Products/Release/$APP_NAME" \
  "$HERE/claude_usage_widget.app" \
  "$HERE/$APP_NAME"; do
  if [[ -d "$c" && -x "$c/Contents/MacOS/claude_usage_widget" ]]; then
    SRC="$c"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  echo "Error: Built app bundle not found. Run ./build_macos.sh first." >&2
  exit 1
fi

if [[ ! -x "$SRC/Contents/MacOS/usage_bridge" ]]; then
  echo "Error: usage_bridge is missing in $SRC/Contents/MacOS/. Run ./build_macos.sh first." >&2
  exit 1
fi

# Check target directory
TARGET_DIR="/Applications"
if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi
FINAL_APP="$TARGET_DIR/$APP_NAME"

echo "Stopping any running instance..."
killall claude_usage_widget 2>/dev/null || true

echo "Installing to $FINAL_APP..."
rm -rf "$FINAL_APP"
cp -R "$SRC" "$FINAL_APP"

echo "Removing quarantine attributes..."
xattr -cr "$FINAL_APP" 2>/dev/null || true

echo "Signing application..."
codesign --force --deep --sign - "$FINAL_APP"

# Symlink command-line utility
mkdir -p "$BIN_DIR"
ln -sf "$FINAL_APP/Contents/MacOS/claude_usage_widget" "$BIN_DIR/claude-usage-widget"

# Register with LaunchServices
touch "$FINAL_APP"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$FINAL_APP" 2>/dev/null || true

cat <<MSG

==================================================
  Claude Usage Widget successfully installed!
==================================================

Location: $FINAL_APP

Next steps:
  1. Open "Claude Usage Widget" from Applications or Spotlight
     (or run 'open -a "$FINAL_APP"')
  2. Right-click the widget -> turn on "Status Line"
  3. Restart Claude Code and send a message

To uninstall:
  ./install_macos.sh --uninstall
MSG
