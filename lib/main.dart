import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/app_theme.dart';
import 'core/router.dart';
import 'core/api_client.dart'; // Au lieu de services/api_client.dart // Assure-toi que le chemin est correct

// Fonction pour gérer les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    print("Message reçu en arrière-plan : ${message.messageId}");
  } catch (e) {
    print("Erreur background Firebase : $e");
  }
}

void main() async {
  // 1. Assurer l'initialisation des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialiser Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("Firebase initialisé avec succès");
  } catch (e) {
    debugPrint("ERREUR INITIALISATION FIREBASE : $e");
  }

  // 3. VÉRIFICATION DE LA CONNEXION (C'est ici que la magie opère)
  // On vérifie si un token existe dans le stockage local
  final bool loggedIn = await ApiClient.isLoggedIn();

  // 4. Lancer l'application
  runApp(
    ProviderScope(
      overrides: [
        // Si tu as un provider qui gère l'état d'authentification,
        // tu peux l'initialiser ici. Sinon, le router s'en chargera.
      ],
      child: const EduNotifyApp(),
    ),
  );
}

class EduNotifyApp extends ConsumerWidget {
  const EduNotifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le routerProvider doit utiliser la logique de redirection
    // basée sur la présence du token (ApiClient.isLoggedIn)
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'EduNotify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}