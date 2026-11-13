import 'dart:ui';

import 'package:claude_usage_widget/data/services/window_service.dart';
import 'package:claude_usage_widget/ui/core/motion.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/widget_layout.dart';

/// Keeps the native window sized for the card, including while the card
/// animates between shapes.
///
/// Resizing a native window on every frame stutters, so a morph is done in
/// three steps: grow the window to hold both shapes, let the card animate
/// inside it, then shrink the window to fit.
class WindowMorpher {
  /// Creates a morpher for a window that currently has [initialSize].
  WindowMorpher({
    required this._window,
    required Size initialSize,
    this.duration = AppMotion.morph,
  }) : _size = initialSize;

  /// How long the card takes to change shape.
  final Duration duration;

  final WindowService _window;
  Size _size;
  int _generation = 0;
  bool _morphing = false;

  /// Fits the window to [size] now, unless a morph is in flight; the morph
  /// fits the window itself when it finishes.
  Future<void> fit(Size size) async {
    if (_morphing) return;
    await _resize(size);
  }

  /// Morphs towards [target]. [apply] switches the UI to the new shape once
  /// the window is large enough; [settledSize] is asked for the final size
  /// when the animation ends, as the view may have changed again by then.
  Future<void> morph({
    required Size target,
    required void Function() apply,
    required Size Function() settledSize,
  }) async {
    final generation = ++_generation;
    _morphing = true;
    await _resize(WidgetLayout.union(_size, target));
    apply();
    await Future<void>.delayed(duration);
    // A newer morph owns the window now; let it finish the job.
    if (generation != _generation) return;
    _morphing = false;
    await _resize(settledSize());
  }

  /// Abandons any morph in flight, so the next [fit] applies immediately.
  void cancel() {
    _generation++;
    _morphing = false;
  }

  Future<void> _resize(Size size) async {
    if (size == _size) return;
    _size = size;
    await _window.setSize(size);
  }
}
