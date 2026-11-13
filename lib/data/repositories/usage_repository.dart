import 'package:claude_usage_widget/data/services/usage_file_service.dart';
import 'package:claude_usage_widget/domain/models/usage_snapshot.dart';
import 'package:claude_usage_widget/domain/use_cases/aggregate_usage.dart';

/// Single source of truth for current usage.
class UsageRepository {
  /// Creates a repository over [_files]; [_clock] is injectable for tests.
  UsageRepository({
    required this._files,
    this._aggregate = const AggregateUsage(),
    this._clock = DateTime.now,
  });

  final UsageFileService _files;
  final AggregateUsage _aggregate;
  final DateTime Function() _clock;

  /// Current usage now, then again after every change.
  Stream<UsageSnapshot> watch() async* {
    yield await _load();
    await for (final _ in _files.changes()) {
      yield await _load();
    }
  }

  Future<UsageSnapshot> _load() async =>
      _aggregate(await _files.readAll(), _clock());
}
