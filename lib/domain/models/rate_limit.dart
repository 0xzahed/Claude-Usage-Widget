import 'package:equatable/equatable.dart';

/// One rate-limit window, such as the 5-hour or 7-day limit.
final class RateLimit extends Equatable {
  /// Creates a window that is [usedPercent] used and resets at [resetsAt].
  const RateLimit({required this.usedPercent, this.resetsAt});

  /// Percent of the window used, as last reported.
  final double usedPercent;

  /// When the window resets, if known.
  final DateTime? resetsAt;

  /// Percent used at [now]: 0 once the window has reset.
  double percentAt(DateTime now) =>
      resetsAt != null && now.isAfter(resetsAt!) ? 0 : usedPercent;

  /// Time left until the reset, or null if unknown or already past.
  Duration? untilReset(DateTime now) {
    final reset = resetsAt;
    if (reset == null || now.isAfter(reset)) return null;
    return reset.difference(now);
  }

  @override
  List<Object?> get props => [usedPercent, resetsAt];
}
