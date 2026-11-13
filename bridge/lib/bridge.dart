/// Shared by the status line command and the widget: where records live, what
/// they contain, and how they are written.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Records older than this many days are deleted by the bridge and ignored by
/// the widget.
const int keepDays = 7;

/// Folder inside the Claude config directory that holds the records.
const String recordsFolderName = 'usage-widget';

/// JSON keys of a record: the fields Claude Code sends plus the bookkeeping
/// fields added by [buildRecord].
abstract final class RecordKeys {
  /// Unique id of the Claude Code session.
  static const sessionId = 'session_id';

  /// Unix seconds when the record was last written (bookkeeping).
  static const writtenAt = 'written_at';

  /// Local calendar day of the last write, `YYYY-MM-DD` (bookkeeping).
  static const day = 'day';

  /// Session cost in USD when [day] began (bookkeeping).
  static const dayBaseCost = 'day_base_cost';

  /// Rate limit block sent by Claude Code.
  static const rateLimits = 'rate_limits';

  /// Cost block sent by Claude Code.
  static const cost = 'cost';

  /// Context window block sent by Claude Code.
  static const contextWindow = 'context_window';
}

/// Returns the Claude config directory: `CLAUDE_CONFIG_DIR` if set, otherwise
/// `.claude` in the home directory.
String claudeConfigDir(Map<String, String> env) {
  final custom = env['CLAUDE_CONFIG_DIR'];
  if (custom != null && custom.isNotEmpty) return custom;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
  return p.join(home, '.claude');
}

/// Returns the folder that holds the records for [configDir].
String recordsDir(String configDir) => p.join(configDir, recordsFolderName);

/// Formats the local calendar day of [t] as `YYYY-MM-DD`.
String dayKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

double? _totalCost(Map<String, Object?>? record) {
  final cost = record?[RecordKeys.cost];
  final total = cost is Map<String, Object?> ? cost['total_cost_usd'] : null;
  return total is num ? total.toDouble() : null;
}

/// Adds the widget's bookkeeping fields to a status line [data] payload.
///
/// `day_base_cost` is the session cost when today began, so the widget can
/// show spend since midnight instead of the whole cost of a resumed session.
Map<String, Object?> buildRecord(
  Map<String, Object?> data,
  Map<String, Object?>? previous,
  DateTime now,
) {
  final today = dayKey(now);
  final double base;
  if (previous == null) {
    base = 0;
  } else if (previous[RecordKeys.day] == today) {
    base = (previous[RecordKeys.dayBaseCost] as num?)?.toDouble() ?? 0;
  } else {
    base = _totalCost(previous) ?? 0;
  }
  return {
    ...data,
    RecordKeys.writtenAt: now.millisecondsSinceEpoch ~/ 1000,
    RecordKeys.day: today,
    RecordKeys.dayBaseCost: base,
  };
}

/// Atomically writes [data] under [configDir], then prunes old records.
///
/// The file is written to a temporary name and renamed, so the widget never
/// reads a half-written file.
void writeRecord(String configDir, Map<String, Object?> data, DateTime now) {
  final dir = Directory(recordsDir(configDir))..createSync(recursive: true);
  final id = (data[RecordKeys.sessionId] ?? 'unknown').toString().replaceAll(
        RegExp(r'[^\w-]'),
        '_',
      );
  final target = File(p.join(dir.path, '$id.json'));
  final tmp = File(p.join(dir.path, '.$id.tmp'));
  tmp.writeAsStringSync(
    jsonEncode(buildRecord(data, _readRecord(target), now)),
  );
  tmp.renameSync(target.path);
  pruneRecords(dir, now);
}

Map<String, Object?>? _readRecord(File file) {
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

/// Deletes record files in [dir] not modified for [keepDays] days.
void pruneRecords(Directory dir, DateTime now) {
  final cutoff = now.subtract(const Duration(days: keepDays));
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    try {
      if (file.lastModifiedSync().isBefore(cutoff)) file.deleteSync();
    } on FileSystemException {
      // Another process removed or locked it; pruning is best effort.
    }
  }
}

/// Short text printed as the status line itself.
String summary(Map<String, Object?> data) {
  final limits = data[RecordKeys.rateLimits];
  if (limits is Map<String, Object?>) {
    String percent(String key) {
      final window = limits[key];
      final used =
          window is Map<String, Object?> ? window['used_percentage'] : null;
      return used is num ? '${used.round()}%' : '--';
    }

    return '5h ${percent('five_hour')} · 7d ${percent('seven_day')}';
  }
  final usd = _totalCost(data);
  return usd != null ? '\$${usd.toStringAsFixed(2)}' : 'Claude';
}
