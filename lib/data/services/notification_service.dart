import 'dart:io';

import 'package:claude_usage_widget/config/logger.dart';
import 'package:claude_usage_widget/data/services/process_runner.dart';

/// Shows desktop notifications.
abstract interface class NotificationService {
  /// Shows a notification with [title] and [body].
  Future<void> show(String title, String body);
}

/// Base for notifiers that use a tool shipped with the OS, so no native
/// plugin is needed. Subclasses only say which command to run.
abstract class CommandNotificationService implements NotificationService {
  /// Creates a notifier that starts programs with [run].
  CommandNotificationService({this._run = runProcess});

  final ProcessRunner _run;

  /// Starts the OS tool for [title] and [body] using [run].
  Future<void> send(ProcessRunner run, String title, String body);

  @override
  Future<void> show(String title, String body) async {
    try {
      await send(_run, title, body);
    } on ProcessException catch (e) {
      logWarning('Notification tool unavailable', e);
    }
  }
}

/// Linux: `notify-send`.
class LinuxNotificationService extends CommandNotificationService {
  /// Creates the notifier.
  LinuxNotificationService({super.run});

  @override
  Future<void> send(ProcessRunner run, String title, String body) =>
      run('notify-send', ['-a', 'Claude Usage', title, body]);
}

/// macOS: AppleScript. The text is passed as arguments, never interpolated
/// into the script, so it cannot be mistaken for code.
class MacNotificationService extends CommandNotificationService {
  /// Creates the notifier.
  MacNotificationService({super.run});

  static const _script =
      'on run argv\n'
      'display notification (item 2 of argv) with title (item 1 of argv)\n'
      'end run';

  @override
  Future<void> send(ProcessRunner run, String title, String body) =>
      run('osascript', ['-e', _script, title, body]);
}

/// Windows: a toast through PowerShell. The text is passed in environment
/// variables, never interpolated into the script.
class WindowsNotificationService extends CommandNotificationService {
  /// Creates the notifier.
  WindowsNotificationService({super.run});

  static const _script = r'''
[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
$t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$n = $t.GetElementsByTagName('text')
$n.Item(0).AppendChild($t.CreateTextNode($env:W_TITLE)) | Out-Null
$n.Item(1).AppendChild($t.CreateTextNode($env:W_BODY)) | Out-Null
$app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show([Windows.UI.Notifications.ToastNotification]::new($t))
''';

  @override
  Future<void> send(ProcessRunner run, String title, String body) => run(
    'powershell',
    ['-NoProfile', '-Command', _script],
    environment: {'W_TITLE': title, 'W_BODY': body},
  );
}

/// For platforms without a known notification tool: does nothing.
class SilentNotificationService implements NotificationService {
  /// Creates the notifier.
  const SilentNotificationService();

  @override
  Future<void> show(String title, String body) async {}
}
