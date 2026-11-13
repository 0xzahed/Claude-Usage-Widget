import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:usage_bridge/bridge.dart' show recordsDir;

/// Reads and writes Claude Code's `settings.json` and our backup of the
/// previous status line.
class ClaudeSettingsService {
  /// Creates a service for the Claude config folder [configDir].
  ClaudeSettingsService({required this.configDir});

  /// The Claude config folder.
  final String configDir;

  File get _settings => File(p.join(configDir, 'settings.json'));
  File get _backup =>
      File(p.join(recordsDir(configDir), 'previous-statusline.json'));

  /// Reads settings; an absent file is an empty map.
  ///
  /// Throws [FormatException] if the file is not a JSON object.
  Future<Map<String, Object?>> read() async {
    if (!_settings.existsSync()) return {};
    final decoded = jsonDecode(await _settings.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('settings.json is not a JSON object');
    }
    return decoded;
  }

  /// Writes settings atomically (temp file, then rename).
  Future<void> write(Map<String, Object?> settings) async {
    await _settings.parent.create(recursive: true);
    final tmp = File('${_settings.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings),
    );
    await tmp.rename(_settings.path);
  }

  /// Saves [value] as the status line to restore on uninstall.
  Future<void> writeBackup(Object value) async {
    await _backup.parent.create(recursive: true);
    await _backup.writeAsString(jsonEncode(value));
  }

  /// The saved status line, or null if there is none.
  Future<Object?> readBackup() async {
    if (!_backup.existsSync()) return null;
    return jsonDecode(await _backup.readAsString());
  }

  /// Removes the backup if present.
  Future<void> deleteBackup() async {
    if (_backup.existsSync()) await _backup.delete();
  }
}
