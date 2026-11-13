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
  `v*` tag). These builds are **untested**. The bridge must sit next to the
  app executable.

## Platform notes

- Linux tray needs `libayatana-appindicator3-dev`; GNOME needs the
  AppIndicator extension to show it.
- macOS: App Sandbox is off so the app can read the Claude config folder.
  Unsigned builds show a Gatekeeper warning.
