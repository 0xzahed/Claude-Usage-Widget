import 'dart:io';

import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:claude_usage_widget/data/services/claude_settings_service.dart';

/// Installs and removes the bridge as Claude Code's status line command.
class StatusLineRepository {
  /// Creates a repository; [bridgePath] is the compiled bridge executable.
  StatusLineRepository({required this._settings, required this.bridgePath});

  /// Path of the bridge executable to register.
  final String bridgePath;

  final ClaudeSettingsService _settings;

  static const _key = 'statusLine';

  /// Whether our bridge is currently the status line command.
  Future<bool> isInstalled() async {
    try {
      return _isOurs((await _settings.read())[_key]);
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  /// Registers the bridge, backing up any status line the user already had.
  ///
  /// Throws [FormatException] or [FileSystemException] if the settings file
  /// cannot be read or written; the file is left untouched in that case.
  Future<void> install() async {
    final settings = await _settings.read();
    final previous = settings[_key];
    if (previous != null && !_isOurs(previous)) {
      await _settings.writeBackup(previous);
    }
    settings[_key] = {
      'type': 'command',
      // Forward slashes work on every OS, including Windows.
      'command': '"${bridgePath.replaceAll(r'\', '/')}"',
      'refreshInterval': AppConstants.statusLineRefreshSeconds,
    };
    await _settings.write(settings);
  }

  /// Restores the previous status line, or removes ours if there was none.
  Future<void> uninstall() async {
    final settings = await _settings.read();
    final backup = await _settings.readBackup();
    if (backup != null) {
      settings[_key] = backup;
    } else {
      settings.remove(_key);
    }
    await _settings.write(settings);
    await _settings.deleteBackup();
  }

  bool _isOurs(Object? statusLine) =>
      statusLine is Map<String, Object?> &&
      '${statusLine['command']}'.contains('usage_bridge');
}
