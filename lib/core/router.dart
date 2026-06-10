import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Le notifier permet au router de réagir dès que l'état d'auth change
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      // 1. On récupère l'état complet de l'authentification
      final authState = ref.read(authProvider);

      // 2. TANT QUE l'application vérifie si un token existe (isLoading est vrai),
      // on ne fait aucune redirection. On attend que _init() dans AuthNotifier soit fini.
      if (authState.isLoading) {
        return null;
      }

      // 3. Une fois le chargement fini, on vérifie si l'utilisateur est authentifié
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      // 4. Si l'utilisateur n'est pas connecté et qu'il n'est pas sur la page login
      if (!isAuth) {
        // On le force à aller sur /login, sauf s'il y est déjà
        return isLoggingIn ? null : '/login';
      }

      // 5. Si l'utilisateur est connecté et qu'il essaie d'aller sur /login
      if (isAuth && isLoggingIn) {
        // On le redirige vers l'accueil (Comme sur Facebook)
        return '/home';
      }

      // Sinon, on le laisse aller sur la page demandée
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

/// Classe utilitaire pour notifier GoRouter quand le StateNotifier change
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    // On écoute les changements de authProvider
    ref.listen<AuthState>(
      authProvider,
          (previous, next) {
        // Si on passe de isLoading: true à isLoading: false,
        // ou si isAuthenticated change, on prévient GoRouter.
        if (previous?.isLoading != next.isLoading ||
            previous?.isAuthenticated != next.isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }
}