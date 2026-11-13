import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:equatable/equatable.dart';

/// A limit that just crossed a notification threshold.
class UsageAlert extends Equatable {
  /// Creates an alert for [limitName] at [percent], crossing [threshold].
  const UsageAlert({
    required this.limitName,
    required this.percent,
    required this.threshold,
    required this.isFinalThreshold,
  });

  /// Which limit, for example "5-hour".
  final String limitName;

  /// Current percent used.
  final double percent;

  /// The threshold that was crossed.
  final double threshold;

  /// Whether [threshold] is the last warning before the limit.
  final bool isFinalThreshold;

  /// Headline for a notification.
  String get title => 'Claude usage: $limitName at ${percent.round()}%';

  /// Supporting line for a notification.
  String get message => isFinalThreshold
      ? 'Almost at your limit.'
      : 'You have used over ${threshold.round()}%.';

  @override
  List<Object?> get props => [limitName, percent, threshold, isFinalThreshold];
}

/// Decides when to notify: once per threshold crossing, re-armed when usage
/// drops back below it (for example after a window resets).
class AlertPolicy {
  /// Creates a policy using [thresholds], ascending.
  AlertPolicy({this.thresholds = AppConstants.alertPercents});

  /// Percents that trigger an alert.
  final List<double> thresholds;

  final _highest = <String, double>{};

  /// Returns the alerts newly due for [snapshot] as of [now].
  List<UsageAlert> evaluate(UsageSnapshot snapshot, DateTime now) {
    final Map<String, RateLimit?> limits = switch (snapshot) {
      SubscriptionUsage(:final fiveHour, :final sevenDay) => {
        '5-hour': fiveHour,
        '7-day': sevenDay,
      },
      GatewayUsage(:final spend) => {'spend': spend},
      NoUsage() || ApiUsage() => const {},
    };
    return [
      for (final MapEntry(:key, :value) in limits.entries)
        if (value != null) ?check(key, value.percentAt(now)),
    ];
  }

  /// Returns an alert if [percent] newly crossed a threshold for [limitName].
  UsageAlert? check(String limitName, double percent) {
    final crossed = thresholds.where((t) => percent >= t);
    final level = crossed.isEmpty ? 0.0 : crossed.last;
    final previous = _highest[limitName] ?? 0;
    _highest[limitName] = level;
    if (level <= previous) return null;
    return UsageAlert(
      limitName: limitName,
      percent: percent,
      threshold: level,
      isFinalThreshold: level >= thresholds.last,
    );
  }
}
