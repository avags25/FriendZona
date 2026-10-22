import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_repository.dart';
import 'screens.dart';
import 'friends.dart';
import 'map/map_page.dart';

class AuthRouterRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.changed());

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.asData?.value != null;
      final path = state.uri.path;
      final isAuthPage = path == '/' || path == '/login' || path == '/register';
      if (!signedIn && !isAuthPage) return '/login';
      if (signedIn && isAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/map', builder: (context, state) => const MapPage()),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: '/friends/add',
        builder: (context, state) => const AddFriendPage(),
      ),
      GoRoute(
        path: '/friends/requests',
        builder: (context, state) => const FriendRequestsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
