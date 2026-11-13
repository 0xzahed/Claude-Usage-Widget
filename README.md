<div align="center">

<img src="assets/icon.png" width="96" alt="">

# Claude Usage Widget

**See your Claude Code limits at a glance, without typing `/usage`.**

A small always-on-top desktop widget with activity-style rings for your
5-hour and 7-day limits. Local only: no network calls, no login token.

[![CI](https://github.com/jihanurrahman33/Claude-Usage-Widget/actions/workflows/ci.yml/badge.svg)](https://github.com/jihanurrahman33/Claude-Usage-Widget/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)

<img src="docs/images/hero.png" alt="The widget as a pill, expanded, in settings, and in light theme">

</div>

## Why

Claude Code tells you how much of your limit is left only when you ask. This
widget keeps the answer on screen, so you see a limit coming before you hit it.

## Features

- **Rings for your limits.** 5-hour and 7-day usage with reset countdowns.
  Green below 70%, orange from 70%, red from 90%.
- **Works with every account type.** Pro and Max limits, company gateway
  spend, or estimated cost and context window for API keys. The widget picks
  the view from the data it receives.
- **Private by design.** It reads what Claude Code already hands to its status
  line. It makes no network calls and never reads your credentials.
- **Alerts** when a limit crosses 80% and 95%.
- **Light and dark**, following your system theme.
- **Always on top**, with a switch to turn it off.
- **Stays out of the way.** A pill that expands on click, with a tray icon,
  launch at login and an opacity slider.

<img src="docs/images/themes.png" alt="Dark and light themes">

## Install

> **Status:** Linux is tested. The macOS and Windows packages build in CI but
> have not been run by anyone yet. Help testing those is very welcome.

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/jihanurrahman33/Claude-Usage-Widget/main/install.sh | bash
```

This downloads the latest release, checks its SHA-256 checksum and installs it
for your user only (no `sudo`). It needs an x86_64 system with GTK 3; for the
tray icon and alerts also install `libayatana-appindicator3-1` and
`libnotify-bin`.

Then:

1. Open **Claude Usage Widget** from your app menu.
2. Right-click the widget, and turn on **Status Line**.
3. Restart Claude Code and send a message.

<details>
<summary>Build from source instead</summary>

You need [Flutter](https://docs.flutter.dev/get-started/install/linux) and the
usual Linux desktop build tools.

```bash
sudo apt install libgtk-3-dev libx11-dev libxi-dev libayatana-appindicator3-dev libnotify-dev
git clone https://github.com/jihanurrahman33/Claude-Usage-Widget.git
cd Claude-Usage-Widget
./build_linux.sh && ./install_linux.sh
```

</details>

### macOS and Windows

Download the `.dmg` or `.zip` from the
[latest release](https://github.com/jihanurrahman33/Claude-Usage-Widget/releases/latest).
These packages compile in CI, but nobody has run them yet; see
[docs/development.md](docs/development.md).

## Update

The widget never goes online, so it does not update itself or check for new
versions. Watch the repository's releases (**Watch → Custom → Releases**) to
hear about them.

- **Linux:** run the install command again. It replaces the app, keeps your
  settings and status line, and restarts the widget if it was running.
  To pin a version: `... | bash -s -- --version v0.1.0`.
- **Built from source:** `git pull`, then `./build_linux.sh && ./install_linux.sh`.
- **macOS and Windows:** quit the widget, download the latest release and
  replace the old app or folder.

## Uninstall

Turn **Status Line** off first so your previous status line is restored, then:

```bash
curl -fsSL https://raw.githubusercontent.com/jihanurrahman33/Claude-Usage-Widget/main/install.sh | bash -s -- --uninstall
```

From a source checkout, `./install_linux.sh --uninstall` does the same.

## Use

| Action | Result |
|---|---|
| Click | Expand or collapse |
| Drag | Move (the position is remembered) |
| Right-click | Settings |

<img src="docs/images/modes.png" alt="Subscription, API key and waiting states">

## How it works

```
Claude Code ──► usage_bridge ──► JSON records ──► widget
               (status line)    (~/.claude/usage-widget)
```

Claude Code runs a [status line](https://code.claude.com/docs/en/statusline)
command and passes it session data, including your rate limits. The bridge is
that command: it saves the data to a file and prints a short status line. The
widget watches the folder and draws what it finds. More in
[docs/architecture.md](docs/architecture.md).

## Good to know

- **Numbers update when Claude Code hears from the API.** While you are idle
  the countdowns keep ticking, but the percentages only change on your next
  message. Usage from claude.ai chat shows up then too.
- **API cost is an estimate** at list price.
- **No per-model weekly limit.** Claude Code does not expose it to the status
  line.
- **The glass is simulated.** An app cannot blur the desktop behind its window
  on every platform. Use the opacity slider if it is hard to read.

Problems? See [docs/troubleshooting.md](docs/troubleshooting.md).

## Contributing

Issues and pull requests are welcome, especially macOS and Windows testing.
Start with [CONTRIBUTING.md](CONTRIBUTING.md). If you work with a coding
agent, point it at [AGENTS.md](AGENTS.md).

## Disclaimer

This is an independent, community project. It is not affiliated with,
endorsed by, or supported by Anthropic. "Claude" is a trademark of Anthropic.

## License

[MIT](LICENSE). The bundled Inter typeface is licensed under the
[SIL Open Font License 1.1](assets/fonts/OFL.txt).
