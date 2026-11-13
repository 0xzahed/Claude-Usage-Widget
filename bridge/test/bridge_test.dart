import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:usage_bridge/bridge.dart';

Map<String, Object?> payload(double cost, {String id = 's1'}) => {
      RecordKeys.sessionId: id,
      RecordKeys.cost: {'total_cost_usd': cost},
      RecordKeys.rateLimits: {
        'five_hour': {'used_percentage': 24.4, 'resets_at': 1},
        'seven_day': {'used_percentage': 61, 'resets_at': 1},
      },
    };

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('bridge'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, Object?> read(String id) {
    final file = File(p.join(recordsDir(tmp.path), '$id.json'));
    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  test('writes a readable record with bookkeeping and no temp files', () {
    writeRecord(tmp.path, payload(1.5), DateTime(2026, 11, 13, 10));
    final record = read('s1');
    expect(record[RecordKeys.day], '2026-11-13');
    expect(record[RecordKeys.dayBaseCost], 0);
    final leftovers = Directory(
      recordsDir(tmp.path),
    ).listSync().where((e) => e.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('keeps the baseline within the same day', () {
    final now = DateTime(2026, 11, 13, 10);
    writeRecord(tmp.path, payload(1), now);
    writeRecord(tmp.path, payload(2.5), now.add(const Duration(hours: 1)));
    expect(read('s1')[RecordKeys.dayBaseCost], 0);
  });

  test('sets the baseline to the previous total on a new day', () {
    writeRecord(tmp.path, payload(4), DateTime(2026, 11, 12, 22));
    writeRecord(tmp.path, payload(4.6), DateTime(2026, 11, 13, 9));
    final record = read('s1');
    expect(record[RecordKeys.day], '2026-11-13');
    expect(record[RecordKeys.dayBaseCost], 4.0);
  });

  test('prunes records older than $keepDays days', () {
    final dir = Directory(recordsDir(tmp.path))..createSync(recursive: true);
    final old = File(p.join(dir.path, 'old.json'))..writeAsStringSync('{}');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));
    writeRecord(tmp.path, payload(1), DateTime.now());
    expect(old.existsSync(), isFalse);
    expect(File(p.join(dir.path, 's1.json')).existsSync(), isTrue);
  });

  test('summary formats limits, cost and fallback', () {
    expect(summary(payload(1)), '5h 24% · 7d 61%');
    expect(
        summary({
          RecordKeys.cost: {'total_cost_usd': 1.234},
        }),
        r'$1.23',);
    expect(summary({}), 'Claude');
  });

  test('claudeConfigDir honours CLAUDE_CONFIG_DIR', () {
    expect(claudeConfigDir({'CLAUDE_CONFIG_DIR': '/x'}), '/x');
    expect(claudeConfigDir({'HOME': '/h'}), p.join('/h', '.claude'));
  });
}
