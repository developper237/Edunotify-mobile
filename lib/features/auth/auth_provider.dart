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

  AuthNotifier(this._ref) : super(const AuthState(isLoading: true)) {
    _init();
  }

  /// Initialisation : Vérifie si une session existe au démarrage de l'app
  Future<void> _init() async {
    try {
      final hasToken = await Storage.hasSession();
      final json = await Storage.getUserJson();

      if (hasToken && json != null) {
        final user = User.fromJson(jsonDecode(json));
        // On restaure l'utilisateur et on coupe le chargement
        state = AuthState(user: user, isAuthenticated: true, isLoading: false);

        // On rafraîchit le token de notification en arrière-plan
        _enregistrerFcmToken();
      } else {
        // Pas de session trouvée
        state = const AuthState(isAuthenticated: false, isLoading: false);
      }
    } catch (e) {
      state = const AuthState(isAuthenticated: false, isLoading: false, error: null);
    }
  }

  /// Enregistre le token Firebase Cloud Messaging sur le serveur
  Future<void> _enregistrerFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await ApiClient.patch('/auth/fcm-token', data: {'fcmToken': fcmToken});
    } catch (e) {
      // Échec silencieux pour ne pas bloquer l'utilisateur
      print("Erreur enregistrement FCM: $e");
    }
  }

  /// Procédure de connexion
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

      // Sauvegarde persistante (SharedPrefs)
      await Storage.saveTokens(
        accessToken:  payload['accessToken'],
        refreshToken: payload['refreshToken'] ?? '',
      );
      await Storage.saveUserJson(jsonEncode(user.toJson()));

      // Nettoyer tous les états des autres services
      _resetAllProviders();

      // Mise à jour de l'état global
      state = AuthState(user: user, isAuthenticated: true, isLoading: false);

      // Enregistrement des notifications
      _enregistrerFcmToken();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion au serveur');
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await ApiClient.post('/auth/logout');
    } catch (_) {
      // On continue le logout local même si le serveur ne répond pas
    }

    await Storage.clear();
    _resetAllProviders();

    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  /// Supprime l'erreur actuelle de l'état
  void clearError() => state = state.copyWith(error: null);

  /// Helper pour réinitialiser les données de l'application
  void _resetAllProviders() {
    _ref.invalidate(sessionStatusProvider);
    _ref.invalidate(sessionDataProvider);
    _ref.invalidate(presenceStatusProvider);
    _ref.invalidate(presenceErrorProvider);
    _ref.invalidate(historiqueEtudiantProvider);
    _ref.invalidate(classesChefProvider);
  }

  /// Changement de mot de passe
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await ApiClient.post(
        '/auth/change-password',
        data: {
          'ancienMotDePasse': oldPassword,
          'nouveauMotDePasse': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}

// --- PROVIDERS ---

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
      (ref) => AuthNotifier(ref),
);

final currentUserProvider = Provider<User?>(
      (ref) => ref.watch(authProvider).user,
);

final isAuthProvider = Provider<bool>(
      (ref) => ref.watch(authProvider).isAuthenticated,
);