import 'dart:ui';

import 'package:claude_usage_widget/data/services/window_service.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/window_morpher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWindow extends Mock implements WindowService {}

void main() {
  const small = Size(100, 50);
  const big = Size(300, 200);
  late _MockWindow window;
  late List<Size> sizes;

  setUpAll(() => registerFallbackValue(Size.zero));

  setUp(() {
    window = _MockWindow();
    sizes = [];
    when(() => window.setSize(any())).thenAnswer((invocation) async {
      sizes.add(invocation.positionalArguments.single as Size);
    });
  });

  WindowMorpher make([Duration duration = Duration.zero]) =>
      WindowMorpher(window: window, initialSize: small, duration: duration);

  test('growing: the window is enlarged before the UI changes', () async {
    final events = <String>[];
    when(() => window.setSize(any())).thenAnswer((_) async {
      events.add('resize');
    });
    await make().morph(
      target: big,
      apply: () => events.add('apply'),
      settledSize: () => big,
    );
    expect(events, ['resize', 'apply']);
  });

  test('shrinking: the window only shrinks after the animation', () async {
    final morpher = make();
    await morpher.fit(big);
    await morpher.morph(target: small, apply: () {}, settledSize: () => small);
    expect(sizes, [big, small]);
  });

  test(
    'fit is ignored during a morph and unchanged sizes are skipped',
    () async {
      final morpher = make(const Duration(milliseconds: 20));
      final morph = morpher.morph(
        target: big,
        apply: () {},
        settledSize: () => big,
      );
      await morpher.fit(small);
      await morph;
      await morpher.fit(big);
      expect(sizes, [big]);
    },
  );

  test('a newer morph takes over the window from an older one', () async {
    final morpher = make(const Duration(milliseconds: 20));
    const medium = Size(200, 100);
    final first = morpher.morph(
      target: big,
      apply: () {},
      settledSize: () => big,
    );
    final second = morpher.morph(
      target: medium,
      apply: () {},
      settledSize: () => medium,
    );
    await Future.wait([first, second]);
    expect(sizes.last, medium);
  });

  test('cancel lets the next fit apply immediately', () async {
    final morpher = make(const Duration(milliseconds: 20));
    final morph = morpher.morph(
      target: big,
      apply: () {},
      settledSize: () => big,
    );
    morpher.cancel();
    await morpher.fit(small);
    await morph;
    expect(sizes.last, small);
  });
}
