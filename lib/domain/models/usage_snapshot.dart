import 'dart:math' as math;

import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:equatable/equatable.dart';

/// What the widget shows, one case per kind of account.
sealed class UsageSnapshot extends Equatable {
  /// Creates a snapshot last updated at [updatedAt].
  const UsageSnapshot({this.updatedAt});

  /// When the underlying data was last written, if known.
  final DateTime? updatedAt;

  /// The highest percent that should colour the UI, at [now].
  double severityPercent(DateTime now);

  @override
  List<Object?> get props => [updatedAt];
}

/// No data has arrived yet.
final class NoUsage extends UsageSnapshot {
  /// Creates the empty snapshot.
  const NoUsage();

  @override
  double severityPercent(DateTime now) => 0;
}

/// Pro and Max accounts: 5-hour and 7-day windows.
final class SubscriptionUsage extends UsageSnapshot {
  /// Creates a subscription snapshot; at least one window is expected.
  const SubscriptionUsage({this.fiveHour, this.sevenDay, super.updatedAt});

  /// The 5-hour window.
  final RateLimit? fiveHour;

  /// The 7-day window.
  final RateLimit? sevenDay;

  @override
  double severityPercent(DateTime now) =>
      math.max(fiveHour?.percentAt(now) ?? 0, sevenDay?.percentAt(now) ?? 0);

  @override
  List<Object?> get props => [...super.props, fiveHour, sevenDay];
}

/// Accounts behind a company gateway with a spend limit.
final class GatewayUsage extends UsageSnapshot {
  /// Creates a gateway snapshot.
  const GatewayUsage({
    required this.spend,
    this.usedUsd,
    this.limitUsd,
    super.updatedAt,
  });

  /// Spend limit window; its percent is authoritative.
  final RateLimit spend;

  /// Dollars spent, when the gateway reports it.
  final double? usedUsd;

  /// Dollar limit, when the gateway reports it.
  final double? limitUsd;

  @override
  double severityPercent(DateTime now) => spend.percentAt(now);

  @override
  List<Object?> get props => [...super.props, spend, usedUsd, limitUsd];
}

/// API-key accounts: estimated cost and context window.
final class ApiUsage extends UsageSnapshot {
  /// Creates an API snapshot.
  const ApiUsage({
    required this.sessionCostUsd,
    required this.todayCostUsd,
    this.contextPercent,
    super.updatedAt,
  });

  /// Estimated cost of the newest session.
  final double sessionCostUsd;

  /// Estimated cost since midnight across sessions.
  final double todayCostUsd;

  /// Context window used by the newest session.
  final double? contextPercent;

  @override
  double severityPercent(DateTime now) => contextPercent ?? 0;

  @override
  List<Object?> get props => [
    ...super.props,
    sessionCostUsd,
    todayCostUsd,
    contextPercent,
  ];
}
