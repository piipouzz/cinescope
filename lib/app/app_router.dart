import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import 'catalogue_shell.dart';
import '../pages/cinema_list_page.dart';
import '../pages/cinema_detail_page.dart';
import '../models/movie.dart';
import '../pages/movie_detail_page.dart';
import '../pages/not_found_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            CatalogueShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cinemas',
                builder: (context, state) => const CinemaListPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/cinemas/:type/:id',
        builder: (context, state) => CinemaDetailRoute(
          key: state.pageKey,
          cinemaId:
              '${state.pathParameters['type']}/${state.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/movie/:id',
        name: 'movie-detail',
        builder: (context, state) {
          final movie = state.extra;
          return MovieDetailPage(movie: movie is Movie ? movie : null);
        },
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}
