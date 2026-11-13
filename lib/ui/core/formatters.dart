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
