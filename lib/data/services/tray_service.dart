// The 0.5.x-compatible API is the stable one for tray_manager 0.8.
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:claude_usage_widget/config/logger.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/legacy.dart';

/// What the tray menu can ask the app to do.
class TrayCallbacks {
  /// Creates the callbacks.
  const TrayCallbacks({
    required this.onToggleVisibility,
    required this.onToggleStartup,
    required this.onQuit,
  });

  /// Show or hide the widget.
  final VoidCallback onToggleVisibility;

  /// Turn launch at startup on or off.
  final VoidCallback onToggleStartup;

  /// Quit the app.
  final VoidCallback onQuit;
}

/// The system tray icon.
abstract interface class TrayService {
  /// Creates the icon; returns false if the desktop has no tray.
  Future<bool> start(TrayCallbacks callbacks);

  /// Rebuilds the menu labels for the current state.
  Future<void> updateMenu({
    required bool windowVisible,
    required bool startupEnabled,
  });

  /// Sets the hover text.
  Future<void> setTooltip(String text);

  /// Removes the icon.
  Future<void> dispose();
}

/// [TrayService] backed by the `tray_manager` plugin.
class SystemTrayService with TrayListener implements TrayService {
  TrayCallbacks? _callbacks;

  static const _toggle = 'toggle';
  static const _startup = 'startup';
  static const _quit = 'quit';

  @override
  Future<bool> start(TrayCallbacks callbacks) async {
    _callbacks = callbacks;
    try {
      trayManager.addListener(this);
      await trayManager.setIcon('assets/icon.png');
      await trayManager.setToolTip('Claude Usage');
      return true;
    } on PlatformException catch (e) {
      logWarning('Tray unavailable', e);
    } on MissingPluginException catch (e) {
      logWarning('Tray plugin missing', e);
    }
    return false;
  }

  @override
  Future<void> updateMenu({
    required bool windowVisible,
    required bool startupEnabled,
  }) => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(
          key: _toggle,
          label: windowVisible ? 'Hide widget' : 'Show widget',
        ),
        MenuItem(
          key: _startup,
          label: 'Launch at startup: ${startupEnabled ? 'on' : 'off'}',
        ),
        MenuItem.separator(),
        MenuItem(key: _quit, label: 'Quit'),
      ],
    ),
  );

  @override
  Future<void> setTooltip(String text) => trayManager.setToolTip(text);

  @override
  void onTrayIconMouseDown() => _callbacks?.onToggleVisibility();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final callbacks = _callbacks;
    if (callbacks == null) return;
    switch (menuItem.key) {
      case _toggle:
        callbacks.onToggleVisibility();
      case _startup:
        callbacks.onToggleStartup();
      case _quit:
        callbacks.onQuit();
    }
  }

  @override
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
