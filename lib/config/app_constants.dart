/// Fixed values shared across the app: timings and thresholds.
abstract final class AppConstants {
  /// Human readable app name.
  static const appName = 'Claude Usage Widget';

  /// Shown in the menu.
  static const version = '0.1.0';

  /// How often the data folder is polled in addition to file watching.
  static const pollInterval = Duration(seconds: 2);

  /// How often countdowns and "updated X ago" labels are redrawn.
  static const redrawInterval = Duration(seconds: 10);

  /// Data older than this is labelled as stale.
  static const staleAfter = Duration(minutes: 5);

  /// Seconds between status line runs requested from Claude Code.
  static const statusLineRefreshSeconds = 5;

  /// Usage percent at which the widget turns amber.
  static const warnPercent = 70.0;

  /// Usage percent at which the widget turns red.
  static const dangerPercent = 90.0;

  /// Usage percents that trigger a desktop notification, ascending.
  static const alertPercents = [80.0, 95.0];

  /// Default strength of the glass fill, from [minOpacity] to 1.
  static const defaultOpacity = 0.9;

  /// Lowest glass strength the slider allows.
  static const minOpacity = 0.5;
}
