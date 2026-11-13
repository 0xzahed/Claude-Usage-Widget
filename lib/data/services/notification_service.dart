import 'dart:io';

import 'package:claude_usage_widget/config/logger.dart';

/// Shows desktop notifications.
abstract interface class NotificationService {
  /// Picks the implementation for the current OS.
  factory NotificationService.forPlatform() = DesktopNotificationService;

  /// Shows a notification with [title] and [body].
  Future<void> show(String title, String body);
}

/// Uses tools shipped with each OS, so no native plugin is needed.
class DesktopNotificationService implements NotificationService {
  /// Creates the service.
  DesktopNotificationService();

  // Text is passed through environment variables, never interpolated into the
  // script, so it cannot be mistaken for code.
  static const _windowsScript = r'''
[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
$t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$n = $t.GetElementsByTagName('text')
$n.Item(0).AppendChild($t.CreateTextNode($env:W_TITLE)) | Out-Null
$n.Item(1).AppendChild($t.CreateTextNode($env:W_BODY)) | Out-Null
$app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show([Windows.UI.Notifications.ToastNotification]::new($t))
''';

  @override
  Future<void> show(String title, String body) async {
    try {
      if (Platform.isLinux) {
        await Process.run('notify-send', ['-a', 'Claude Usage', title, body]);
      } else if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'on run argv\n'
              'display notification (item 2 of argv) with title (item 1 of argv)\n'
              'end run',
          title,
          body,
        ]);
      } else if (Platform.isWindows) {
        await Process.run(
          'powershell',
          ['-NoProfile', '-Command', _windowsScript],
          environment: {'W_TITLE': title, 'W_BODY': body},
        );
      }
    } on ProcessException catch (e) {
      logWarning('Notification tool unavailable', e);
    }
  }
}
