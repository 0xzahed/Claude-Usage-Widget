import 'dart:io';

import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:path/path.dart' as p;

/// Starts the app at login, using each OS's native mechanism.
abstract interface class AutostartService {
  /// Picks the implementation for the current OS.
  factory AutostartService.forPlatform() {
    final exe = Platform.resolvedExecutable;
    final home = Platform.environment['HOME'] ?? '.';
    if (Platform.isWindows) return WindowsAutostartService(exe);
    if (Platform.isMacOS) {
      return FileAutostartService(
        file: File(p.join(home, 'Library', 'LaunchAgents', '$_macLabel.plist')),
        content: _launchAgent(exe),
      );
    }
    final config =
        Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    return FileAutostartService(
      file: File(p.join(config, 'autostart', 'claude-usage-widget.desktop')),
      content: _desktopEntry(exe),
    );
  }

  /// Whether the app starts at login.
  Future<bool> isEnabled();

  /// Turns start at login on or off.
  Future<void> setEnabled({required bool enabled});
}

const _macLabel = 'dev.usagewidget.claude-usage-widget';

String _desktopEntry(String exe) =>
    '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=${AppConstants.appName}\n'
    'Exec="$exe"\n'
    'X-GNOME-Autostart-enabled=true\n';

String _launchAgent(String exe) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<plist version="1.0"><dict>\n'
    '<key>Label</key><string>$_macLabel</string>\n'
    '<key>ProgramArguments</key><array><string>$exe</string></array>\n'
    '<key>RunAtLoad</key><true/>\n'
    '</dict></plist>\n';

/// Linux (XDG autostart) and macOS (LaunchAgent): a file's presence is the flag.
class FileAutostartService implements AutostartService {
  /// Creates a service that writes [content] to [file] when enabled.
  FileAutostartService({required this.file, required this.content});

  /// The autostart file.
  final File file;

  /// What to write into [file].
  final String content;

  @override
  Future<bool> isEnabled() async => file.existsSync();

  @override
  Future<void> setEnabled({required bool enabled}) async {
    if (enabled) {
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } else if (file.existsSync()) {
      await file.delete();
    }
  }
}

/// Windows: a value under the current user's `Run` registry key.
class WindowsAutostartService implements AutostartService {
  /// Creates a service that registers [executable].
  WindowsAutostartService(this.executable);

  /// The executable to start.
  final String executable;

  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'ClaudeUsageWidget';

  @override
  Future<bool> isEnabled() async {
    final result = await Process.run('reg', ['query', _key, '/v', _name]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setEnabled({required bool enabled}) async {
    final args = enabled
        ? [
            'add',
            _key,
            '/v',
            _name,
            '/t',
            'REG_SZ',
            '/d',
            '"$executable"',
            '/f',
          ]
        : ['delete', _key, '/v', _name, '/f'];
    await Process.run('reg', args);
  }
}
