import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';

/// One-line summary of [snapshot] as of [now], for tooltips.
String formatSummary(UsageSnapshot snapshot, DateTime now) {
  String percent(double? value) => value == null ? '--' : '${value.round()}%';
  return switch (snapshot) {
    NoUsage() => 'Claude Usage',
    SubscriptionUsage(:final fiveHour, :final sevenDay) =>
      'Claude · 5h ${percent(fiveHour?.percentAt(now))}'
          ' · 7d ${percent(sevenDay?.percentAt(now))}',
    GatewayUsage(:final spend) =>
      'Claude · spend ${percent(spend.percentAt(now))}',
    ApiUsage(:final todayCostUsd) =>
      'Claude · ~${formatMoney(todayCostUsd)} today',
  };
}

/// Formats a time until reset, such as "2h 30m" or "2d 21h".
String formatDuration(Duration remaining) {
  if (remaining.inDays >= 1) {
    return '${remaining.inDays}d ${remaining.inHours % 24}h';
  }
  if (remaining.inHours >= 1) {
    return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
  }
  return '${remaining.inMinutes.clamp(1, 59)}m';
}

/// Formats how long ago something happened, such as "12m ago".
String formatAge(Duration age) {
  if (age.inHours >= 1) return '${age.inHours}h ago';
  return '${age.inMinutes.clamp(1, 59)}m ago';
}

/// Formats [value] as dollars with [decimals] places.
String formatMoney(double value, [int decimals = 2]) =>
    '\$${value.toStringAsFixed(decimals)}';
