import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's window position and opacity.
class PreferencesService {
  /// Creates a service over [_prefs].
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _x = 'window_x';
  static const _y = 'window_y';
  static const _opacity = 'opacity';

  /// Last saved window position, or null on first run.
  Offset? get windowPosition {
    final x = _prefs.getDouble(_x);
    final y = _prefs.getDouble(_y);
    return x == null || y == null ? null : Offset(x, y);
  }

  /// Saves the window position.
  Future<void> saveWindowPosition(Offset position) async {
    await _prefs.setDouble(_x, position.dx);
    await _prefs.setDouble(_y, position.dy);
  }

  /// Saved card opacity, or null if never changed.
  double? get opacity => _prefs.getDouble(_opacity);

  /// Saves the card opacity.
  Future<void> saveOpacity(double value) => _prefs.setDouble(_opacity, value);
}
