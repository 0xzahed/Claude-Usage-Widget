import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:claude_usage_widget/config/app_constants.dart';
import 'package:claude_usage_widget/config/logger.dart';
import 'package:claude_usage_widget/data/models/session_record_mapper.dart';
import 'package:claude_usage_widget/domain/models/session_record.dart';
import 'package:path/path.dart' as p;

/// Reads and watches the records folder written by the status line bridge.
class UsageFileService {
  /// Creates a service for [directory], polling every [pollInterval] as a
  /// fallback for platforms where file watching is unreliable.
  UsageFileService({
    required this.directory,
    this.pollInterval = AppConstants.pollInterval,
  });

  /// The records folder.
  final String directory;

  /// Fallback poll period.
  final Duration pollInterval;

  /// Reads every readable record; unreadable files are skipped and logged.
  Future<List<SessionRecord>> readAll() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    final payloads = <SessionRecord>[];
    await for (final entity in dir.list()) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      try {
        final payload = SessionRecordMapper.fromJson(
          jsonDecode(await entity.readAsString()),
        );
        if (payload != null) payloads.add(payload);
      } on FormatException catch (e) {
        logWarning('Skipping malformed record ${entity.path}', e);
      } on FileSystemException catch (e) {
        // Usually the bridge replacing the file mid-read; the next tick works.
        logWarning('Could not read ${entity.path}', e);
      }
    }
    return payloads;
  }

  /// Emits whenever the folder may have changed: on file events and on a timer.
  Stream<void> changes() {
    Timer? timer;
    StreamSubscription<FileSystemEvent>? watch;
    // Single-subscription controllers close themselves when cancelled.
    // ignore: close_sinks
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        timer = Timer.periodic(pollInterval, (_) => controller.add(null));
        try {
          Directory(directory).createSync(recursive: true);
          watch = Directory(directory).watch().listen(
            (_) => controller.add(null),
            onError: (Object e) => logWarning('File watch failed', e),
          );
        } on FileSystemException catch (e) {
          logWarning('Watching $directory unavailable, polling only', e);
        }
      },
      onCancel: () async {
        timer?.cancel();
        await watch?.cancel();
      },
    );
    return controller.stream;
  }
}
