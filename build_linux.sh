#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
(cd bridge && dart pub get && dart compile exe bin/usage_bridge.dart -o usage_bridge)
flutter build linux
cp bridge/usage_bridge build/linux/x64/release/bundle/
