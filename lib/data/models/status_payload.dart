import 'dart:math' as math;

import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:flutter/foundation.dart';
import 'package:usage_bridge/bridge.dart' show RecordKeys;

/// One session record written by the bridge, parsed from JSON.
///
/// Parsing is tolerant: Claude Code omits fields depending on the account, so
/// every field except [sessionId] is optional.
@immutable
final class StatusPayload {
  /// Creates a payload; prefer [StatusPayload.fromJson].
  const StatusPayload({
    required this.sessionId,
    required this.writtenAt,
    this.day,
    this.dayBaseCostUsd = 0,
    this.fiveHour,
    this.sevenDay,
    this.spendLimit,
    this.spendUsedUsd,
    this.spendLimitUsd,
    this.totalCostUsd,
    this.contextUsedPercent,
  });

  /// Parses a record, returning null if it is not a JSON object.
  static StatusPayload? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final limits = _object(json[RecordKeys.rateLimits]);
    final spend = _object(limits?['spend_limit']);
    return StatusPayload(
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

  /// Claude Code session id.
  final String sessionId;

  /// When the bridge last wrote this record.
  final DateTime writtenAt;

  /// Local day of the last write, `YYYY-MM-DD`.
  final String? day;

  /// Session cost when [day] began.
  final double dayBaseCostUsd;

  /// 5-hour window, subscription accounts only.
  final RateLimit? fiveHour;

  /// 7-day window, subscription accounts only.
  final RateLimit? sevenDay;

  /// Gateway spend limit window, if any.
  final RateLimit? spendLimit;

  /// Gateway dollars spent.
  final double? spendUsedUsd;

  /// Gateway dollar limit.
  final double? spendLimitUsd;

  /// Total session cost at list price.
  final double? totalCostUsd;

  /// Context window percent used.
  final double? contextUsedPercent;

  /// Spend since midnight for this session, never negative.
  double get todayCostUsd => math.max(0, (totalCostUsd ?? 0) - dayBaseCostUsd);

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
