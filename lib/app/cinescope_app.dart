import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'app_router.dart';

class CinescopeApp extends StatefulWidget {
  const CinescopeApp({super.key});

  @override
  State<CinescopeApp> createState() => _CinescopeAppState();
}

class _CinescopeAppState extends State<CinescopeApp> {
  final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Builder(
        builder: (context) => ShadApp.router(
          title: 'CinéScope',
          debugShowCheckedModeBanner: false,
          themeMode: context.watch<ThemeProvider>().themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: _router,
        ),
      ),
    );
  }
}
