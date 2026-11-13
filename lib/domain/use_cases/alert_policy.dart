import 'package:claude_usage_widget/config/app_constants.dart';

/// A limit that just crossed a notification threshold.
class UsageAlert {
  /// Creates an alert for [limitName] at [percent], crossing [threshold].
  const UsageAlert({
    required this.limitName,
    required this.percent,
    required this.threshold,
  });

  /// Which limit, for example "5-hour".
  final String limitName;

  /// Current percent used.
  final double percent;

  /// The threshold that was crossed.
  final double threshold;
}

/// Decides when to notify: once per threshold crossing, re-armed when usage
/// drops back below it (for example after a window resets).
class AlertPolicy {
  /// Creates a policy using [thresholds], ascending.
  AlertPolicy({this.thresholds = AppConstants.alertPercents});

  /// Percents that trigger an alert.
  final List<double> thresholds;

  final _highest = <String, double>{};

  /// Returns an alert if [percent] newly crossed a threshold for [limitName].
  UsageAlert? check(String limitName, double percent) {
    final crossed = thresholds.where((t) => percent >= t);
    final level = crossed.isEmpty ? 0.0 : crossed.last;
    final previous = _highest[limitName] ?? 0;
    _highest[limitName] = level;
    if (level > previous) {
      return UsageAlert(
        limitName: limitName,
        percent: percent,
        threshold: level,
      );
    }
    return null;
  }
}
