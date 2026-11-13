import 'dart:io';

import 'package:claude_usage_widget/app.dart';
import 'package:claude_usage_widget/data/repositories/status_line_repository.dart';
import 'package:claude_usage_widget/data/repositories/usage_repository.dart';
import 'package:claude_usage_widget/data/services/autostart_service.dart';
import 'package:claude_usage_widget/data/services/claude_settings_service.dart';
import 'package:claude_usage_widget/data/services/notification_service.dart';
import 'package:claude_usage_widget/data/services/preferences_service.dart';
import 'package:claude_usage_widget/data/services/tray_service.dart';
import 'package:claude_usage_widget/data/services/usage_file_service.dart';
import 'package:claude_usage_widget/data/services/window_service.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/cubit/usage_widget_cubit.dart';
import 'package:claude_usage_widget/ui/features/usage_widget/widget_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_bridge/bridge.dart' show claudeConfigDir, recordsDir;

/// Wires the dependency graph and starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configDir = claudeConfigDir(Platform.environment);
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  final window = DesktopWindowService();
  await window.init(
    size: WidgetLayout.windowSizeFor(WidgetLayout.pill),
    position: preferences.windowPosition,
  );

  final bridgeName = Platform.isWindows ? 'usage_bridge.exe' : 'usage_bridge';
  final cubit = UsageWidgetCubit(
    usage: UsageRepository(
      files: UsageFileService(directory: recordsDir(configDir)),
    ),
    statusLine: StatusLineRepository(
      settings: ClaudeSettingsService(configDir: configDir),
      bridgePath: p.join(p.dirname(Platform.resolvedExecutable), bridgeName),
    ),
    autostart: AutostartService.forPlatform(),
    preferences: preferences,
    window: window,
    tray: SystemTrayService(),
    notifications: NotificationService.forPlatform(),
  );
  runApp(UsageWidgetApp(cubit: cubit));
  await cubit.start();
}
