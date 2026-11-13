import 'dart:io';

/// Runs an external program. Injected so services that shell out can be
/// tested without starting real processes.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
});

/// The real [ProcessRunner].
Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.run(executable, arguments, environment: environment);
