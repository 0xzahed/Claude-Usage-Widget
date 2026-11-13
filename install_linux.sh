#!/usr/bin/env bash
# Install (or --uninstall) Claude Usage Widget for the current user. No sudo needed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA/claude-usage-widget"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
# Must match the GTK application id so the dock/Alt-Tab show our icon, not a gear.
APP_ID="dev.usagewidget.claude_usage_widget"
DESKTOP="$DATA/applications/$APP_ID.desktop"
OLD_DESKTOP="$DATA/applications/claude-usage-widget.desktop"
ICON="$DATA/icons/hicolor/512x512/apps/claude-usage-widget.png"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/claude-usage-widget.desktop"

if [[ "${1:-}" == "--uninstall" ]]; then
  pkill -x claude_usage_wi 2>/dev/null || true
  rm -rf "$APP_DIR" "$BIN_DIR/claude-usage-widget" "$DESKTOP" "$OLD_DESKTOP" "$ICON" "$AUTOSTART"
  echo "Uninstalled. (If you used 'Install status line', right-click the widget and"
  echo "choose 'Uninstall status line' first to restore your Claude Code status line.)"
  exit 0
fi

# Find the app bundle: next to this script (release tarball) or in the build output.
for c in "$HERE" "$HERE/build/linux/x64/release/bundle"; do
  [[ -x "$c/claude_usage_widget" ]] && SRC="$c" && break
done
if [[ -z "${SRC:-}" ]]; then
  echo "App not built. Run ./build_linux.sh first." >&2; exit 1
fi
[[ -x "$SRC/usage_bridge" ]] || { echo "usage_bridge missing next to the app. Run ./build_linux.sh." >&2; exit 1; }

pkill -x claude_usage_wi 2>/dev/null || true
rm -f "$OLD_DESKTOP"
mkdir -p "$APP_DIR" "$BIN_DIR" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
rm -rf "$APP_DIR"/*
cp -r "$SRC"/. "$APP_DIR"/
rm -f "$APP_DIR/install_linux.sh"
ln -sf "$APP_DIR/claude_usage_widget" "$BIN_DIR/claude-usage-widget"

ICON_SRC="$HERE/assets/icon.png"
[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$ICON"

cat > "$DESKTOP" <<DESK
[Desktop Entry]
Type=Application
Name=Claude Usage Widget
Comment=Floating Claude Code usage meter
Exec="$APP_DIR/claude_usage_widget"
Icon=$ICON
StartupWMClass=$APP_ID
Categories=Utility;
Terminal=false
DESK

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$DATA/icons/hicolor" 2>/dev/null || true
command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" 2>/dev/null || true

cat <<MSG
Installed to $APP_DIR

Next steps:
  1. Launch "Claude Usage Widget" from your app menu (or run: claude-usage-widget)
  2. Right-click the widget -> "Install status line"
  3. Restart Claude Code and send a message
  Optional: right-click -> "Launch at startup"

Uninstall: ./install_linux.sh --uninstall
MSG
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Note: add $BIN_DIR to your PATH to use the 'claude-usage-widget' command." ;; esac
