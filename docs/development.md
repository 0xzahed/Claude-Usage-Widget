# Development

## Run

```bash
flutter pub get
flutter run -d linux        # or macos / windows
```

To try it without touching your real data, point it at a scratch folder:

```bash
mkdir -p /tmp/demo/usage-widget
NOW=$(date +%s)
echo "{\"session_id\":\"demo\",\"written_at\":$NOW,\"rate_limits\":{\"five_hour\":{\"used_percentage\":24,\"resets_at\":$((NOW+9000))},\"seven_day\":{\"used_percentage\":78,\"resets_at\":$((NOW+250000))}}}" > /tmp/demo/usage-widget/demo.json
CLAUDE_CONFIG_DIR=/tmp/demo flutter run -d linux
```

## Test

```bash
flutter analyze && flutter test
(cd bridge && dart analyze && dart test)
```

## Preview the UI without a screen

```bash
PREVIEW_OUT=/tmp/previews flutter test tool/preview_test.dart
python3 tool/make_screenshots.py /tmp/previews     # README images
python3 tool/make_icon.py                          # app icon
```

Add `--enable-impeller` to render with the app's real renderer.

## Build

- Linux: `./build_linux.sh`, then `./install_linux.sh`.
- macOS and Windows: `.github/workflows/build.yml` (run it manually or push a
  `v*` tag). These builds compile but have **not been run**. The bridge must sit next to the
  app executable.

## Release

Users update by re-running `install.sh` (Linux) or downloading the latest
release (macOS, Windows), so a release is how a change reaches them.

1. Set the new version in `pubspec.yaml` and `lib/config/app_constants.dart`.
2. Add a `## x.y.z` section to `CHANGELOG.md`; it becomes the release notes.
3. Commit, then `git tag vx.y.z && git push origin main vx.y.z`.

The tag runs `.github/workflows/build.yml`, which fails early if the tag and
the pubspec version differ, builds the three packages and publishes them with a
`SHA256SUMS` file. Asset names carry no version, so
`releases/latest/download/<name>` always serves the newest; `install.sh`
depends on that. The Linux package is built on Ubuntu 22.04 so it runs on
distributions with an older glibc.

## Platform notes

- Linux uses the X11 backend (XWayland on Wayland sessions), because Wayland
  cannot keep a window above others or restore its position.
- Linux tray needs `libayatana-appindicator3-dev`; GNOME needs the
  AppIndicator extension to show it.
- macOS: App Sandbox is off so the app can read the Claude config folder.
  Unsigned builds show a Gatekeeper warning.
