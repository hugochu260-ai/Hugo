import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'services/settings_store.dart';

class FypApp extends StatelessWidget {
  const FypApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    return MaterialApp(
      title: '智行友伴',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(light: true),
      darkTheme: buildAppTheme(light: false),
      themeMode: settings.lightMode ? ThemeMode.light : ThemeMode.dark,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
