import 'package:claude_usage_widget/domain/models/rate_limit.dart';
import 'package:claude_usage_widget/domain/models/session_record.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:usage_bridge/bridge.dart' show dayKey, keepDays;

/// Turns the records of all Claude Code sessions into one [UsageSnapshot].
///
/// Every open session reports the account's limits but may hold an older
/// snapshot, and idle sessions keep rewriting theirs, so file recency is not
/// data freshness. Within one window usage only grows, so the latest window
/// and the highest percent seen for it win.
final class AggregateUsage {
  /// Creates the use case.
  const AggregateUsage();

  /// Aggregates [payloads] as of [now].
  UsageSnapshot call(List<SessionRecord> payloads, DateTime now) {
    final cutoff = now.subtract(const Duration(days: keepDays));
    final fresh = payloads.where((p) => p.writtenAt.isAfter(cutoff)).toList();
    if (fresh.isEmpty) return const NoUsage();

    final newest = fresh.reduce(
      (a, b) => b.writtenAt.isAfter(a.writtenAt) ? b : a,
    );
    final updatedAt = newest.writtenAt;

    final gateway = fresh.where((p) => p.spendLimit != null);
    if (gateway.isNotEmpty) {
      final source = gateway.reduce(
        (a, b) => b.writtenAt.isAfter(a.writtenAt) ? b : a,
      );
      return GatewayUsage(
        spend: source.spendLimit!,
        usedUsd: source.spendUsedUsd,
        limitUsd: source.spendLimitUsd,
        updatedAt: updatedAt,
      );
    }

    final five = _bestWindow(fresh.map((p) => p.fiveHour));
    final seven = _bestWindow(fresh.map((p) => p.sevenDay));
    if (five != null || seven != null) {
      return SubscriptionUsage(
        fiveHour: five,
        sevenDay: seven,
        updatedAt: updatedAt,
      );
    }

    if (newest.totalCostUsd != null) {
      final today = dayKey(now);
      final todayCost = fresh
          .where((p) => (p.day ?? dayKey(p.writtenAt)) == today)
          .fold<double>(0, (sum, p) => sum + p.todayCostUsd);
      return ApiUsage(
        sessionCostUsd: newest.totalCostUsd!,
        todayCostUsd: todayCost,
        contextPercent: newest.contextUsedPercent,
        updatedAt: updatedAt,
      );
    }
    return const NoUsage();
  }

  RateLimit? _bestWindow(Iterable<RateLimit?> windows) {
    RateLimit? best;
    for (final window in windows.whereType<RateLimit>()) {
      if (best == null || _isBetter(window, best)) best = window;
    }
    return best;
  }

  bool _isBetter(RateLimit candidate, RateLimit current) {
    final a = candidate.resetsAt?.millisecondsSinceEpoch ?? 0;
    final b = current.resetsAt?.millisecondsSinceEpoch ?? 0;
    return a > b || (a == b && candidate.usedPercent > current.usedPercent);
  }
}
