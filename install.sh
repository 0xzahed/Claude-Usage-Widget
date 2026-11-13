#!/usr/bin/env bash
# Download and install (or update) Claude Usage Widget on Linux. No sudo needed.
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
ASSET="claude-usage-widget-linux.tar.gz"
PROCESS="claude_usage_wi" # the kernel truncates process names to 15 characters

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
  command -v tar >/dev/null || fail "tar is required"

  if [[ "$uninstall" == 1 ]]; then
    curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install_linux.sh" |
      bash -s -- --uninstall
    exit 0
  fi

  [[ "$(uname -s)" == "Linux" ]] || fail "this installer is for Linux; see the README for macOS and Windows"
  [[ "$(uname -m)" == "x86_64" ]] || fail "only x86_64 packages are published; build from source on $(uname -m)"

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

  echo "Downloading Claude Usage Widget ($version)..."
  curl -fL --progress-bar "$base/$ASSET" -o "$tmp/$ASSET" ||
    fail "download failed: $base/$ASSET"
  curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" ||
    fail "download failed: $base/SHA256SUMS"

  echo "Verifying checksum..."
  grep " $ASSET\$" "$tmp/SHA256SUMS" >"$tmp/expected" ||
    fail "SHA256SUMS has no entry for $ASSET"
  (cd "$tmp" && sha256sum --check --quiet expected) ||
    fail "checksum mismatch; the download is corrupt or was tampered with"

  local was_running=0
  pgrep -x "$PROCESS" >/dev/null && was_running=1

  mkdir "$tmp/bundle"
  tar -xzf "$tmp/$ASSET" -C "$tmp/bundle"
  [[ -f "$tmp/bundle/install_linux.sh" ]] || fail "package is missing install_linux.sh"
  bash "$tmp/bundle/install_linux.sh"

  # An update stops the running widget; bring it back so nothing looks broken.
  local app="${XDG_DATA_HOME:-$HOME/.local/share}/claude-usage-widget/claude_usage_widget"
  if [[ "$was_running" == 1 && -x "$app" ]] && ! pgrep -x "$PROCESS" >/dev/null; then
    setsid "$app" >/dev/null 2>&1 </dev/null &
    echo "Restarted the widget with the new version."
  fi
}

main "$@"
