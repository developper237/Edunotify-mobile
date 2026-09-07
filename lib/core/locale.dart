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
  String get roleProfesseur   => isFr ? 'Professeur'           : 'Professor';
  String get roleDelegue      => isFr ? 'Délégué'              : 'Class Representative';
  String get roleEtudiant     => isFr ? 'Étudiant'             : 'Student';

  String roleLabel(String role) {
    switch (role) {
      case 'super_admin':      return roleSuperAdmin;
      case 'admin':            return roleAdmin;
      case 'chef_departement': return roleChef;
      case 'professeur':       return roleProfesseur;
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
  String get close            => isFr ? 'Fermer'                  : 'Close';
  String get delete           => isFr ? 'Supprimer'               : 'Delete';
  String get confirm          => isFr ? 'Confirmer'               : 'Confirm';
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

  // ── Chat / Messages ──
  String get messages         => isFr ? 'Messages'            : 'Messages';
  String get newMessage       => isFr ? 'Nouveau message'     : 'New message';
  String get typeMessage      => isFr ? 'Tapez un message...' : 'Type a message...';
  String get send             => isFr ? 'Envoyer'             : 'Send';
  String get noMessages       => isFr ? 'Aucun message'       : 'No messages';
  String get groupChat        => isFr ? 'Chat de groupe'      : 'Group chat';
  String get privateChat      => isFr ? 'Chat privé'          : 'Private chat';
  String get joinGroup        => isFr ? 'Rejoindre un groupe' : 'Join a group';
  String get createGroup      => isFr ? 'Créer un groupe'     : 'Create a group';
  String get groupName        => isFr ? 'Nom du groupe'       : 'Group name';
  String get invitationCode   => isFr ? 'Code d\'invitation'  : 'Invitation code';
  String get copyCode         => isFr ? 'Copier le code'      : 'Copy code';
  String get codeCopied       => isFr ? 'Code copié !'        : 'Code copied!';
  String get members          => isFr ? 'Membres'             : 'Members';
  String get member           => isFr ? 'Membre'              : 'Member';
  String get online           => isFr ? 'En ligne'            : 'Online';
  String get noConversations  => isFr ? 'Aucune conversation' : 'No conversations';
  String get searchUsers      => isFr ? 'Rechercher un utilisateur' : 'Search for a user';
  String get newConversation  => isFr ? 'Nouvelle conversation': 'New conversation';
  String get deleteMessage    => isFr ? 'Supprimer le message': 'Delete message';
  String get deleteConversation => isFr ? 'Supprimer la conversation' : 'Delete conversation';
  String get attachment       => isFr ? 'Pièce jointe'        : 'Attachment';
  String get audioMessage     => isFr ? 'Message vocal'       : 'Audio message';

  // ── Notes / Requêtes ──
  String get myResults        => isFr ? 'Mes résultats'       : 'My results';
  String get myRequests       => isFr ? 'Mes requêtes'        : 'My requests';
  String get publishGrades    => isFr ? 'Publier des notes'   : 'Publish grades';
  String get noResultsPublished => isFr ? 'Aucun résultat publié' : 'No results published';
  String get resultsWillAppear => isFr ? 'Vos résultats apparaîtront ici\ndès que le chef de département les publiera.' : 'Your results will appear here\nonce the department head publishes them.';
  String get submitRequest    => isFr ? 'Soumettre une requête': 'Submit a request';
  String get describeProblem  => isFr ? 'Décrivez le problème': 'Describe the problem';
  String get attachDocument   => isFr ? 'Joindre un document (PDF)' : 'Attach a document (PDF)';
  String get documentAttached => isFr ? 'Document joint'      : 'Document attached';
  String get sendRequest      => isFr ? 'Envoyer la requête'  : 'Send request';
  String get requestSubmitted => isFr ? 'Requête soumise avec succès' : 'Request submitted successfully';
  String get requestPending   => isFr ? 'En attente'          : 'Pending';
  String get requestProcessed => isFr ? 'Traitée'             : 'Processed';
  String get requestRejected  => isFr ? 'Rejetée'             : 'Rejected';
  String get noRequests       => isFr ? 'Aucune requête soumise' : 'No requests submitted';
  String get average          => isFr ? 'Moyenne'             : 'Average';
  String get passable         => isFr ? 'Passable'            : 'Passable';
  String get good             => isFr ? 'Bien'                : 'Good';
  String get toCatchUp        => isFr ? 'À rattraper'         : 'Needs makeup';
  String get insufficient     => isFr ? 'Insuffisant'         : 'Insufficient';
  String get admitted         => isFr ? 'Admis'               : 'Admitted';
  String get notAdmitted      => isFr ? 'Non admis'           : 'Not admitted';
  String get coefficient      => isFr ? 'Coeff.'              : 'Coeff.';
  String get viewDetail       => isFr ? 'Voir le détail'      : 'View details';
  String get publishedOn      => isFr ? 'Publié le'           : 'Published on';
  String get submittedOn      => isFr ? 'Soumise le'          : 'Submitted on';
  String get generalAverage   => isFr ? 'Moyenne générale'    : 'General average';
  String get student          => isFr ? 'Étudiant'            : 'Student';
  String get matricule        => isFr ? 'Matricule'           : 'Student ID';
  String get response         => isFr ? 'Réponse'             : 'Response';
  String get treatRequest     => isFr ? 'Traiter cette requête': 'Process this request';
  String get documentJustificatif => isFr ? 'Document justificatif' : 'Supporting document';
  String get openDocument     => isFr ? 'appuyez pour ouvrir' : 'tap to open';
  String get allRequests      => isFr ? 'Toutes les requêtes' : 'All requests';
  String get pendingRequests  => isFr ? 'En attente'          : 'Pending';
  String get processedRequests => isFr ? 'Traitées'           : 'Processed';
  String get noRequestsReceived => isFr ? 'Aucune requête reçue' : 'No requests received';
  String get requestsCount    => isFr ? 'requête(s)'          : 'request(s)';
  String get allTreated       => isFr ? 'Toutes traitées'     : 'All processed';
  String get treat            => isFr ? 'Traiter'             : 'Process';
  String get newGrade         => isFr ? 'Nouvelle note'       : 'New grade';
  String get reject           => isFr ? 'Rejeter'             : 'Reject';
  String get approve          => isFr ? 'Approuver'           : 'Approve';

  // ── Examens ──
  String get examRoom         => isFr ? 'Salle d\'examen'     : 'Exam room';
  String get joinExam         => isFr ? 'Rejoindre un examen' : 'Join an exam';
  String get examCode         => isFr ? 'Code de l\'examen'   : 'Exam code';
  String get startExam        => isFr ? 'Commencer l\'examen' : 'Start exam';
  String get submitExam       => isFr ? 'Soumettre l\'examen' : 'Submit exam';
  String get examSubmitted    => isFr ? 'Examen soumis !'     : 'Exam submitted!';
  String get yourScore        => isFr ? 'Votre note'          : 'Your score';
  String get outOf            => isFr ? 'sur'                 : 'out of';
  String get viewCorrection   => isFr ? 'Consulter la correction' : 'View correction';
  String get examHistory      => isFr ? 'Historique des examens' : 'Exam history';
  String get noExamsPassed    => isFr ? 'Aucun examen passé'  : 'No exams taken';
  String get examCorrected    => isFr ? 'Corrigé'             : 'Corrected';
  String get examInvalid      => isFr ? 'Invalide'            : 'Invalid';
  String get correctAnswer    => isFr ? 'Bonne réponse'       : 'Correct answer';
  String get wrongAnswer      => isFr ? 'Mauvaise réponse'    : 'Wrong answer';
  String get yourAnswer       => isFr ? 'Votre réponse'       : 'Your answer';
  String get noAnswer         => isFr ? 'Pas de réponse'      : 'No answer';
  String get points           => isFr ? 'points'              : 'points';
  String get question         => isFr ? 'Question'            : 'Question';
  String get timer            => isFr ? 'Chrono'              : 'Timer';
  String get remainingTime    => isFr ? 'restant'             : 'remaining';
  String get previous         => isFr ? 'Précédent'           : 'Previous';
  String get next             => isFr ? 'Suivant'             : 'Next';
  String get createExam       => isFr ? 'Créer un examen'     : 'Create exam';
  String get sessionCode      => isFr ? 'Code de la session'  : 'Session code';
  String get copyInvitation   => isFr ? 'Copier le code d\'invitation' : 'Copy invitation code';
  String get launchExam       => isFr ? 'Lancer l\'examen'    : 'Start exam';
  String get endExam          => isFr ? 'Terminer l\'examen'  : 'End exam';
  String get examLaunched     => isFr ? 'Examen lancé'        : 'Exam started';
  String get examEnded        => isFr ? 'Examen terminé'      : 'Exam ended';
  String get studentsComposed => isFr ? 'Étudiants ayant composé' : 'Students who took the exam';
  String get noStudents       => isFr ? 'Aucun étudiant'      : 'No students';
  String get questionOf       => isFr ? 'Question'            : 'Question';
  String get ofTotal          => isFr ? 'sur'                 : 'of';
  String get minRemaining     => isFr ? 'min restantes'       : 'min remaining';
}


// Provider global
final stringsProvider = Provider<Strings>(
      (ref) => Strings(ref.watch(localeProvider)),
);