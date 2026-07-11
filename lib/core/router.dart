import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/force_change_password_screen.dart';
import '../features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Attendre que _init() soit terminé
      if (authState.isLoading) return null;

      final isAuth         = authState.isAuthenticated;
      final isLoggingIn    = state.matchedLocation == '/login';
      final isChangingPass = state.matchedLocation == '/force-change-password';
      final statut         = authState.user?.statut;

      // ── Pas connecté → login ─────────────────────────────────
      if (!isAuth) return isLoggingIn ? null : '/login';

      // ── Compte ou établissement suspendu → déconnexion forcée
      // On vide la session et on renvoie vers le login avec message
      if (statut == 'suspendu') {
        // Déconnexion silencieuse (sans appel API)
        Future.microtask(() =>
            ref.read(authProvider.notifier).logoutSilencieux());
        return '/login';
      }

      // ── Premier login → écran changement de mot de passe obligatoire
      // Bloque TOUTES les autres routes
      if (authState.doitChangerMotDePasse) {
        return isChangingPass ? null : '/force-change-password';
      }

      // ── Connecté + actif sur login ou force-change → home ───
      if (isLoggingIn || isChangingPass) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/force-change-password',
        builder: (context, state) => const ForceChangePasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(
      authProvider,
          (previous, next) {
        if (previous?.isLoading       != next.isLoading       ||
            previous?.isAuthenticated != next.isAuthenticated  ||
            previous?.user?.statut    != next.user?.statut) {
          notifyListeners();
        }
      },
    );
  }
}