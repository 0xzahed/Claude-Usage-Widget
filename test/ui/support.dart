import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:claude_usage_widget/ui/core/glass_theme.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/cubit/usage_widget_cubit.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/cubit/usage_widget_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cubit whose state is set by the test.
class MockUsageWidgetCubit extends MockCubit<UsageWidgetState>
    implements UsageWidgetCubit {}

/// The moment every UI test treats as "now".
final testNow = DateTime(2026, 11, 13, 12);

/// A subscription snapshot at the given percentages.
SubscriptionUsage subscription({double five = 24, double seven = 78}) =>
    SubscriptionUsage(
      fiveHour: RateLimit(
        usedPercent: five,
        resetsAt: testNow.add(const Duration(hours: 2, minutes: 30)),
      ),
      sevenDay: RateLimit(
        usedPercent: seven,
        resetsAt: testNow.add(const Duration(days: 2, hours: 21)),
      ),
      updatedAt: testNow,
    );

/// An API-key snapshot.
const apiUsage = ApiUsage(
  sessionCostUsd: 1.37,
  todayCostUsd: 4.2,
  contextPercent: 42,
);

/// A gateway snapshot.
final gatewayUsage = GatewayUsage(
  spend: RateLimit(
    usedPercent: 40,
    resetsAt: testNow.add(const Duration(days: 9)),
  ),
  usedUsd: 20,
  limitUsd: 50,
);

/// Loads the bundled typeface, so layout tests measure real text instead of
/// the square placeholder glyphs tests use by default.
Future<void> loadAppFont() async {
  final bytes = File('assets/fonts/Inter.ttf').readAsBytesSync();
  final loader = FontLoader(AppText.family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
