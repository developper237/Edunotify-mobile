import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// FILIERES PAR DEPARTEMENT
// ══════════════════════════════════════════════════════════════════

const Map<String, List<String>> filieresParDepartement = {
  'Informatique': [
    'Genie Logiciel',
    'Administration Systeme et Reseau',
    'Reseaux et Telecommunications',
    'Informatique de Gestion',
  ],
  'Genie Civil': [
    'Genie Civil',
    'Topographie',
    'Environnement et Amenagement',
  ],
  'Genie Electrique': [
    'Genie Electrique',
    'Electronique',
    'Automatisme et Informatique Industrielle',
  ],
  'Genie Mecanique': [
    'Genie Mecanique',
    'Maintenance Industrielle',
  ],
  'default': [
    'Genie Logiciel',
    'Administration Systeme et Reseau',
    'Genie Civil',
    'Genie Electrique',
    'Genie Mecanique',
  ],
};

final filieresProvider = Provider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  final dept = user?.departementNom ?? 'default';
  return filieresParDepartement[dept] ??
      filieresParDepartement['default']!;
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
    id:           j['id'] ?? '',
    nomSalle:     j['nom'] ?? j['nomSalle'] ?? '',
    filiere:      j['filiere'] ?? '',
    niveau:       j['niveau'] ?? '',
    formation:    j['formation'] ?? 'FI',
    codeGenere:   j['codeGenere'] ?? '',
    emailDelegue: j['emailDelegue'] ?? '',
    nbEtudiants:  j['nbEtudiants'] ?? j['_count']?['etudiants'] ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════
// GENERATION CODE
// ══════════════════════════════════════════════════════════════════

String genererCodeClasse(
    String nomSalle, String filiere, String niveau, String formation) {
  final salle = nomSalle.trim().replaceAll(' ', '');
  final sigles = {
    'Genie Logiciel':                          'GL',
    'Administration Systeme et Reseau':        'ASR',
    'Genie Civil':                             'GC',
    'Genie Electrique':                        'GE',
    'Genie Mecanique':                         'GM',
    'Informatique de Gestion':                 'IG',
    'Reseaux et Telecommunications':           'RT',
    'Topographie':                             'TOPO',
    'Environnement et Amenagement':            'EA',
    'Electronique':                            'ELEC',
    'Automatisme et Informatique Industrielle': 'AII',
    'Maintenance Industrielle':                'MI',
  };
  final sigle = sigles[filiere] ??
      filiere.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  return '$salle-$sigle-$niveau-$formation';
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER — chargement depuis le backend
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

  void ajouter(ClasseSalle classe) {
    final current = state.value ?? [];
    state = AsyncData([...current, classe]);
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
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppColors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Creer une salle',
                        style: TextStyle(
                            color: AppColors.green,
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreerSalleModal(
        onCreer: (classe) =>
            ref.read(classesChefProvider.notifier).ajouter(classe),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE CLASSE
// ══════════════════════════════════════════════════════════════════

class _ClasseTile extends StatelessWidget {
  final ClasseSalle classe;
  const _ClasseTile({required this.classe});

  @override
  Widget build(BuildContext context) {
    final isFI = classe.formation == 'FI';
    final formationColor = isFI ? AppColors.green : AppColors.violet;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  classe.codeGenere,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classe.filiere,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Niveau ${classe.niveau}',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline,
                        color: AppColors.cyan, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${classe.nbEtudiants}',
                      style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.door_front_door_outlined,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Text('Salle ${classe.nomSalle}',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              if (classe.emailDelegue.isNotEmpty) ...[
                Icon(Icons.email_outlined,
                    size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    classe.emailDelegue,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                isFI ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                size: 13,
                color: formationColor,
              ),
              const SizedBox(width: 4),
              Text(
                isFI
                    ? 'Formation Initiale (cours du jour)'
                    : 'Formation par Alternance (cours du soir)',
                style: TextStyle(
                  color: formationColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
  final void Function(ClasseSalle) onCreer;
  const _CreerSalleModal({required this.onCreer});

  @override
  ConsumerState<_CreerSalleModal> createState() => _CreerSalleModalState();
}

class _CreerSalleModalState extends ConsumerState<_CreerSalleModal> {
  final _nomSalle        = TextEditingController();
  final _emailDelegue    = TextEditingController();
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

  Future<void> _creer() async {
    final nom      = _nomSalle.text.trim();
    final email    = _emailDelegue.text.trim();
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
        'matriculeDelegue': matricule,  // ← nouveau champ
        'prenomDelegue':    'Delegue',
        'nomDelegue':       nom,
      });

      final code = genererCodeClasse(nom, _filiere, _niveau, _formation);

      widget.onCreer(ClasseSalle(
        id:           'cls-${DateTime.now().millisecondsSinceEpoch}',
        nomSalle:     nom,
        filiere:      _filiere,
        niveau:       _niveau,
        formation:    _formation,
        codeGenere:   code,
        emailDelegue: email,
        nbEtudiants:  0,
      ));

      setState(() { _loading = false; _done = true; });
    } on ApiException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erreur de connexion au serveur';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filieres = ref.watch(filieresProvider);
    if (!filieres.contains(_filiere)) _filiere = filieres.first;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            Text('Creer une salle',
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),

            const SizedBox(height: 8),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.green, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un compte delegue sera cree et les identifiants '
                          'envoyes par email. Le matricule permet au systeme '
                          'de retrouver ses notes comme les autres etudiants.',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Apercu code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text('Code de la classe',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    _codePreview,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Genere automatiquement',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 11)),
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'B1',
                prefixIcon: Icon(Icons.door_front_door_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 16),

            // ── Filiere ──
            _FieldLabel('Filiere *', context),
            const SizedBox(height: 4),
            Text('${filieres.length} filiere(s) dans votre departement',
                style: TextStyle(color: AppColors.green, fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.dark : AppColors.light,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filieres.contains(_filiere)
                      ? _filiere
                      : filieres.first,
                  isExpanded: true,
                  dropdownColor: context.cardColor,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: context.textMuted),
                  items: filieres
                      .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f,
                        style: TextStyle(
                            color: context.textPrimary,
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
                    onTap: () => setState(() => _niveau = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                          right: n != _niveaux.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.green.withValues(alpha: 0.15)
                            : context.isDark
                            ? AppColors.dark
                            : AppColors.light,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.green
                              : context.borderColor,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          n,
                          style: TextStyle(
                            color: selected
                                ? AppColors.green
                                : context.textSecondary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // ── Formation ──
            _FieldLabel('Type de formation *', context),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _formation = 'FI'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _formation == 'FI'
                            ? AppColors.green.withValues(alpha: 0.15)
                            : context.isDark
                            ? AppColors.dark
                            : AppColors.light,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _formation == 'FI'
                              ? AppColors.green
                              : context.borderColor,
                          width: _formation == 'FI' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.wb_sunny_outlined,
                              color: _formation == 'FI'
                                  ? AppColors.green
                                  : context.textMuted,
                              size: 24),
                          const SizedBox(height: 6),
                          Text('FI',
                              style: TextStyle(
                                  color: _formation == 'FI'
                                      ? AppColors.green
                                      : context.textSecondary,
                                  fontSize: 15,
                                  fontWeight: _formation == 'FI'
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                          const SizedBox(height: 2),
                          Text('Cours du jour',
                              style: TextStyle(
                                  color: _formation == 'FI'
                                      ? AppColors.green
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _formation == 'FA'
                            ? AppColors.violet.withValues(alpha: 0.15)
                            : context.isDark
                            ? AppColors.dark
                            : AppColors.light,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _formation == 'FA'
                              ? AppColors.violet
                              : context.borderColor,
                          width: _formation == 'FA' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.nights_stay_outlined,
                              color: _formation == 'FA'
                                  ? AppColors.violet
                                  : context.textMuted,
                              size: 24),
                          const SizedBox(height: 6),
                          Text('FA',
                              style: TextStyle(
                                  color: _formation == 'FA'
                                      ? AppColors.violet
                                      : context.textSecondary,
                                  fontSize: 15,
                                  fontWeight: _formation == 'FA'
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                          const SizedBox(height: 2),
                          Text('Cours du soir',
                              style: TextStyle(
                                  color: _formation == 'FA'
                                      ? AppColors.violet
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

            const SizedBox(height: 16),

            // ── Email delegue ──
            _FieldLabel('Email du delegue *', context),
            const SizedBox(height: 4),
            Text('Ce compte recevra les identifiants par email',
                style: TextStyle(
                    color: context.textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailDelegue,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'delegue@classe.cm',
                prefixIcon: Icon(Icons.email_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),

            const SizedBox(height: 16),

            // ── Matricule delegue ── (NOUVEAU)
            _FieldLabel('Matricule du delegue *', context),
            const SizedBox(height: 4),
            Text(
              'Permet au delegue de recevoir ses notes comme les autres etudiants',
              style: TextStyle(color: context.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _matriculeDelegue,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Ex: 21G0042',
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
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 13)),
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
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 18),
                label: Text(
                    _loading ? 'Creation en cours...' : 'Creer la classe'),
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
      color: ctx.textSecondary,
      fontSize: 13,
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
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.check_rounded, color: color, size: 36),
        ),
        const SizedBox(height: 20),
        Text(titre,
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(message,
              style: TextStyle(
                  color: context.textMuted, fontSize: 13, height: 1.5),
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