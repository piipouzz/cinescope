import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../models/movie.dart';
import '../pages/movie_detail_page.dart';
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
