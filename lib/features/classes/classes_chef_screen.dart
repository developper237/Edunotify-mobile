import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// NORMALISATION DE TEXTE
// ══════════════════════════════════════════════════════════════════

String _normalize(String input) {
  const avecAccents = 'àâäáãåéèêëíìîïóòôöõúùûüçñ';
  const sansAccents  = 'aaaaaaeeeeiiiiooooouuuucn';
  var out = input.toLowerCase();
  for (var i = 0; i < avecAccents.length; i++) {
    out = out.replaceAll(avecAccents[i], sansAccents[i]);
  }
  return out;
}

// ══════════════════════════════════════════════════════════════════
// DEPARTEMENTS / FILIERES
// ══════════════════════════════════════════════════════════════════

class _DepartementFilieres {
  final String nom;
  final List<String> motsCles;
  final List<String> filieres;

  const _DepartementFilieres({
    required this.nom,
    required this.motsCles,
    required this.filieres,
  });
}

final List<_DepartementFilieres> _departements = [
  const _DepartementFilieres(
    nom: 'Génie Informatique',
    motsCles: ['genie informatique', 'departement informatique'],
    filieres: [
      'Genie Logiciel',
      'Administration et Securite des Reseaux',
      'Genie Informatique',
      'Genie Reseau et Telecommunications',
      'Mention des technologies de l\'information et du numérique'
    ],
  ),
  const _DepartementFilieres(
    nom: 'Génie Électrique et Informatique Industrielle',
    motsCles: ['genie electrique', 'geii'],
    filieres: [
      'Genie Electrique et Informatique Industrielle',
      'Mecatronique',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Génie Industriel et Maintenance',
    motsCles: ['genie industriel', 'gim'],
    filieres: [
      'Genie Industriel et Maintenance',
      'Genie Mecanique et Productique',
      'Logistique Industrielle',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Génie Thermique et Énergie',
    motsCles: ['thermique', 'energie'],
    filieres: [
      'Genie Thermique et Energie',
      "Economie d'Energie et Environnement",
      'Valorisation des Energies Renouvelables',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Génie Civil',
    motsCles: ['genie civil'],
    filieres: [
      'Genie Civil',
      'Genie des Mines',
      'Genie Metallurgique',
      'Genie Ferroviaire',
      'Meteorologie',
      'Licence en Petrole et Gaz',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Génie Biomédical',
    motsCles: ['biomedical', 'chimie'],
    filieres: [
      'Genie Biomedical',
      'Chimie Pharmaceutique',
      'Qualite, Hygiene et Salubrite des Aliments',
      'Chimie Industrielle et Pharmaceutique',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Gestion des Entreprises et des Administrations',
    motsCles: ['entreprises et des administrations', 'gestion des entreprises'],
    filieres: [
      'Gestion des Entreprises et des Administrations',
      'Genie Logistique et Transport',
      'Techniques de Commercialisation',
      'Negociation Vente',
      'Gestion des Ressources Humaines',
      'Assistant Manager',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Organisation et Gestion Administrative',
    motsCles: ['organisation et gestion administrative', 'oga'],
    filieres: [
      'Organisation et Gestion Administrative',
      'Gestion Appliquee aux Petites et Moyennes Organisations',
      'Gestion Comptable et Financiere',
    ],
  ),
  const _DepartementFilieres(
    nom: 'Gestion Bancaire et Financière',
    motsCles: ['bancaire', 'banque et finances'],
    filieres: [
      'Gestion Bancaire et Financiere',
      'Banque et Finances',
    ],
  ),
];

final List<String> _toutesLesFilieres =
_departements.expand((d) => d.filieres).toSet().toList();

final filieresProvider = Provider<List<String>>((ref) {
  final user    = ref.watch(currentUserProvider);
  final deptNom = _normalize(user?.departementNom ?? '');

  if (deptNom.isEmpty) return _toutesLesFilieres;

  for (final dept in _departements) {
    final match = dept.motsCles.any((mot) => deptNom.contains(_normalize(mot)));
    if (match) return dept.filieres;
  }
  return _toutesLesFilieres;
});

// ══════════════════════════════════════════════════════════════════
// MODELE
// ══════════════════════════════════════════════════════════════════

class ClasseSalle {
  final String id;
  final String nomSalle;
  final String filiere;
  final String niveau;
  final String formation;
  final String codeGenere;
  final String emailDelegue;
  final int nbEtudiants;

  const ClasseSalle({
    required this.id,
    required this.nomSalle,
    required this.filiere,
    required this.niveau,
    required this.formation,
    required this.codeGenere,
    required this.emailDelegue,
    required this.nbEtudiants,
  });

  factory ClasseSalle.fromJson(Map<String, dynamic> j) => ClasseSalle(
    id:           j['id']           ?? '',
    nomSalle:     j['nom']          ?? j['nomSalle'] ?? '',
    filiere:      j['filiere']      ?? '',
    niveau:       j['niveau']       ?? '',
    formation:    j['formation']    ?? 'FI',
    codeGenere:   j['codeGenere']   ?? '',
    emailDelegue: j['emailDelegue'] ?? '',
    nbEtudiants:  j['nbEtudiants']  ?? j['_count']?['etudiants'] ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════
// GENERATION CODE
// ══════════════════════════════════════════════════════════════════

bool formationEstModifiable(String niveau) => niveau == 'L1' || niveau == 'L2';

String genererCodeClasse(
    String nomSalle, String filiere, String niveau, String formation) {
  final salle = nomSalle.trim().replaceAll(' ', '');
  final sigles = {
    'Genie Logiciel':                                         'GL',
    'Administration et Securite des Reseaux':                 'ASR',
    'Genie Informatique':                                     'GI',
    'Genie Reseau et Telecommunications':                     'GRT',
    'Genie Electrique et Informatique Industrielle':          'GEII',
    'Genie Industriel et Maintenance':                        'GIM',
    'Genie Mecanique et Productique':                         'GMP',
    'Genie Thermique et Energie':                             'GTE',
    'Genie Biomedical':                                       'GBM',
    'Genie Civil':                                            'GC',
    'Genie des Mines':                                        'GMI',
    'Genie Metallurgique':                                    'GME',
    'Genie Ferroviaire':                                      'GFE',
    'Meteorologie':                                           'MET',
    'Licence en Petrole et Gaz':                              'PG',
    'Logistique Industrielle':                                'LI',
    "Economie d'Energie et Environnement":                    'EEE',
    'Valorisation des Energies Renouvelables':                'VER',
    'Chimie Pharmaceutique':                                  'CP',
    'Qualite, Hygiene et Salubrite des Aliments':             'QHSA',
    'Gestion des Entreprises et des Administrations':         'GEA',
    'Genie Logistique et Transport':                          'GLT',
    'Techniques de Commercialisation':                        'TC',
    'Organisation et Gestion Administrative':                 'OGA',
    'Gestion Appliquee aux Petites et Moyennes Organisations':'GAPMO',
    'Gestion Comptable et Financiere':                        'GCF',
    'Negociation Vente':                                      'CNV',
    'Gestion des Ressources Humaines':                        'GRH',
    'Gestion Bancaire et Financiere':                         'GBF',
    'Banque et Finances':                                     'BAF',
    'Assistant Manager':                                      'AMA',
    'Chimie Industrielle et Pharmaceutique':                  'CIP',
    'Mecatronique':                                           'MECA',
    'Mention des technologies de l\'information et du numérique': 'MTIN',
  };
  final sigle = sigles[filiere] ??
      filiere.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  return '$salle-$sigle-$niveau-$formation';
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final classesChefProvider =
StateNotifierProvider<ClassesChefNotifier, AsyncValue<List<ClasseSalle>>>(
      (ref) => ClassesChefNotifier(ref),
);

class ClassesChefNotifier
    extends StateNotifier<AsyncValue<List<ClasseSalle>>> {
  final Ref _ref;
  ClassesChefNotifier(this._ref) : super(const AsyncLoading()) {
    charger();
  }

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecté');

      final resp = await ApiClient.getAcademic(
        '/academic/mes-classes',
        userId:        user.id,
        role:          user.role,
        departementId: user.departementId,
      );

      final filieres = resp['filieres'] as Map<String, dynamic>? ?? {};
      final classes  = <ClasseSalle>[];
      for (final liste in filieres.values) {
        for (final c in (liste as List)) {
          classes.add(ClasseSalle.fromJson(c as Map<String, dynamic>));
        }
      }
      state = AsyncData(classes);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ── Supprimer une classe ────────────────────────────────────────
  Future<void> supprimer(String classeId) async {
    await ApiClient.delete('/auth/cascade/classe/$classeId');
    state = state.whenData(
          (liste) => liste.where((c) => c.id != classeId).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class ClassesChefScreen extends ConsumerWidget {
  const ClassesChefScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesChefProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Classes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showCreerModal(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Creer une salle',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.textMuted),
              const SizedBox(height: 12),
              Text('Impossible de charger les classes',
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(classesChefProvider.notifier).charger(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
        data: (classes) => classes.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.class_outlined,
                  size: 48, color: context.textMuted),
              const SizedBox(height: 12),
              Text('Aucune classe',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreerModal(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Creer une salle'),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          color: AppColors.green,
          onRefresh: () =>
              ref.read(classesChefProvider.notifier).charger(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ClasseTile(classe: classes[i]),
          ),
        ),
      ),
    );
  }

  void _showCreerModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CreerSalleModal(
        // On recharge la liste complète depuis le serveur après création,
        // au lieu d'ajouter localement un objet avec un id fictif.
        // Ça garantit que l'id stocké correspond bien à celui de la DB
        // (sinon la suppression envoie un DELETE sur un id qui n'existe pas → 404).
        onCreer: () => ref.read(classesChefProvider.notifier).charger(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE CLASSE
// ══════════════════════════════════════════════════════════════════

class _ClasseTile extends ConsumerWidget {
  final ClasseSalle classe;
  const _ClasseTile({required this.classe});

  Future<void> _confirmerSuppression(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la classe ?'),
        content: Text(
          'La classe ${classe.codeGenere} et toutes ses données '
              '(présences, notes, étudiants) seront supprimées définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(classesChefProvider.notifier).supprimer(classe.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Classe ${classe.codeGenere} supprimée'),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la suppression'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFI           = classe.formation == 'FI';
    final formationColor = isFI ? AppColors.green : AppColors.violet;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Ligne 1 : code + filière + nb étudiants ───────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        AppColors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(classe.codeGenere,
                    style: const TextStyle(
                        color:       Colors.white,
                        fontSize:    13,
                        fontWeight:  FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classe.filiere,
                        style: TextStyle(
                            color:      context.textPrimary,
                            fontSize:   13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Niveau ${classe.niveau}',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.cyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text('${classe.nbEtudiants}',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Ligne 2 : salle + email délégué ───────────────────
          Row(
            children: [
              Icon(Icons.door_front_door_outlined,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Text('Salle ${classe.nomSalle}',
                  style:
                  TextStyle(color: context.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              if (classe.emailDelegue.isNotEmpty) ...[
                Icon(Icons.email_outlined,
                    size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(classe.emailDelegue,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // ── Ligne 3 : formation ────────────────────────────────
          Row(
            children: [
              Icon(
                isFI
                    ? Icons.wb_sunny_outlined
                    : Icons.nights_stay_outlined,
                size:  13,
                color: formationColor,
              ),
              const SizedBox(width: 4),
              Text(
                isFI
                    ? 'Formation Initiale (cours du jour)'
                    : 'Formation par Alternance (cours du soir)',
                style: TextStyle(
                    color:      formationColor,
                    fontSize:   11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Bouton supprimer ───────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _confirmerSuppression(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:        AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.red, size: 14),
                    SizedBox(width: 4),
                    Text('Supprimer',
                        style: TextStyle(
                            color:      AppColors.red,
                            fontSize:   12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL CREER SALLE
// ══════════════════════════════════════════════════════════════════

class _CreerSalleModal extends ConsumerStatefulWidget {
  // VoidCallback : on ne renvoie plus l'objet ClasseSalle créé côté client
  // (avec un id fictif), on se contente de signaler "création réussie" pour
  // que l'écran parent recharge la vraie liste depuis le serveur.
  final VoidCallback onCreer;
  const _CreerSalleModal({required this.onCreer});

  @override
  ConsumerState<_CreerSalleModal> createState() => _CreerSalleModalState();
}

class _CreerSalleModalState extends ConsumerState<_CreerSalleModal> {
  final _nomSalle         = TextEditingController();
  final _emailDelegue     = TextEditingController();
  final _matriculeDelegue = TextEditingController();
  String  _filiere   = 'Genie Logiciel';
  String  _niveau    = 'L1';
  String  _formation = 'FI';
  bool    _loading   = false;
  bool    _done      = false;
  String? _error;

  static const _niveaux = ['L1', 'L2', 'L3', 'M1', 'M2'];

  @override
  void dispose() {
    _nomSalle.dispose();
    _emailDelegue.dispose();
    _matriculeDelegue.dispose();
    super.dispose();
  }

  String get _codePreview {
    if (_nomSalle.text.trim().isEmpty) return '---';
    return genererCodeClasse(
        _nomSalle.text.trim(), _filiere, _niveau, _formation);
  }

  void _selectionnerNiveau(String n) {
    setState(() {
      _niveau = n;
      if (!formationEstModifiable(n)) _formation = 'FA';
    });
  }

  Future<void> _creer() async {
    final nom       = _nomSalle.text.trim();
    final email     = _emailDelegue.text.trim();
    final matricule = _matriculeDelegue.text.trim();

    if (nom.isEmpty || email.isEmpty || matricule.isEmpty) {
      setState(() => _error = 'Tous les champs sont obligatoires');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Adresse email invalide');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient.post('/auth/cascade/classe', data: {
        'nomSalle':         nom,
        'filiere':          _filiere,
        'niveau':           _niveau,
        'formation':        _formation,
        'emailDelegue':     email,
        'matriculeDelegue': matricule,
        'prenomDelegue':    'Delegue',
        'nomDelegue':       nom,
      });

      // On ne fabrique plus de ClasseSalle locale avec un id fictif
      // (ex: 'cls-1783789211215'). L'appelant (widget.onCreer) recharge
      // la liste depuis le serveur, qui renverra le vrai id Prisma
      // (ex: 'cmrgl8eh10001mxnnxhngcw4z'). Sans ça, un DELETE ultérieur
      // sur cette classe échoue avec un 404 car l'id n'existe pas en DB.
      widget.onCreer();

      setState(() { _loading = false; _done = true; });
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() {
        _loading = false;
        _error   = 'Erreur de connexion au serveur';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filieres = ref.watch(filieresProvider);
    if (!filieres.contains(_filiere)) _filiere = filieres.first;

    final formationModifiable = formationEstModifiable(_niveau);

    return Container(
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _done
          ? _SuccessView(
        titre:   'Classe creee !',
        message: 'La classe $_codePreview a ete creee.\n'
            'Les identifiants ont ete envoyes a ${_emailDelegue.text.trim()}.',
        color:   AppColors.green,
        onClose: () => Navigator.pop(context),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color:        context.borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            Text('Creer une salle',
                style: TextStyle(
                    color:      context.textPrimary,
                    fontSize:   17,
                    fontWeight: FontWeight.w700)),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        context.isDark
                    ? AppColors.dark
                    : AppColors.light,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: context.textMuted, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un compte delegue sera cree et les identifiants '
                          'envoyes par email. Le matricule permet au systeme '
                          'de retrouver ses notes comme les autres etudiants.',
                      style: TextStyle(
                          color:  context.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Aperçu code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Code de la classe',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(_codePreview,
                      style: const TextStyle(
                          color:       Colors.white,
                          fontSize:    22,
                          fontWeight:  FontWeight.w700,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('Genere automatiquement',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Nom salle ──
            _FieldLabel('Nom de la salle *', context),
            const SizedBox(height: 4),
            Text('Ex: B1, C2, Amphi A...',
                style: TextStyle(
                    color: context.textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: _nomSalle,
              onChanged:  (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:   'B1',
                prefixIcon: Icon(Icons.door_front_door_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 16),

            // ── Filiere ──
            _FieldLabel('Filiere *', context),
            const SizedBox(height: 4),
            Text('${filieres.length} filiere(s) dans votre departement',
                style: TextStyle(
                    color: AppColors.green, fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:        context.isDark
                    ? AppColors.dark
                    : AppColors.light,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filieres.contains(_filiere)
                      ? _filiere
                      : filieres.first,
                  isExpanded:    true,
                  dropdownColor: context.cardColor,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: context.textMuted),
                  items: filieres
                      .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f,
                        style: TextStyle(
                            color:    context.textPrimary,
                            fontSize: 14)),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _filiere = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Niveau ──
            _FieldLabel('Niveau *', context),
            const SizedBox(height: 8),
            Row(
              children: _niveaux.map((n) {
                final selected = _niveau == n;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectionnerNiveau(n),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: n != _niveaux.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.green
                            : context.isDark
                            ? AppColors.dark
                            : AppColors.light,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(n,
                            style: TextStyle(
                                color:      selected
                                    ? Colors.white
                                    : context.textSecondary,
                                fontSize:   13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Formation ──
            if (formationModifiable) ...[
              const SizedBox(height: 16),
              _FieldLabel('Type de formation *', context),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _formation = 'FI'),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _formation == 'FI'
                              ? AppColors.green
                              : context.isDark
                              ? AppColors.dark
                              : AppColors.light,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.wb_sunny_outlined,
                                color: _formation == 'FI'
                                    ? Colors.white
                                    : context.textMuted,
                                size: 24),
                            const SizedBox(height: 6),
                            Text('FI',
                                style: TextStyle(
                                    color: _formation == 'FI'
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontSize:   15,
                                    fontWeight: _formation == 'FI'
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                            const SizedBox(height: 2),
                            Text('Cours du jour',
                                style: TextStyle(
                                    color: _formation == 'FI'
                                        ? Colors.white70
                                        : context.textMuted,
                                    fontSize: 11),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _formation = 'FA'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _formation == 'FA'
                              ? AppColors.violet
                              : context.isDark
                              ? AppColors.dark
                              : AppColors.light,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.nights_stay_outlined,
                                color: _formation == 'FA'
                                    ? Colors.white
                                    : context.textMuted,
                                size: 24),
                            const SizedBox(height: 6),
                            Text('FA',
                                style: TextStyle(
                                    color: _formation == 'FA'
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontSize:   15,
                                    fontWeight: _formation == 'FA'
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                            const SizedBox(height: 2),
                            Text('Cours du soir',
                                style: TextStyle(
                                    color: _formation == 'FA'
                                        ? Colors.white70
                                        : context.textMuted,
                                    fontSize: 11),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        AppColors.violet,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.nights_stay_outlined,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A partir de la L3, la formation par alternance '
                            'est appliquee automatiquement.',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Email délégué ──
            _FieldLabel('Email du delegue *', context),
            const SizedBox(height: 4),
            Text('Ce compte recevra les identifiants par email',
                style: TextStyle(
                    color: context.textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller:  _emailDelegue,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText:   'delegue@classe.cm',
                prefixIcon: Icon(Icons.email_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 16),

            // ── Matricule délégué ──
            _FieldLabel('Matricule du delegue *', context),
            const SizedBox(height: 4),
            Text(
              'Permet au delegue de recevoir ses notes comme les autres etudiants',
              style: TextStyle(
                  color: context.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller:           _matriculeDelegue,
              textCapitalization:   TextCapitalization.characters,
              decoration: InputDecoration(
                hintText:   'Ex: 21G0042',
                prefixIcon: Icon(Icons.badge_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            // Erreur
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        AppColors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _creer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: _loading
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Icon(Icons.add, size: 18),
                label: Text(_loading
                    ? 'Creation en cours...'
                    : 'Creer la classe'),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _FieldLabel(this.text, this.ctx);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color:      ctx.textSecondary,
      fontSize:   13,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final String titre, message;
  final Color color;
  final VoidCallback onClose;

  const _SuccessView({
    required this.titre,
    required this.message,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color:        context.borderColor,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text(titre,
            style: TextStyle(
                color:      context.textPrimary,
                fontSize:   18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(message,
              style: TextStyle(
                  color:    context.textMuted,
                  fontSize: 13,
                  height:   1.5),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Fermer'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}