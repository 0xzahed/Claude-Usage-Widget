# Security

## What the app touches

- It reads JSON records from `<claude config>/usage-widget/`.
- With your consent (the **Status Line** switch) it edits the `statusLine`
  entry of Claude Code's `settings.json`, and keeps a backup of the previous
  value.
- It makes no network calls and does not read credentials or tokens.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's
**Security → Report a vulnerability** on this repository. You should get a
reply within a week.
