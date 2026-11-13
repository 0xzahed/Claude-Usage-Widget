import 'dart:math' as math;

import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:flutter/foundation.dart';

/// What one Claude Code session last reported, as written by the bridge.
///
/// Claude Code omits fields depending on the account, so every field except
/// [sessionId] and [writtenAt] is optional.
@immutable
final class SessionRecord {
  /// Creates a record.
  const SessionRecord({
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
}
