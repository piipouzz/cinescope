import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/not_found_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const HomePage()),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}
