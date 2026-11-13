import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:claude_usage_widget/domain/use_cases/aggregate_usage.dart';
import 'package:claude_usage_widget/domain/use_cases/alert_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 11, 13, 12);
  const aggregate = AggregateUsage();

  group('RateLimit', () {
    test('reads 0% once the window has reset', () {
      final past = RateLimit(
        usedPercent: 80,
        resetsAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(past.percentAt(now), 0);
      expect(past.untilReset(now), isNull);
    });

    test('keeps the percent and counts down before the reset', () {
      final future = RateLimit(
        usedPercent: 80,
        resetsAt: now.add(const Duration(hours: 2)),
      );
      expect(future.percentAt(now), 80);
      expect(future.untilReset(now), const Duration(hours: 2));
    });
  });

  group('AggregateUsage', () {
    RateLimit limit(double pct, int resetHours) => RateLimit(
      usedPercent: pct,
      resetsAt: now.add(Duration(hours: resetHours)),
    );

    test('no payloads means no usage', () {
      expect(aggregate(const [], now), isA<NoUsage>());
    });

    test('ignores payloads older than the retention window', () {
      final old = payload(
        writtenAt: now.subtract(const Duration(days: 8)),
        fiveHour: limit(50, 1),
      );
      expect(aggregate([old], now), isA<NoUsage>());
    });

    test('takes the latest window and highest percent across sessions', () {
      final snapshot = aggregate([
        payload(id: 'idle', fiveHour: limit(1, 3), sevenDay: limit(44, 90)),
        payload(id: 'live', fiveHour: limit(27, 3), sevenDay: limit(48, 90)),
        payload(id: 'old', fiveHour: limit(90, 1), sevenDay: limit(99, 10)),
      ], now);
      expect(snapshot, isA<SubscriptionUsage>());
      final sub = snapshot as SubscriptionUsage;
      expect(sub.fiveHour?.usedPercent, 27);
      expect(sub.sevenDay?.usedPercent, 48);
    });

    test('gateway accounts use the spend limit', () {
      final snapshot = aggregate([
        payload(
          spend: limit(40, 5),
          spendUsed: 20,
          spendLimit: 50,
          fiveHour: limit(10, 1),
        ),
      ], now);
      expect(snapshot, isA<GatewayUsage>());
      expect((snapshot as GatewayUsage).limitUsd, 50);
    });

    test('API accounts sum spend since midnight per session', () {
      final snapshot = aggregate([
        payload(id: 'a', day: '2026-11-13', cost: 4.6, dayBase: 4, context: 12),
        payload(id: 'b', day: '2026-11-13', cost: 1),
        payload(id: 'c', day: '2026-11-12', cost: 9),
      ], now);
      expect(snapshot, isA<ApiUsage>());
      expect((snapshot as ApiUsage).todayCostUsd, closeTo(1.6, 1e-9));
    });
  });

  group('AlertPolicy', () {
    test('fires once per threshold and re-arms after a drop', () {
      final policy = AlertPolicy();
      final fired = <double>[];
      for (final pct in <double>[50, 81, 85, 96, 10, 90]) {
        final alert = policy.check('5-hour', pct);
        if (alert != null) fired.add(alert.threshold);
      }
      expect(fired, [80, 95, 80]);
    });

    test('evaluates every limit of a snapshot and words the alert', () {
      final policy = AlertPolicy();
      final snapshot = SubscriptionUsage(
        fiveHour: RateLimit(
          usedPercent: 96,
          resetsAt: now.add(const Duration(hours: 1)),
        ),
        sevenDay: RateLimit(
          usedPercent: 82,
          resetsAt: now.add(const Duration(days: 1)),
        ),
      );
      final alerts = policy.evaluate(snapshot, now);
      expect(alerts.map((a) => a.limitName), ['5-hour', '7-day']);
      expect(alerts.first.title, 'Claude usage: 5-hour at 96%');
      expect(alerts.first.message, 'Almost at your limit.');
      expect(alerts.last.message, 'You have used over 80%.');
      // Nothing new on the same data.
      expect(policy.evaluate(snapshot, now), isEmpty);
    });

    test('a window that has reset does not alert', () {
      final expired = SubscriptionUsage(
        fiveHour: RateLimit(
          usedPercent: 99,
          resetsAt: now.subtract(const Duration(minutes: 1)),
        ),
      );
      expect(AlertPolicy().evaluate(expired, now), isEmpty);
      expect(AlertPolicy().evaluate(const NoUsage(), now), isEmpty);
    });

    test('tracks each limit separately', () {
      final policy = AlertPolicy();
      expect(policy.check('5-hour', 85), isNotNull);
      expect(policy.check('7-day', 85), isNotNull);
    });
  });
}
