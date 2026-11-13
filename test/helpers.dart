import 'package:claude_usage_widget/data/models/status_payload.dart';
import 'package:claude_usage_widget/domain/models/rate_limit.dart';

/// Builds a payload for tests with sensible defaults.
StatusPayload payload({
  String id = 's1',
  DateTime? writtenAt,
  String? day,
  double dayBase = 0,
  RateLimit? fiveHour,
  RateLimit? sevenDay,
  RateLimit? spend,
  double? spendUsed,
  double? spendLimit,
  double? cost,
  double? context,
}) => StatusPayload(
  sessionId: id,
  writtenAt: writtenAt ?? DateTime(2026, 11, 13, 12),
  day: day,
  dayBaseCostUsd: dayBase,
  fiveHour: fiveHour,
  sevenDay: sevenDay,
  spendLimit: spend,
  spendUsedUsd: spendUsed,
  spendLimitUsd: spendLimit,
  totalCostUsd: cost,
  contextUsedPercent: context,
);
