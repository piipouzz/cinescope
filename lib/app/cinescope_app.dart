import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'app_router.dart';

class CinescopeApp extends ConsumerStatefulWidget {
  const CinescopeApp({super.key});

  @override
  ConsumerState<CinescopeApp> createState() => _CinescopeAppState();
}

class _CinescopeAppState extends ConsumerState<CinescopeApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp.router(
      title: 'CinéScope',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeProvider),
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
