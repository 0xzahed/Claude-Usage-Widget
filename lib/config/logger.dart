import 'dart:developer' as developer;

/// Logs a recoverable problem; visible in DevTools and the debug console.
void logWarning(String message, [Object? error]) {
  developer.log(
    error == null ? message : '$message: $error',
    name: 'usage_widget',
    level: 900,
  );
}
