import 'dart:io'; // Import nécessaire pour vérifier la plateforme
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/api_client.dart';
import 'features/auth/auth_provider.dart';

// 1. Canal de notification pour Android (doit matcher ton firebase.js backend)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'edunotify_default', // ID identique au backend
  'Alertes SmartCampus', // Nom visible dans les réglages du téléphone
  description: 'Notifications importantes (Appel, Notes, Rapports)',
  importance: Importance.max,
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Gestionnaire des notifications en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // On initialise Firebase pour pouvoir traiter les données en arrière-plan si besoin
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialiser Firebase (S'adapte à la plateforme)
    await Firebase.initializeApp();

    // Configuration spécifique aux plateformes mobiles (Android / iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Créer le canal sur l'appareil (Spécifique Android)
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Demander les permissions Android 13+ et iOS
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialisation des notifications locales pour le mode "App ouverte"
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // 4. Écouter les notifications quand l'app est ouverte (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
        }
      });
    }
  } catch (e) {
    debugPrint("Erreur d'initialisation Firebase : $e");
    // L'application continuera de tourner même si Firebase échoue (ex: sur Windows)
  }

  runApp(
    const ProviderScope(
      child: SmartCampusApp(),
    ),
  );
}

class SmartCampusApp extends ConsumerWidget {
  const SmartCampusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // routerProvider doit être défini dans ton fichier core/router.dart
    final router = ref.watch(routerProvider);

    // Déconnexion forcée quand un établissement est bloqué
    ApiClient.setForceLogoutCallback(() {
      ref.read(authProvider.notifier).logoutSilencieux();
    });

    return MaterialApp.router(
      title: 'SmartCampus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // ── C'était ça qui manquait : sans themeMode, Flutter utilise
      // ThemeMode.system par défaut et ignore complètement le toggle
      // du profil (themeModeProvider). ──
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}