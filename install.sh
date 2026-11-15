#!/usr/bin/env bash
# Download and install (or update) Claude Usage Widget on Linux and macOS. No sudo needed.
#
#   curl -fsSL https://raw.githubusercontent.com/jihanurrahman33/Claude-Usage-Widget/main/install.sh | bash
#
# Run the same command again to update. Options (after `bash -s --` when piped):
#   --version vX.Y.Z   install that release instead of the latest
#   --uninstall        remove the widget
#
# Everything lives in main() so a partly downloaded script cannot run.
set -euo pipefail

REPO="jihanurrahman33/Claude-Usage-Widget"

fail() {
  echo "error: $*" >&2
  exit 1
}

main() {
  local version="latest"
  local uninstall=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        [[ $# -ge 2 ]] || fail "--version needs a value, for example v0.1.0"
        version="$2"
        shift 2
        ;;
      --uninstall)
        uninstall=1
        shift
        ;;
      -h | --help)
        echo "Usage: install.sh [--version vX.Y.Z] [--uninstall]"
        exit 0
        ;;
      *) fail "unknown option: $1" ;;
    esac
  done

  command -v curl >/dev/null || fail "curl is required"

  local os
  os="$(uname -s)"
  [[ "$os" == "Linux" || "$os" == "Darwin" ]] || fail "this installer is for Linux and macOS; see the README for Windows"

  if [[ "$uninstall" == 1 ]]; then
    if [[ "$os" == "Darwin" ]]; then
      curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install_macos.sh" |
        bash -s -- --uninstall
    else
      curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install_linux.sh" |
        bash -s -- --uninstall
    fi
    exit 0
  fi

  local asset process
  if [[ "$os" == "Darwin" ]]; then
    asset="claude-usage-widget-macos.dmg"
    process="claude_usage_widget"
  else
    [[ "$(uname -m)" == "x86_64" ]] || fail "only x86_64 packages are published for Linux; build from source on $(uname -m)"
    command -v tar >/dev/null || fail "tar is required"
    asset="claude-usage-widget-linux.tar.gz"
    process="claude_usage_wi" # kernel truncates Linux process names to 15 characters
  fi

  # CLAUDE_USAGE_WIDGET_BASE_URL lets a mirror (or a test) supply the files.
  local base
  if [[ -n "${CLAUDE_USAGE_WIDGET_BASE_URL:-}" ]]; then
    base="$CLAUDE_USAGE_WIDGET_BASE_URL"
  elif [[ "$version" == "latest" ]]; then
    base="https://github.com/$REPO/releases/latest/download"
  else
    base="https://github.com/$REPO/releases/download/$version"
  fi

  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand now: tmp is local to main
  trap "rm -rf '$tmp'" EXIT

  echo "Downloading Claude Usage Widget ($version) for $os..."
  curl -fL --progress-bar "$base/$asset" -o "$tmp/$asset" ||
    fail "download failed: $base/$asset"
  curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" ||
    fail "download failed: $base/SHA256SUMS"

  echo "Verifying checksum..."
  grep " $asset\$" "$tmp/SHA256SUMS" >"$tmp/expected" ||
    fail "SHA256SUMS has no entry for $asset"

  if command -v sha256sum >/dev/null; then
    (cd "$tmp" && sha256sum --check --quiet expected) ||
      fail "checksum mismatch; the download is corrupt or was tampered with"
  elif command -v shasum >/dev/null; then
    (cd "$tmp" && shasum -a 256 --check --quiet expected) ||
      fail "checksum mismatch; the download is corrupt or was tampered with"
  else
    fail "neither sha256sum nor shasum is available to verify download"
  fi

  local was_running=0
  pgrep -x "$process" >/dev/null && was_running=1

  if [[ "$os" == "Darwin" ]]; then
    local mountpoint="$tmp/mount"
    mkdir -p "$mountpoint"
    hdiutil attach "$tmp/$asset" -nobrowse -mountpoint "$mountpoint" -quiet

    local target_dir="/Applications"
    if [[ ! -w "$target_dir" ]]; then
      target_dir="$HOME/Applications"
      mkdir -p "$target_dir"
    fi
    local dest_app="$target_dir/Claude Usage Widget.app"

    pkill -x "$process" 2>/dev/null || true
    rm -rf "$dest_app"

    local src_app
    if [[ -d "$mountpoint/Claude Usage Widget.app" ]]; then
      src_app="$mountpoint/Claude Usage Widget.app"
    elif [[ -d "$mountpoint/claude_usage_widget.app" ]]; then
      src_app="$mountpoint/claude_usage_widget.app"
    else
      hdiutil detach "$mountpoint" -force -quiet 2>/dev/null || true
      fail "could not find application inside disk image"
    fi

    cp -R "$src_app" "$dest_app"
    hdiutil detach "$mountpoint" -force -quiet 2>/dev/null || true

    xattr -cr "$dest_app" 2>/dev/null || true
    codesign --force --deep --sign - "$dest_app" 2>/dev/null || true

    local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
    mkdir -p "$bin_dir"
    ln -sf "$dest_app/Contents/MacOS/claude_usage_widget" "$bin_dir/claude-usage-widget"
    touch "$dest_app"
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$dest_app" 2>/dev/null || true

    echo "Installed to $dest_app"
    if [[ "$was_running" == 1 ]]; then
      open -a "$dest_app"
      echo "Restarted the widget with the new version."
    else
      echo ""
      echo "Next steps:"
      echo "  1. Open 'Claude Usage Widget' from Applications (or Spotlight)"
      echo "  2. Right-click the widget -> turn on 'Status Line'"
      echo "  3. Restart Claude Code and send a message"
    fi
  else
    mkdir "$tmp/bundle"
    tar -xzf "$tmp/$asset" -C "$tmp/bundle"
    [[ -f "$tmp/bundle/install_linux.sh" ]] || fail "package is missing install_linux.sh"
    bash "$tmp/bundle/install_linux.sh"

    # An update stops the running widget; bring it back so nothing looks broken.
    local app="${XDG_DATA_HOME:-$HOME/.local/share}/claude-usage-widget/claude_usage_widget"
    if [[ "$was_running" == 1 && -x "$app" ]] && ! pgrep -x "$process" >/dev/null; then
      setsid "$app" >/dev/null 2>&1 </dev/null &
      echo "Restarted the widget with the new version."
    fi
  fi
}

main "$@"
