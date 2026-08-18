import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/storage.dart';
import 'auth_state.dart';
import '../presence/presence_screen.dart';
import '../classes/classes_chef_screen.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final hasToken = await Storage.hasSession();
    final json     = await Storage.getUserJson();
    if (hasToken && json != null) {
      final user = User.fromJson(jsonDecode(json));
      state = AuthState(user: user, isAuthenticated: true);
      // Enregistrer le token FCM au démarrage (fire-and-forget)
      _enregistrerFcmToken();
    } else {
      state = const AuthState();
    }
  }

  // ── Récupère et envoie le token FCM au backend ─────────────────
  Future<void> _enregistrerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final user = state.user;
      if (user == null) return;

      // Envoyer au backend
      await ApiClient.patch('/auth/fcm-token', data: {'fcmToken': token});

      // Mettre à jour le state et le storage local
      final userMisAJour = user.copyWith(fcmToken: token);
      await Storage.saveUserJson(jsonEncode(userMisAJour.toJson()));
      state = state.copyWith(user: userMisAJour);

      // Écouter les renouvellements automatiques du token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient.patch('/auth/fcm-token', data: {'fcmToken': newToken});
          final u = state.user;
          if (u == null) return;
          final updated = u.copyWith(fcmToken: newToken);
          await Storage.saveUserJson(jsonEncode(updated.toJson()));
          state = state.copyWith(user: updated);
        } catch (_) {}
      });
    } catch (_) {
      // Silencieux — FCM non disponible sur Desktop/Windows
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await ApiClient.post('/auth/login', data: {
        'email':    email,
        'password': password,
      });
      final payload = resp.containsKey('data')
          ? resp['data'] as Map<String, dynamic>
          : resp;
      final user = User.fromJson(payload['user'] as Map<String, dynamic>);
      await Storage.saveTokens(
        accessToken:  payload['accessToken'],
        refreshToken: payload['refreshToken'] ?? '',
      );
      await Storage.saveUserJson(jsonEncode(user.toJson()));

      // Réinitialise TOUS les caches
      _ref.invalidate(sessionStatusProvider);
      _ref.invalidate(sessionDataProvider);
      _ref.invalidate(presenceStatusProvider);
      _ref.invalidate(presenceErrorProvider);
      _ref.invalidate(historiqueEtudiantProvider);
      _ref.invalidate(classesChefProvider);
      _ref.invalidate(dernierSessionIdProvider);

      state = AuthState(user: user, isAuthenticated: true);

      // Enregistrer le token FCM après login (fire-and-forget)
      _enregistrerFcmToken();

    } on ApiException catch (e) {
      String message = e.message;
      final code = e.body?['code'] as String?;
      if (code == 'COMPTE_SUSPENDU') {
        message = 'Votre compte est suspendu. Contactez votre administrateur.';
      } else if (code == 'ETABLISSEMENT_SUSPENDU') {
        message = 'Votre établissement est suspendu. Contactez le support SmartCampus.';
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion');
    }
  }

  /// Appelé depuis ForceChangePasswordScreen après changement réussi.
  Future<void> activerCompte({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.post(
        '/auth/change-password',
        data: {
          'ancienMotDePasse':  ancienMotDePasse,
          'nouveauMotDePasse': nouveauMotDePasse,
        },
      );
      final userActif = state.user!.copyWith(statut: 'actif');
      await Storage.saveUserJson(jsonEncode(userActif.toJson()));
      state = AuthState(user: userActif, isAuthenticated: true);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion');
      rethrow;
    }
  }

  /// Upload du logo de l'établissement (admin uniquement).
  Future<void> uploaderLogoEtablissement({
    required List<int> fileBytes,
    required String filename,
  }) async {
    final resp = await ApiClient.uploadLogoEtablissement(
      fileBytes: fileBytes,
      filename:  filename,
    );
    final payload = resp.containsKey('data')
        ? resp['data'] as Map<String, dynamic>
        : resp;
    final nouvelleUrl = payload['logoUrl'] as String?;
    if (nouvelleUrl == null || state.user == null) return;
    final userMisAJour = state.user!.copyWith(etablissementLogo: nouvelleUrl);
    await Storage.saveUserJson(jsonEncode(userMisAJour.toJson()));
    state = state.copyWith(user: userMisAJour);
  }

  Future<void> logout() async {
    try { await ApiClient.post('/auth/logout'); } catch (_) {}
    await Storage.clear();
    _ref.invalidate(sessionStatusProvider);
    _ref.invalidate(sessionDataProvider);
    _ref.invalidate(presenceStatusProvider);
    _ref.invalidate(presenceErrorProvider);
    _ref.invalidate(historiqueEtudiantProvider);
    _ref.invalidate(classesChefProvider);
    _ref.invalidate(dernierSessionIdProvider);
    state = const AuthState();
  }

  /// Déconnexion silencieuse sans appel API.
  Future<void> logoutSilencieux() async {
    await Storage.clear();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);

  /// Changement de mot de passe depuis les paramètres (compte déjà actif)
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await ApiClient.post(
        '/auth/change-password',
        data: {
          'ancienMotDePasse':  oldPassword,
          'nouveauMotDePasse': newPassword,
        },
      );
    } on ApiException {
      rethrow;
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
      (ref) => AuthNotifier(ref),
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});