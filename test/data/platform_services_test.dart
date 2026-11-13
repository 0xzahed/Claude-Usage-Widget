import 'dart:io';

import 'package:claude_usage_widget/data/services/autostart_service.dart';
import 'package:claude_usage_widget/data/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Records what a service asked the OS to run.
class _Recorder {
  final calls = <(String, List<String>, Map<String, String>?)>[];
  int exitCode = 0;
  Object? failure;

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    if (failure case final Object error) throw error;
    calls.add((executable, arguments, environment));
    return ProcessResult(1, exitCode, '', '');
  }
}

void main() {
  late _Recorder os;
  setUp(() => os = _Recorder());

  group('notifications', () {
    test('Linux uses notify-send with the text as arguments', () async {
      await LinuxNotificationService(run: os.run).show('Title', 'Body');
      final (exe, args, _) = os.calls.single;
      expect(exe, 'notify-send');
      expect(args, containsAllInOrder(['Title', 'Body']));
    });

    test('macOS passes text as arguments, never inside the script', () async {
      const hostile = '" & do shell script "x';
      await MacNotificationService(run: os.run).show(hostile, 'Body');
      final (exe, args, _) = os.calls.single;
      expect(exe, 'osascript');
      expect(args[1], isNot(contains(hostile)));
      expect(args.sublist(2), [hostile, 'Body']);
    });

    test('Windows passes text through the environment', () async {
      const hostile = r"'); Remove-Item x; ('";
      await WindowsNotificationService(run: os.run).show(hostile, 'Body');
      final (exe, args, env) = os.calls.single;
      expect(exe, 'powershell');
      expect(args.join(' '), isNot(contains(hostile)));
      expect(env, {'W_TITLE': hostile, 'W_BODY': 'Body'});
    });

    test('a missing tool is logged, not thrown', () async {
      os.failure = const ProcessException('notify-send', []);
      await expectLater(
        LinuxNotificationService(run: os.run).show('a', 'b'),
        completes,
      );
    });
  });

  group('autostart', () {
    test('XDG entry is created and removed', () async {
      final tmp = Directory.systemTemp.createTempSync('autostart');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final service = FileAutostartService.xdg(
        executable: '/opt/app/widget',
        configHome: tmp.path,
      );
      expect(await service.isEnabled(), isFalse);
      await service.setEnabled(enabled: true);
      final entry = File(
        p.join(tmp.path, 'autostart', 'claude-usage-widget.desktop'),
      );
      expect(entry.readAsStringSync(), contains('Exec="/opt/app/widget"'));
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(enabled: false);
      expect(entry.existsSync(), isFalse);
    });

    test('Windows reads and writes the Run registry key', () async {
      final service = WindowsAutostartService(r'C:\app\w.exe', run: os.run);
      os.exitCode = 1;
      expect(await service.isEnabled(), isFalse);
      os.exitCode = 0;
      await service.setEnabled(enabled: true);
      await service.setEnabled(enabled: false);
      expect(os.calls.map((c) => c.$2.first), ['query', 'add', 'delete']);
      expect(os.calls[1].$2, contains(r'"C:\app\w.exe"'));
    });
  });
}
