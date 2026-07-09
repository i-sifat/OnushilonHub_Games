import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/font_size_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // DB init intentionally removed from here — SplashScreen awaits it so the
  // UI is visible (with a progress indicator) while the first-install seed runs.

  // F-03: initialise notification service and re-schedule any saved reminder.
  await NotificationService.instance.initialize();

  runApp(const ProviderScope(child: OnushilonHubApp()));
}

class OnushilonHubApp extends ConsumerWidget {
  const OnushilonHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme + font size are both stored preferences; watching them rebuilds
    // MaterialApp.router so the entire widget tree reflows from the single
    // ThemeData source of truth.
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);

    // Router is read (not watched) because appRouterProvider is keepAlive and
    // immutable — watching it would recreate the GoRouter on every rebuild.
    final router = ref.read(appRouterProvider);

    return MaterialApp.router(
      title: 'OnushilonHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontSize: fontSize),
      darkTheme: AppTheme.dark(fontSize: fontSize),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
