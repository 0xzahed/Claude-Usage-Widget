# Troubleshooting

**"Waiting for Claude Code"**
Turn on **Status Line** in Settings (right-click), restart Claude Code and
send one message. Check that files appear in `~/.claude/usage-widget/`.

**The numbers lag behind `/usage`**
Claude Code only gets fresh limits when the API responds. The widget shows the
last value it was given and catches up on your next message.

**No rings, only a cost**
You are signed in with an API key. Limits exist only for Pro, Max and gateway
accounts.

**No tray icon on GNOME**
Enable the "AppIndicator and KStatusNotifierItem Support" extension.

**A generic gear icon in the dock**
Run `./install_linux.sh` again and relaunch from the app menu.

**I already had a status line**
It is saved when you turn **Status Line** on and restored when you turn it off.

**Hard to read over a bright window**
Raise **Opacity** in Settings.
