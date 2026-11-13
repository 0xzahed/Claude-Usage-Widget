import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Timing shared by every animation, so the widget moves as one object.
abstract final class AppMotion {
  /// The card changing shape between pill, details and settings.
  static const morph = Duration(milliseconds: 460);

  /// Content cross-fading while the card morphs.
  static const content = Duration(milliseconds: 220);

  /// A ring settling on a new value.
  static const value = Duration(milliseconds: 720);

  /// Slightly bouncy spring used for shape and value changes.
  static const spring = SpringCurve();
}

/// The step response of a damped spring, as a [Curve].
///
/// Unlike an ease curve it starts fast and settles naturally; with a
/// [dampingRatio] below 1 it overshoots a little before coming to rest.
class SpringCurve extends Curve {
  /// Creates a spring; 1 is critically damped (no bounce), lower is bouncier.
  const SpringCurve({this.dampingRatio = 0.82})
    : assert(dampingRatio > 0 && dampingRatio <= 1, 'Use a ratio in (0, 1].');

  /// How quickly oscillation dies out.
  final double dampingRatio;

  // Decay chosen so the spring is within 0.1% of rest at t = 1.
  static const _settle = 6.9;

  @override
  double transformInternal(double t) {
    if (dampingRatio >= 1) {
      const omega = _settle + 2.6;
      return 1 - math.exp(-omega * t) * (1 + omega * t);
    }
    final omega = _settle / dampingRatio;
    final damped = omega * math.sqrt(1 - dampingRatio * dampingRatio);
    final envelope = math.exp(-_settle * t);
    return 1 -
        envelope *
            (math.cos(damped * t) + (_settle / damped) * math.sin(damped * t));
  }
}
