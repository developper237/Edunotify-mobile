class User {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String statut;
  final String? classeId;
  final String? etablissementId;
  final String? departementId;
  final String? fcmToken;
  final bool biometrieActivee;
  final String? departementNom;
  final String? salleCode;
  final String? etablissementNom;
  final String? etablissementLogo;

  const User({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.statut,
    this.classeId,
    this.etablissementId,
    this.departementId,
    this.fcmToken,
    this.biometrieActivee = false,
    this.departementNom,
    this.salleCode,
    this.etablissementNom,
    this.etablissementLogo,
  });

  String get fullName  => '$prenom $nom';
  String get initiales =>
      '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'
          .toUpperCase();

  factory User.fromJson(Map<String, dynamic> j) => User(
    id:                j['id'],
    nom:               j['nom'],
    prenom:            j['prenom'],
    email:             j['email'],
    role:              j['role'],
    statut:            j['statut']            ?? 'actif',
    classeId:          j['classeId']          ?? j['classeEtudiantId'] ?? j['classeDelegueId'],
    etablissementId:   j['etablissementId'],
    departementId:     j['departementId'],
    fcmToken:          j['fcmToken'],
    biometrieActivee:  j['biometrieActivee']  ?? false,
    departementNom:    j['departementNom'],
    salleCode:         j['salleCode'],
    etablissementNom:  j['etablissementNom'],
    etablissementLogo: j['etablissementLogo'],
  );

  Map<String, dynamic> toJson() => {
    'id':               id,
    'nom':              nom,
    'prenom':           prenom,
    'email':            email,
    'role':             role,
    'statut':           statut,
    'classeId':         classeId,
    'etablissementId':  etablissementId,
    'departementId':    departementId,
    'fcmToken':         fcmToken,
    'biometrieActivee': biometrieActivee,
    'departementNom':   departementNom,
    'salleCode':        salleCode,
    'etablissementNom': etablissementNom,
    'etablissementLogo': etablissementLogo,
  };

  User copyWith({
    String? fcmToken,
    bool? biometrieActivee,
    String? departementNom,
    String? salleCode,
    String? etablissementNom,
    String? etablissementLogo,
    String? etablissementId,
    String? departementId,
  }) => User(
    id:                id,
    nom:               nom,
    prenom:            prenom,
    email:             email,
    role:              role,
    statut:            statut,
    classeId:          classeId,
    etablissementId:   etablissementId   ?? this.etablissementId,
    departementId:     departementId     ?? this.departementId,
    fcmToken:          fcmToken          ?? this.fcmToken,
    biometrieActivee:  biometrieActivee  ?? this.biometrieActivee,
    departementNom:    departementNom    ?? this.departementNom,
    salleCode:         salleCode         ?? this.salleCode,
    etablissementNom:  etablissementNom  ?? this.etablissementNom,
    etablissementLogo: etablissementLogo ?? this.etablissementLogo,
  );
}

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) => AuthState(
    user:            user            ?? this.user,
    isLoading:       isLoading       ?? this.isLoading,
    error:           error,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
  );
}