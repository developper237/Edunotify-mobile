/// Point de configuration unique des URLs de services.
///
/// Chaque URL est surchargeable au moment du build, sans toucher au code :
///
/// ```bash
/// flutter build apk \
///   --dart-define=AUTH_URL=https://auth-service.up.railway.app \
///   --dart-define=NOTIF_URL=https://notification-service.up.railway.app \
///   --dart-define=PRESENCE_URL=https://presence-service.up.railway.app \
///   --dart-define=ACADEMIC_URL=https://academic-service.up.railway.app \
///   --dart-define=CHATBOT_URL=https://chatbot-service.up.railway.app \
///   --dart-define=BILLING_URL=https://billing-service.up.railway.app
/// ```
///
/// Les valeurs par défaut sont le déploiement Render actuel : un build sans
/// `--dart-define` continue donc de fonctionner pendant la migration.
/// Un changement d'hébergeur ne demande plus de modifier le code source.
class EnvConfig {
  const EnvConfig._();

  /// auth-service : login, refresh, cascade, import CSV, profils.
  static const String auth = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: 'https://smartcampus-auth.onrender.com',
  );

  /// notification-service : notifications, sondages, flux SSE `/notifications/stream`.
  static const String notif = String.fromEnvironment(
    'NOTIF_URL',
    defaultValue: 'https://notification-service-1o8a.onrender.com',
  );

  /// presence-service : sessions OTP de présence.
  static const String presence = String.fromEnvironment(
    'PRESENCE_URL',
    defaultValue: 'https://presence-service-q9wq.onrender.com',
  );

  /// academic-service : notes, bulletins, emplois du temps.
  static const String academic = String.fromEnvironment(
    'ACADEMIC_URL',
    defaultValue: 'https://academic-service-f5sm.onrender.com',
  );

  /// chatbot-service : assistant Gemini.
  static const String chatbot = String.fromEnvironment(
    'CHATBOT_URL',
    defaultValue: 'https://chatbot-service-sh1b.onrender.com',
  );

  /// billing-service : abonnements, paiements Mobile Money, **et aussi** les
  /// routes `/library`, `/exam`, `/chat` ainsi que les fichiers `/uploads/...`
  /// (voir `services/billing-service/src/index.js`).
  static const String billing = String.fromEnvironment(
    'BILLING_URL',
    defaultValue: 'https://billing-service-efm6.onrender.com',
  );
}
