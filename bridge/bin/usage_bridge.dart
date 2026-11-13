import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:usage_bridge/bridge.dart';

/// Claude Code status line command.
///
/// Reads the payload from stdin, records it for the widget and prints a short
/// status line. Optional arguments are a previous status line command whose
/// output is passed through instead.
Future<void> main(List<String> args) async {
  try {
    final raw = await utf8.decodeStream(stdin);
    final data = jsonDecode(raw);
    if (data is Map<String, Object?>) {
      writeRecord(
        claudeConfigDir(Platform.environment),
        data,
        DateTime.now(),
      );
      final passthrough = args.isEmpty ? null : await _runPrevious(args, raw);
      stdout.write(passthrough ?? summary(data));
    }
  } on FormatException {
    // Not JSON: print nothing rather than break the status line.
  } on FileSystemException catch (e) {
    stderr.writeln('usage_bridge: $e');
  }
  // The status line must never fail, whatever happened above.
  exit(0);
}

Future<String?> _runPrevious(List<String> command, String input) async {
  try {
    final process = await Process.start(
      command.first,
      command.sublist(1),
      runInShell: true,
    );
    process.stdin.write(input);
    await process.stdin.close();
    return await utf8
        .decodeStream(process.stdout)
        .timeout(const Duration(seconds: 3));
  } on ProcessException {
    return null;
  } on TimeoutException {
    return null;
  }
}
