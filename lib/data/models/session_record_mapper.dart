import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/session_record.dart';
import 'package:usage_bridge/bridge.dart' show RecordKeys;

/// Translates the bridge's JSON records into [SessionRecord]s.
///
/// Knowledge of the wire format stays here, in the data layer, so the domain
/// model does not change when Claude Code renames a field.
abstract final class SessionRecordMapper {
  /// Parses a record, returning null if [json] is not a JSON object.
  ///
  /// Parsing is tolerant: missing or mistyped fields become null.
  static SessionRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final limits = _object(json[RecordKeys.rateLimits]);
    final spend = _object(limits?['spend_limit']);
    return SessionRecord(
      sessionId: json[RecordKeys.sessionId]?.toString() ?? 'unknown',
      writtenAt: DateTime.fromMillisecondsSinceEpoch(
        (_number(json[RecordKeys.writtenAt]) ?? 0).toInt() * 1000,
      ),
      day: json[RecordKeys.day] as String?,
      dayBaseCostUsd: _number(json[RecordKeys.dayBaseCost]) ?? 0,
      fiveHour: _limit(limits?['five_hour']),
      sevenDay: _limit(limits?['seven_day']),
      spendLimit: _limit(spend),
      spendUsedUsd: _number(spend?['used_usd']),
      spendLimitUsd: _number(spend?['limit_usd']),
      totalCostUsd: _number(_object(json[RecordKeys.cost])?['total_cost_usd']),
      contextUsedPercent: _number(
        _object(json[RecordKeys.contextWindow])?['used_percentage'],
      ),
    );
  }

  static Map<String, Object?>? _object(Object? value) =>
      value is Map<String, Object?> ? value : null;

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  static RateLimit? _limit(Object? json) {
    final window = _object(json);
    final used = _number(window?['used_percentage']);
    if (used == null) return null;
    final reset = _number(window?['resets_at']);
    return RateLimit(
      usedPercent: used,
      resetsAt: reset == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(reset.toInt() * 1000),
    );
  }
}
