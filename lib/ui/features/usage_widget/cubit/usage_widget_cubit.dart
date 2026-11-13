import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:claude_usage_widget/data/repositories/status_line_repository.dart';
import 'package:claude_usage_widget/data/repositories/usage_repository.dart';
import 'package:claude_usage_widget/data/services/autostart_service.dart';
import 'package:claude_usage_widget/data/services/notification_service.dart';
import 'package:claude_usage_widget/data/services/preferences_service.dart';
import 'package:claude_usage_widget/data/services/tray_service.dart';
import 'package:claude_usage_widget/data/services/window_service.dart';
import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:claude_usage_widget/domain/use_cases/alert_policy.dart';
import 'package:claude_usage_widget/ui/core/motion.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/cubit/usage_widget_state.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/widget_layout.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the widget's state and coordinates window, tray, alerts and settings.
class UsageWidgetCubit extends Cubit<UsageWidgetState> {
  /// Creates the cubit; all collaborators are injected so tests can fake them.
  UsageWidgetCubit({
    required this._usage,
    required this._statusLine,
    required this._autostart,
    required PreferencesService preferences,
    required this._window,
    required this._tray,
    required this._notifications,
    AlertPolicy? alertPolicy,
    this._morphDuration = AppMotion.morph,
    DateTime Function() clock = DateTime.now,
  }) : _preferences = preferences,
       _alerts = alertPolicy ?? AlertPolicy(),
       _clock = clock,
       super(
         UsageWidgetState(
           now: clock(),
           opacity: preferences.opacity ?? AppConstants.defaultOpacity,
           alwaysOnTop: preferences.alwaysOnTop,
         ),
       );

  final UsageRepository _usage;
  final StatusLineRepository _statusLine;
  final AutostartService _autostart;
  final PreferencesService _preferences;
  final WindowService _window;
  final TrayService _tray;
  final NotificationService _notifications;
  final AlertPolicy _alerts;
  final Duration _morphDuration;
  final DateTime Function() _clock;

  Size _windowSize = WidgetLayout.windowSizeFor(WidgetLayout.pill);
  int _morphGeneration = 0;
  bool _morphing = false;

  StreamSubscription<UsageSnapshot>? _usageSub;
  StreamSubscription<Offset>? _moveSub;
  Timer? _redraw;

  /// Loads settings, starts the tray and begins listening for usage.
  Future<void> start() async {
    final trayAvailable = await _tray.start(
      TrayCallbacks(
        onToggleVisibility: () => unawaited(toggleVisibility()),
        onToggleStartup: () => unawaited(toggleStartup()),
        onQuit: () => unawaited(quit()),
      ),
    );
    emit(
      state.copyWith(
        trayAvailable: trayAvailable,
        statusLineInstalled: await _statusLine.isInstalled(),
        startupEnabled: await _autostart.isEnabled(),
      ),
    );
    await _refreshTrayMenu();
    _moveSub = _window.moved.listen(
      (position) => unawaited(_preferences.saveWindowPosition(position)),
    );
    _usageSub = _usage.watch().distinct().listen(_onSnapshot);
    _redraw = Timer.periodic(
      AppConstants.redrawInterval,
      (_) => emit(state.copyWith(now: _clock())),
    );
  }

  void _onSnapshot(UsageSnapshot snapshot) {
    final now = _clock();
    emit(state.copyWith(snapshot: snapshot, now: now));
    _checkAlerts(snapshot, now);
    unawaited(_tray.setTooltip(_tooltip(snapshot, now)));
    unawaited(_syncWindowSize());
  }

  void _checkAlerts(UsageSnapshot snapshot, DateTime now) {
    final Map<String, RateLimit?> limits = switch (snapshot) {
      SubscriptionUsage(:final fiveHour, :final sevenDay) => {
        '5-hour': fiveHour,
        '7-day': sevenDay,
      },
      GatewayUsage(:final spend) => {'spend': spend},
      _ => const <String, RateLimit?>{},
    };
    for (final MapEntry(:key, :value) in limits.entries) {
      if (value == null) continue;
      final alert = _alerts.check(key, value.percentAt(now));
      if (alert != null) {
        unawaited(
          _notifications.show(
            'Claude usage: ${alert.limitName} at ${alert.percent.round()}%',
            alert.threshold >= AppConstants.alertPercents.last
                ? 'Almost at your limit.'
                : 'You have used over ${alert.threshold.round()}%.',
          ),
        );
      }
    }
  }

  String _tooltip(UsageSnapshot snapshot, DateTime now) {
    String pct(double? v) => v == null ? '--' : '${v.round()}%';
    return switch (snapshot) {
      NoUsage() => 'Claude Usage',
      SubscriptionUsage(:final fiveHour, :final sevenDay) =>
        'Claude · 5h ${pct(fiveHour?.percentAt(now))}'
            ' · 7d ${pct(sevenDay?.percentAt(now))}',
      GatewayUsage(:final spend) =>
        'Claude · spend ${pct(spend.percentAt(now))}',
      ApiUsage(:final todayCostUsd) =>
        'Claude · ~\$${todayCostUsd.toStringAsFixed(2)} today',
    };
  }

  Future<void> _resizeWindow(Size size) async {
    if (size == _windowSize) return;
    _windowSize = size;
    await _window.setSize(size);
  }

  /// Fits the window to the current view, unless a morph is in flight; the
  /// morph fits it when it finishes.
  Future<void> _syncWindowSize() async {
    if (_morphing) return;
    await _resizeWindow(WidgetLayout.windowSize(state));
  }

  /// Starts a window drag.
  Future<void> startDrag() => _window.startDragging();

  /// Expands or collapses the details view.
  Future<void> toggleDetails() => _setMode(
    state.viewMode == ViewMode.pill ? ViewMode.details : ViewMode.pill,
  );

  /// Opens or closes the settings menu.
  Future<void> toggleMenu() =>
      _setMode(state.viewMode == ViewMode.menu ? ViewMode.pill : ViewMode.menu);

  /// Closes the settings menu.
  Future<void> closeMenu() => _setMode(ViewMode.pill);

  /// Switches view, morphing the card between the two shapes.
  ///
  /// The window first grows to hold both shapes, the card then animates
  /// inside it, and only afterwards does the window shrink to fit. Resizing
  /// the native window on every frame instead would stutter.
  Future<void> _setMode(ViewMode mode) async {
    if (mode == state.viewMode) return;
    final generation = ++_morphGeneration;
    final next = state.copyWith(viewMode: mode, clearError: true);
    _morphing = true;
    await _resizeWindow(
      WidgetLayout.union(_windowSize, WidgetLayout.windowSize(next)),
    );
    emit(next);
    await Future<void>.delayed(_morphDuration);
    // A newer morph owns the window now; let it finish the job.
    if (generation != _morphGeneration || isClosed) return;
    _morphing = false;
    await _syncWindowSize();
  }

  /// Registers or removes the bridge as the status line command.
  Future<void> toggleStatusLine() async {
    try {
      if (state.statusLineInstalled) {
        await _statusLine.uninstall();
      } else {
        await _statusLine.install();
      }
      emit(
        state.copyWith(
          statusLineInstalled: await _statusLine.isInstalled(),
          clearError: true,
        ),
      );
    } on FormatException catch (e) {
      emit(
        state.copyWith(errorMessage: 'settings.json is invalid: ${e.message}'),
      );
    } on FileSystemException catch (e) {
      emit(state.copyWith(errorMessage: 'Cannot write settings: ${e.message}'));
    }
  }

  /// Keeps the widget above other windows, or lets them cover it.
  Future<void> toggleAlwaysOnTop() async {
    final enabled = !state.alwaysOnTop;
    await _window.setAlwaysOnTop(enabled: enabled);
    emit(state.copyWith(alwaysOnTop: enabled));
    await _preferences.saveAlwaysOnTop(value: enabled);
  }

  /// Turns launch at startup on or off.
  Future<void> toggleStartup() async {
    await _autostart.setEnabled(enabled: !state.startupEnabled);
    emit(state.copyWith(startupEnabled: await _autostart.isEnabled()));
    await _refreshTrayMenu();
  }

  /// Previews a new glass strength while the slider moves.
  void setOpacity(double value) => emit(
    state.copyWith(
      opacity: value.clamp(AppConstants.minOpacity, 1.0).toDouble(),
    ),
  );

  /// Persists the current glass strength once the slider is released.
  Future<void> saveOpacity() => _preferences.saveOpacity(state.opacity);

  /// Shows or hides the window (only meaningful when a tray icon exists).
  Future<void> toggleVisibility() async {
    final visible = !state.windowVisible;
    // Hiding always returns to the pill, cancelling any morph in flight.
    _morphGeneration++;
    _morphing = false;
    emit(state.copyWith(windowVisible: visible, viewMode: ViewMode.pill));
    await _window.setVisible(visible: visible);
    await _refreshTrayMenu();
    await _syncWindowSize();
  }

  /// Quits the app.
  Future<void> quit() => _window.close();

  Future<void> _refreshTrayMenu() {
    if (!state.trayAvailable) return Future<void>.value();
    return _tray.updateMenu(
      windowVisible: state.windowVisible,
      startupEnabled: state.startupEnabled,
    );
  }

  @override
  Future<void> close() async {
    _redraw?.cancel();
    await _usageSub?.cancel();
    await _moveSub?.cancel();
    await _tray.dispose();
    await _window.dispose();
    return super.close();
  }
}
