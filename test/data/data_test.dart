import 'dart:convert';
import 'dart:io';

import 'package:claude_usage_widget/data/models/session_record_mapper.dart';
import 'package:claude_usage_widget/data/repositories/status_line_repository.dart';
import 'package:claude_usage_widget/data/repositories/usage_repository.dart';
import 'package:claude_usage_widget/data/services/claude_settings_service.dart';
import 'package:claude_usage_widget/data/services/usage_file_service.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usage_bridge/bridge.dart' show recordsDir;

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('data'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('SessionRecordMapper', () {
    test('parses a subscription record', () {
      final parsed = SessionRecordMapper.fromJson({
        'session_id': 's',
        'written_at': 100,
        'rate_limits': {
          'five_hour': {'used_percentage': 24, 'resets_at': 200},
          'seven_day': {'used_percentage': 61},
        },
      })!;
      expect(parsed.fiveHour?.usedPercent, 24);
      expect(parsed.fiveHour?.resetsAt, isNotNull);
      expect(parsed.sevenDay?.resetsAt, isNull);
    });

    test('parses gateway spend fields', () {
      final parsed = SessionRecordMapper.fromJson({
        'rate_limits': {
          'spend_limit': {
            'used_percentage': 40,
            'used_usd': 20,
            'limit_usd': 50,
          },
        },
      })!;
      expect(parsed.spendLimit?.usedPercent, 40);
      expect(parsed.spendLimitUsd, 50);
    });

    test('rejects non-objects and tolerates missing fields', () {
      expect(SessionRecordMapper.fromJson([1]), isNull);
      expect(
        SessionRecordMapper.fromJson(<String, Object?>{})!.fiveHour,
        isNull,
      );
    });
  });

  group('UsageRepository', () {
    test('skips malformed files and emits a snapshot', () async {
      final dir = Directory(p.join(tmp.path, 'records'))..createSync();
      File(p.join(dir.path, 'bad.json')).writeAsStringSync('{not json');
      File(p.join(dir.path, 'ok.json')).writeAsStringSync(
        jsonEncode({
          'session_id': 'ok',
          'written_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'rate_limits': {
            'five_hour': {'used_percentage': 30},
          },
        }),
      );
      final repo = UsageRepository(
        files: UsageFileService(
          directory: dir.path,
          pollInterval: const Duration(milliseconds: 50),
        ),
      );
      final first = await repo.watch().first;
      expect(first, isA<SubscriptionUsage>());
    });

    test('missing folder yields no usage', () async {
      final repo = UsageRepository(
        files: UsageFileService(directory: p.join(tmp.path, 'nope')),
      );
      expect(await repo.watch().first, isA<NoUsage>());
    });
  });

  group('StatusLineRepository', () {
    late File settings;
    StatusLineRepository make() => StatusLineRepository(
      settings: ClaudeSettingsService(configDir: tmp.path),
      bridgePath: r'C:\app\usage_bridge.exe',
    );
    Map<String, Object?> read() =>
        jsonDecode(settings.readAsStringSync()) as Map<String, Object?>;

    setUp(() => settings = File(p.join(tmp.path, 'settings.json')));

    test(
      'installs with forward slashes and refresh, keeping other keys',
      () async {
        settings.writeAsStringSync(jsonEncode({'theme': 'dark'}));
        final repo = make();
        await repo.install();
        final statusLine = read()['statusLine']! as Map<String, Object?>;
        expect(read()['theme'], 'dark');
        expect(statusLine['command'], '"C:/app/usage_bridge.exe"');
        expect(statusLine['refreshInterval'], 5);
        expect(await repo.isInstalled(), isTrue);
      },
    );

    test('backs up and restores a previous status line', () async {
      settings.writeAsStringSync(
        jsonEncode({
          'statusLine': {'type': 'command', 'command': 'old.sh'},
        }),
      );
      final repo = make();
      await repo.install();
      await repo.install(); // must not replace the backup with our own entry
      await repo.uninstall();
      final restored = read()['statusLine']! as Map<String, Object?>;
      expect(restored['command'], 'old.sh');
      expect(
        File(p.join(recordsDir(tmp.path), 'previous-statusline.json'))
            .existsSync(),
        isFalse,
      );
    });

    test('uninstall without a backup removes the entry', () async {
      final repo = make();
      await repo.install();
      await repo.uninstall();
      expect(read().containsKey('statusLine'), isFalse);
    });

    test('invalid settings.json is reported and left untouched', () async {
      settings.writeAsStringSync('[1, 2]');
      await expectLater(make().install(), throwsFormatException);
      expect(settings.readAsStringSync(), '[1, 2]');
    });
  });
}
