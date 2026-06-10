import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider langue ───────────────────────────────────────────────
final localeProvider = StateProvider<AppLocale>((_) => AppLocale.fr);

enum AppLocale { fr, en }

// ── Toutes les chaînes ────────────────────────────────────────────
class Strings {
  final AppLocale locale;
  const Strings(this.locale);

  bool get isFr => locale == AppLocale.fr;

  // Auth
  String get appTagline       => isFr ? 'Connecte-toi à ton espace'         : 'Sign in to your account';
  String get email            => isFr ? 'Email'                              : 'Email';
  String get password         => isFr ? 'Mot de passe'                       : 'Password';
  String get login            => isFr ? 'Se connecter'                       : 'Sign in';
  String get loggingIn        => isFr ? 'Connexion...'                       : 'Signing in...';
  String get loginError       => isFr ? 'Email ou mot de passe incorrect'    : 'Invalid email or password';
  String get noAccount        => isFr ? 'Pas encore de compte ? '            : 'No account yet? ';
  String get createAccount    => isFr ? 'Créer un compte'                    : 'Create account';

  // Nav
  String get home             => isFr ? 'Accueil'        : 'Home';
  String get notifs           => isFr ? 'Notifs'         : 'Notifs';
  String get presence         => isFr ? 'Présence'       : 'Attendance';
  String get attendance       => isFr ? 'Appel'          : 'Roll call';
  String get history          => isFr ? 'Historique'     : 'History';
  String get notes            => isFr ? 'Notes'          : 'Grades';
  String get classes          => isFr ? 'Classes'        : 'Classes';
  String get users            => isFr ? 'Utilisateurs'   : 'Users';
  String get reports          => isFr ? 'Rapports'       : 'Reports';
  String get schools          => isFr ? 'Établissements' : 'Schools';
  String get stats            => isFr ? 'Stats'          : 'Stats';
  String get profile          => isFr ? 'Profil'         : 'Profile';

  // Dashboard salutation
  String get goodMorning      => isFr ? 'Bonjour,'        : 'Good morning,';
  String get goodAfternoon    => isFr ? 'Bon après-midi,' : 'Good afternoon,';
  String get goodEvening      => isFr ? 'Bonsoir,'        : 'Good evening,';

  // Rôles
  String get roleSuperAdmin   => isFr ? 'Super Administrateur' : 'Super Administrator';
  String get roleAdmin        => isFr ? 'Administrateur'       : 'Administrator';
  String get roleChef         => isFr ? 'Chef de Département'  : 'Department Head';
  String get roleDelegue      => isFr ? 'Délégué'              : 'Class Representative';
  String get roleEtudiant     => isFr ? 'Étudiant'             : 'Student';

  String roleLabel(String role) {
    switch (role) {
      case 'super_admin':      return roleSuperAdmin;
      case 'admin':            return roleAdmin;
      case 'chef_departement': return roleChef;
      case 'delegue':          return roleDelegue;
      case 'etudiant':         return roleEtudiant;
      default:                 return role;
    }
  }

  // Dashboard étudiant
  String get quickAccess      => isFr ? 'Accès rapide'           : 'Quick access';
  String get todayStatus      => isFr ? 'Statut du jour'         : 'Today\'s status';
  String get myAttendance     => isFr ? 'Ma présence'            : 'My attendance';
  String get confirmCode      => isFr ? 'Confirmer mon code'     : 'Confirm my code';
  String get myGrades         => isFr ? 'Mes notes'              : 'My grades';
  String get viewBulletin     => isFr ? 'Voir mon bulletin'      : 'View report card';
  String get timetable        => isFr ? 'Emploi du temps'        : 'Timetable';
  String get currentWeek      => isFr ? 'Semaine en cours'       : 'Current week';
  String get notifications    => isFr ? 'Notifications'          : 'Notifications';
  String get myAlerts         => isFr ? 'Mes alertes'            : 'My alerts';
  String get attendanceToday  => isFr ? 'Présence aujourd\'hui'  : 'Attendance today';
  String get notConfirmed     => isFr ? 'Non confirmée'          : 'Not confirmed';
  String get unreadNotifs     => isFr ? 'Notifications non lues' : 'Unread notifications';

  // Dashboard délégué
  String get actions          => isFr ? 'Actions'              : 'Actions';
  String get startRollCall    => isFr ? 'Lancer un appel'      : 'Start roll call';
  String get generateCode     => isFr ? 'Générer un code'      : 'Generate code';
  String get pastSessions     => isFr ? 'Sessions passées'     : 'Past sessions';
  String get attendanceRate   => isFr ? 'Taux de présence'     : 'Attendance rate';
  String get notify           => isFr ? 'Notifier'             : 'Notify';
  String get sendMessage      => isFr ? 'Envoyer un message'   : 'Send message';

  // Présence étudiant
  String get enterCode        => isFr ? 'Saisis le code de présence'                          : 'Enter the attendance code';
  String get codeHint         => isFr ? 'Le délégué affiche le code en classe.\nTu as quelques minutes pour le saisir.' : 'The class rep shows the code in class.\nYou have a few minutes to enter it.';
  String get confirmAttendance => isFr ? 'Confirmer ma présence'   : 'Confirm attendance';
  String get confirming       => isFr ? 'Confirmation...'          : 'Confirming...';
  String get clear            => isFr ? 'Effacer'                  : 'Clear';
  String get codeExpiry       => isFr ? 'Le code est valable 5 minutes après sa génération.' : 'The code is valid for 5 minutes after generation.';
  String get attendanceConfirmed => isFr ? 'Présence confirmée !'  : 'Attendance confirmed!';
  String get confirmedAt      => isFr ? 'Ta présence a été enregistrée à' : 'Your attendance was recorded at';
  String get back             => isFr ? 'Retour'                   : 'Back';
  String get invalidCode      => isFr ? 'Code invalide ou session expirée' : 'Invalid code or session expired';

  // Présence délégué
  String get startSession     => isFr ? 'Lancer un appel'         : 'Start roll call';
  String get subject          => isFr ? 'Matière'                 : 'Subject';
  String get subjectHint      => isFr ? 'Ex: Mathématiques, Physique...' : 'E.g. Mathematics, Physics...';
  String get teacher          => isFr ? 'Professeur'              : 'Teacher';
  String get teacherHint      => isFr ? 'Nom du professeur'       : 'Teacher\'s name';
  String get room             => isFr ? 'Salle'                   : 'Room';
  String get roomHint         => isFr ? 'Ex: B12, Amphi A...'     : 'E.g. B12, Main Hall...';
  String get sessionType      => isFr ? 'Type de séance'          : 'Session type';
  String get validity         => isFr ? 'Durée de validité du code' : 'Code validity duration';
  String get studentTime      => isFr ? 'Les étudiants auront'    : 'Students will have';
  String get minutesToEnter   => isFr ? 'minutes pour saisir le code.' : 'minutes to enter the code.';
  String get launching        => isFr ? 'Génération...'           : 'Generating...';
  String get launch           => isFr ? 'Lancer l\'appel'         : 'Start roll call';
  String get fillAllFields    => isFr ? 'Remplis tous les champs obligatoires' : 'Fill in all required fields';
  String get sessionActive    => isFr ? 'Session en cours'        : 'Active session';
  String get presenceCode     => isFr ? 'Code de présence'        : 'Attendance code';
  String get expired          => isFr ? 'Expiré'                  : 'Expired';
  String get codeExpired      => isFr ? 'Code expiré'             : 'Code expired';
  String get remaining        => isFr ? 'restantes'               : 'remaining';
  String get confirmedCount   => isFr ? 'Présences confirmées'    : 'Confirmed attendance';
  String get closeSession     => isFr ? 'Fermer la session'       : 'Close session';
  String get sessionClosed    => isFr ? 'Session terminée'        : 'Session closed';
  String get viewReport       => isFr ? 'Voir le rapport'         : 'View report';
  String get newRollCall      => isFr ? 'Nouvel appel'            : 'New roll call';

  // Historique
  String get rollCallHistory  => isFr ? 'Historique des appels'   : 'Roll call history';
  String get noArchive        => isFr ? 'Aucune session archivée' : 'No archived sessions';
  String get today            => isFr ? 'Aujourd\'hui'            : 'Today';
  String get yesterday        => isFr ? 'Hier'                    : 'Yesterday';
  String get present          => isFr ? 'présent(s)'              : 'present';
  String get absent           => isFr ? 'absent(s)'               : 'absent';

  // Détail session
  String get presentsTab      => isFr ? 'Présents'   : 'Present';
  String get absentsTab       => isFr ? 'Absents'    : 'Absent';
  String get rate             => isFr ? 'Taux'       : 'Rate';
  String get duration         => isFr ? 'Durée'      : 'Duration';
  String get nonePresent      => isFr ? 'Aucun présent' : 'Nobody present';
  String get noneAbsent       => isFr ? 'Aucun absent'  : 'Nobody absent';

  // Notifications
  String get noNotifications  => isFr ? 'Aucune notification'  : 'No notifications';
  String get all              => isFr ? 'Tous'      : 'All';
  String get exams            => isFr ? 'Examens'   : 'Exams';
  String get results          => isFr ? 'Résultats' : 'Results';
  String get course           => isFr ? 'Cours'     : 'Course';
  String get admin            => isFr ? 'Admin'     : 'Admin';
  String get urgent           => isFr ? 'Urgent'    : 'Urgent';
  String get minutesAgo       => isFr ? 'Il y a'    : '';
  String get min              => isFr ? 'min'       : 'min ago';
  String get hoursAgo         => isFr ? 'Il y a'    : '';
  String get h                => isFr ? 'h'         : 'h ago';
  String get daysAgo          => isFr ? 'Il y a'    : '';
  String get j                => isFr ? 'j'         : 'd ago';

  String timeAgo(Duration diff) {
    if (diff.inMinutes < 60) {
      return isFr
          ? 'Il y a ${diff.inMinutes} min'
          : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return isFr ? 'Il y a ${diff.inHours}h' : '${diff.inHours}h ago';
    }
    return isFr ? 'Il y a ${diff.inDays}j' : '${diff.inDays}d ago';
  }

  // Profil
  String get myProfile        => isFr ? 'Mon profil'              : 'My profile';
  String get information      => isFr ? 'Informations'            : 'Information';
  String get emailLabel       => isFr ? 'Email'                   : 'Email';
  String get idLabel          => isFr ? 'Identifiant'             : 'ID';
  String get statusLabel      => isFr ? 'Statut'                  : 'Status';
  String get active           => isFr ? 'Actif'                   : 'Active';
  String get inactive         => isFr ? 'Inactif'                 : 'Inactive';
  String get settings         => isFr ? 'Paramètres'              : 'Settings';
  String get changePassword   => isFr ? 'Changer le mot de passe' : 'Change password';
  String get notifPrefs       => isFr ? 'Préférences notifications' : 'Notification preferences';
  String get session          => isFr ? 'Session'                 : 'Session';
  String get logout           => isFr ? 'Se déconnecter'          : 'Sign out';
  String get logoutConfirm    => isFr ? 'Déconnexion'             : 'Sign out';
  String get logoutMessage    => isFr ? 'Tu vas être déconnecté de ton compte.' : 'You will be signed out of your account.';
  String get cancel           => isFr ? 'Annuler'                 : 'Cancel';
  String get disconnect       => isFr ? 'Déconnecter'             : 'Sign out';
  String get appearance       => isFr ? 'Apparence'               : 'Appearance';
  String get darkTheme        => isFr ? 'Thème sombre'            : 'Dark theme';
  String get lightTheme       => isFr ? 'Thème clair'             : 'Light theme';
  String get language         => isFr ? 'Langue'                  : 'Language';
  String get currentPassword  => isFr ? 'Mot de passe actuel'     : 'Current password';
  String get newPassword      => isFr ? 'Nouveau mot de passe'    : 'New password';
  String get confirmNewPwd    => isFr ? 'Confirmer le nouveau'    : 'Confirm new password';
  String get save             => isFr ? 'Enregistrer'             : 'Save';

  // Thème types
  String get typeExam         => isFr ? 'Cours'        : 'Course';
  String get typeTD           => isFr ? 'TD'           : 'Tutorial';
  String get typeTP           => isFr ? 'TP'           : 'Lab';
  String get typeExamen       => isFr ? 'Examen'       : 'Exam';
  String get typeRattrapage   => isFr ? 'Rattrapage'   : 'Resit';

  List<String> get sessionTypes => isFr
      ? ['Cours', 'TD', 'TP', 'Examen', 'Rattrapage']
      : ['Course', 'Tutorial', 'Lab', 'Exam', 'Resit'];
}

// Provider global
final stringsProvider = Provider<Strings>(
      (ref) => Strings(ref.watch(localeProvider)),
);