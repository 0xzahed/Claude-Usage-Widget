import 'dart:io';

import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:claude_usage_widget/data/services/process_runner.dart';
import 'package:path/path.dart' as p;

/// Starts the app at login, using each OS's native mechanism.
abstract interface class AutostartService {
  /// Whether the app starts at login.
  Future<bool> isEnabled();

  /// Turns start at login on or off.
  Future<void> setEnabled({required bool enabled});
}

/// Autostart where a file's presence is the switch: Linux (XDG autostart)
/// and macOS (LaunchAgent).
class FileAutostartService implements AutostartService {
  /// Creates a service that writes [content] to [file] when enabled.
  FileAutostartService({required this.file, required this.content});

  /// Linux: a desktop entry for [executable] under [configHome]`/autostart`.
  factory FileAutostartService.xdg({
    required String executable,
    required String configHome,
  }) => FileAutostartService(
    file: File(p.join(configHome, 'autostart', 'claude-usage-widget.desktop')),
    content:
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=${AppConstants.appName}\n'
        'Exec="$executable"\n'
        'X-GNOME-Autostart-enabled=true\n',
  );

  /// macOS: a LaunchAgent for [executable] under [home]`/Library`.
  factory FileAutostartService.launchAgent({
    required String executable,
    required String home,
  }) => FileAutostartService(
    file: File(p.join(home, 'Library', 'LaunchAgents', '$_macLabel.plist')),
    content:
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<plist version="1.0"><dict>\n'
        '<key>Label</key><string>$_macLabel</string>\n'
        '<key>ProgramArguments</key><array><string>$executable</string></array>\n'
        '<key>RunAtLoad</key><true/>\n'
        '</dict></plist>\n',
  );

  static const _macLabel = 'dev.usagewidget.claude-usage-widget';

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
  /// Creates a service that registers [executable], using [run] for `reg`.
  WindowsAutostartService(this.executable, {this._run = runProcess});

  /// The executable to start.
  final String executable;

  final ProcessRunner _run;

  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'ClaudeUsageWidget';

  @override
  Future<bool> isEnabled() async {
    final result = await _run('reg', ['query', _key, '/v', _name]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setEnabled({required bool enabled}) async {
    await _run(
      'reg',
      enabled
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
          : ['delete', _key, '/v', _name, '/f'],
    );
  }
}
