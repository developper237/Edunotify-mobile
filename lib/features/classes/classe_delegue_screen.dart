import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class EtudiantClasse {
  final String id;
  final String nom;
  final String prenom;
  final String matricule;
  final String email;

  const EtudiantClasse({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.email,
  });

  factory EtudiantClasse.fromJson(Map<String, dynamic> j) => EtudiantClasse(
    id:        j['id']        as String? ?? '',
    nom:       j['nom']       as String? ?? '',
    prenom:    j['prenom']    as String? ?? '',
    matricule: j['matricule'] as String? ?? '',
    email:     j['email']     as String? ?? '',
  );
}

class EtudiantCSV {
  final String matricule;
  final String nom;
  final String prenom;
  final String email;
  final String niveau;
  final String formation;
  final bool valide;
  final String? erreur;

  const EtudiantCSV({
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.niveau,
    required this.formation,
    this.valide = true,
    this.erreur,
  });
}

class ImportResult {
  final int created;
  final int skipped;
  final List<String> errors;

  const ImportResult({
    required this.created,
    required this.skipped,
    required this.errors,
  });
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER — Étudiants depuis le backend
// ══════════════════════════════════════════════════════════════════

final classeBackendProvider = StateNotifierProvider<
    ClasseBackendNotifier, AsyncValue<List<EtudiantClasse>>>(
      (ref) => ClasseBackendNotifier(ref),
);

class ClasseBackendNotifier
    extends StateNotifier<AsyncValue<List<EtudiantClasse>>> {
  final Ref _ref;
  ClasseBackendNotifier(this._ref) : super(const AsyncLoading()) {
    charger();
  }

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        state = const AsyncData([]);
        return;
      }
      final resp = await ApiClient.get(
        '/auth/cascade/ma-classe',
      );
      final liste = (resp['etudiants'] as List<dynamic>? ?? [])
          .map((e) => EtudiantClasse.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncData(liste);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER — Import CSV
// ══════════════════════════════════════════════════════════════════

enum ImportStatus { idle, parsing, preview, importing, done, error }

class ImportState {
  final ImportStatus status;
  final List<EtudiantCSV> etudiants;
  final ImportResult? result;
  final String? errorMessage;

  const ImportState({
    this.status = ImportStatus.idle,
    this.etudiants = const [],
    this.result,
    this.errorMessage,
  });

  ImportState copyWith({
    ImportStatus? status,
    List<EtudiantCSV>? etudiants,
    ImportResult? result,
    String? errorMessage,
  }) =>
      ImportState(
        status:       status       ?? this.status,
        etudiants:    etudiants    ?? this.etudiants,
        result:       result       ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

final importProvider =
StateNotifierProvider<ImportNotifier, ImportState>(
      (ref) => ImportNotifier(),
);

class ImportNotifier extends StateNotifier<ImportState> {
  ImportNotifier() : super(const ImportState());

  Future<void> choisirFichier() async {
    state = state.copyWith(status: ImportStatus.parsing);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: ImportStatus.idle);
        return;
      }

      final bytes   = result.files.first.bytes!;
      final content = utf8.decode(bytes);
      final rows    = const CsvToListConverter().convert(
        content,
        eol: '\n',
        shouldParseNumbers: false,
      );

      if (rows.isEmpty) {
        state = state.copyWith(
          status:       ImportStatus.error,
          errorMessage: 'Fichier CSV vide',
        );
        return;
      }

      final dataRows =
      _isHeader(rows.first) ? rows.sublist(1) : rows;

      final etudiants = dataRows
          .where((row) => row.length >= 4)
          .map((row) => _parseRow(row))
          .toList();

      if (etudiants.isEmpty) {
        state = state.copyWith(
          status:       ImportStatus.error,
          errorMessage: 'Aucune ligne valide trouvée',
        );
        return;
      }

      state = state.copyWith(
        status:    ImportStatus.preview,
        etudiants: etudiants,
      );
    } catch (e) {
      state = state.copyWith(
        status:       ImportStatus.error,
        errorMessage: 'Erreur de lecture : ${e.toString()}',
      );
    }
  }

  Future<void> confirmerImport(WidgetRef ref) async {
    state = state.copyWith(status: ImportStatus.importing);
    try {
      final valides = state.etudiants.where((e) => e.valide).toList();

      final csvContent = StringBuffer();
      csvContent.writeln('matricule,nom,prenom,email,niveau,formation');
      for (final e in valides) {
        csvContent.writeln(
            '${e.matricule},${e.nom},${e.prenom},${e.email},${e.niveau},${e.formation}');
      }

      final resp = await ApiClient.postFormData(
        '/auth/csv/import',
        csvContent: csvContent.toString(),
        filename:   'import.csv',
      );

      final summary = resp['summary'] as Map<String, dynamic>;
      final result = ImportResult(
        created: summary['created'] as int,
        skipped: summary['skipped'] as int,
        errors:  (resp['details']?['errors'] as List<dynamic>? ?? [])
            .map((e) => e['error']?.toString() ?? '')
            .toList(),
      );

      state = state.copyWith(status: ImportStatus.done, result: result);

      // Recharger la liste depuis le backend après import
      ref.read(classeBackendProvider.notifier).charger();
    } on ApiException catch (e) {
      state = state.copyWith(
          status: ImportStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
          status: ImportStatus.error, errorMessage: 'Erreur de connexion');
    }
  }

  void reset() => state = const ImportState();

  bool _isHeader(List<dynamic> row) {
    final first = row.first.toString().toLowerCase();
    return first == 'matricule' || first == 'nom' || first == 'name';
  }

  EtudiantCSV _parseRow(List<dynamic> row) {
    final matricule = row[0].toString().trim();
    final nom       = row[1].toString().trim().toUpperCase();
    final prenom    = row[2].toString().trim();
    final email     = row.length > 3 ? row[3].toString().trim() : '';
    final niveau    = row.length > 4 ? row[4].toString().trim() : 'L1';
    final formation = row.length > 5 ? row[5].toString().trim() : 'jour';

    if (matricule.isEmpty)
      return EtudiantCSV(
        matricule: matricule, nom: nom, prenom: prenom,
        email: email, niveau: niveau, formation: formation,
        valide: false, erreur: 'Matricule vide',
      );
    if (!email.contains('@'))
      return EtudiantCSV(
        matricule: matricule, nom: nom, prenom: prenom,
        email: email, niveau: niveau, formation: formation,
        valide: false, erreur: 'Email invalide',
      );

    return EtudiantCSV(
      matricule: matricule, nom: nom, prenom: prenom,
      email: email, niveau: niveau, formation: formation,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL
// ══════════════════════════════════════════════════════════════════

class ClasseDelegueScreen extends ConsumerWidget {
  const ClasseDelegueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importProvider);

    switch (importState.status) {
      case ImportStatus.preview:
        return _PreviewScreen(etudiants: importState.etudiants);
      case ImportStatus.importing:
        return const _LoadingScreen();
      case ImportStatus.done:
        return _ResultScreen(result: importState.result!);
      default:
        return const _HomeScreen();
    }
  }
}

// ── Vue accueil — charge depuis le backend ────────────────────────
class _HomeScreen extends ConsumerWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etudiantsAsync = ref.watch(classeBackendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Classe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: () =>
                ref.read(classeBackendProvider.notifier).charger(),
          ),
        ],
      ),
      body: etudiantsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.cyan),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: context.textMuted),
              const SizedBox(height: 12),
              Text('Impossible de charger la classe',
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(classeBackendProvider.notifier).charger(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (etudiants) => etudiants.isEmpty
            ? _EmptyClassView()
            : _ClasseListView(etudiants: etudiants),
      ),
    );
  }
}

// ── Vue classe vide ───────────────────────────────────────────────
class _EmptyClassView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.people_outline,
                color: AppColors.cyan, size: 48),
          ),

          const SizedBox(height: 24),

          Text(
            'Aucun étudiant importé',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importe la liste CSV de ta classe pour\ncréer automatiquement les comptes étudiants.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(importProvider.notifier).choisirFichier(),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: const Text('Importer liste CSV'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _telechargerTemplate(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.borderColor),
              ),
              icon: Icon(Icons.download_outlined,
                  size: 18, color: context.textMuted),
              label: const Text('Télécharger le modèle CSV'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showFormatInfo(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.borderColor),
              ),
              icon: Icon(Icons.info_outline,
                  size: 18, color: context.textMuted),
              label: const Text('Voir le format attendu'),
            ),
          ),

          const SizedBox(height: 32),

          // Format CSV
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_outlined,
                        size: 16, color: AppColors.cyan),
                    const SizedBox(width: 8),
                    Text('Format CSV attendu',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                _CodeLine(
                    'matricule, nom, prenom, email, niveau, formation'),
                const SizedBox(height: 4),
                _CodeLine(
                    '21G0001, DUPONT, Jean, j.dupont@iut.cm, L1, jour'),
                _CodeLine(
                    '21G0002, NGONO, Marie, m.ngono@iut.cm, L1, soir'),
                _CodeLine(
                    '21G0003, BIYA, Paul, p.biya@iut.cm, L2, jour'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 13, color: AppColors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mot de passe généré automatiquement : Edu@matricule',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _telechargerTemplate(BuildContext context) async {
    try {
      const template =
          'matricule,nom,prenom,email,niveau,formation\n'
          '21G0001,DUPONT,Jean,jean.dupont@iut.cm,L1,FI\n'
          '21G0002,NGONO,Marie,marie.ngono@iut.cm,L1,FA\n';
      final dir  = await getExternalStorageDirectory();
      final file = File('${dir!.path}/edunotify_template.csv');
      await file.writeAsString(template);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Template sauvegardé : ${file.path}'),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Erreur lors du téléchargement'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  void _showFormatInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
      context.isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colonnes obligatoires',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 16),
            ...[
              ['matricule', 'Identifiant unique étudiant', AppColors.cyan],
              ['nom',       'Nom de famille en majuscules', AppColors.green],
              ['prenom',    'Prénom',                       AppColors.green],
              ['email',     'Adresse email valide',         AppColors.blue],
              ['niveau',    'L1, L2, L3, M1 ou M2',        AppColors.violet],
              ['formation', 'jour ou soir',                 AppColors.orange],
            ].map((col) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (col[2] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(col[0] as String,
                        style: TextStyle(
                            color: col[2] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Text(col[1] as String,
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Vue liste étudiants (depuis backend) ─────────────────────────
class _ClasseListView extends ConsumerStatefulWidget {
  final List<EtudiantClasse> etudiants;
  const _ClasseListView({required this.etudiants});

  @override
  ConsumerState<_ClasseListView> createState() => _ClasseListViewState();
}

class _ClasseListViewState extends ConsumerState<_ClasseListView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.etudiants
        : widget.etudiants.where((e) =>
    e.nom.toLowerCase().contains(_query) ||
        e.prenom.toLowerCase().contains(_query) ||
        e.matricule.toLowerCase().contains(_query)).toList();

    return Column(
      children: [
        // Stats
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.cyan.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppColors.cyan, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.etudiants.length} étudiant(s)',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'dans ta classe',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              // Bouton importer plus
              GestureDetector(
                onTap: () =>
                    ref.read(importProvider.notifier).choisirFichier(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_outlined,
                          color: AppColors.cyan, size: 14),
                      SizedBox(width: 4),
                      Text('Importer',
                          style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Barre de recherche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher un étudiant...',
              prefixIcon: Icon(Icons.search,
                  color: context.textMuted, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear,
                    color: context.textMuted, size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              )
                  : null,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${filtered.length} résultat(s)',
                style:
                TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Liste
        Expanded(
          child: RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () =>
                ref.read(classeBackendProvider.notifier).charger(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _EtudiantTile(etudiant: filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _EtudiantTile extends StatelessWidget {
  final EtudiantClasse etudiant;
  const _EtudiantTile({required this.etudiant});

  @override
  Widget build(BuildContext context) {
    final initiales =
        '${etudiant.prenom.isNotEmpty ? etudiant.prenom[0] : '?'}'
        '${etudiant.nom.isNotEmpty ? etudiant.nom[0] : '?'}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initiales,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${etudiant.prenom} ${etudiant.nom}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 11, color: context.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      etudiant.matricule,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.email_outlined,
                        size: 11, color: context.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        etudiant.email,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preview CSV ───────────────────────────────────────────────────
class _PreviewScreen extends ConsumerWidget {
  final List<EtudiantCSV> etudiants;
  const _PreviewScreen({required this.etudiants});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valides   = etudiants.where((e) => e.valide).toList();
    final invalides = etudiants.where((e) => !e.valide).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu avant import'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatMini(
                      label: 'Total', value: '${etudiants.length}',
                      color: AppColors.cyan),
                ),
                Container(width: 1, height: 32, color: context.borderColor),
                Expanded(
                  child: _StatMini(
                      label: 'Valides', value: '${valides.length}',
                      color: AppColors.green),
                ),
                Container(width: 1, height: 32, color: context.borderColor),
                Expanded(
                  child: _StatMini(
                      label: 'Erreurs', value: '${invalides.length}',
                      color: invalides.isEmpty
                          ? AppColors.textMuted
                          : AppColors.red),
                ),
              ],
            ),
          ),

          if (invalides.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: AppColors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${invalides.length} ligne(s) ignorée(s). '
                          'Seules les ${valides.length} lignes valides seront importées.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: etudiants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _PreviewTile(etudiant: etudiants[i]),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border(
                  top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(importProvider.notifier).reset(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textSecondary,
                      side: BorderSide(color: context.borderColor),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: valides.isEmpty
                        ? null
                        : () => ref
                        .read(importProvider.notifier)
                        .confirmerImport(ref),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label:
                    Text('Importer ${valides.length} étudiant(s)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final EtudiantCSV etudiant;
  const _PreviewTile({required this.etudiant});

  @override
  Widget build(BuildContext context) {
    final color = etudiant.valide ? AppColors.green : AppColors.red;
    final icon  = etudiant.valide
        ? Icons.check_circle_outline
        : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: etudiant.valide
              ? context.borderColor
              : AppColors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${etudiant.prenom} ${etudiant.nom}',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  etudiant.valide
                      ? '${etudiant.matricule} · ${etudiant.email}'
                      : etudiant.erreur ?? 'Erreur',
                  style: TextStyle(
                    color:    etudiant.valide ? context.textMuted : AppColors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (etudiant.valide)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(etudiant.niveau,
                  style: const TextStyle(
                      color: AppColors.violet,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.cyan, strokeWidth: 3),
            const SizedBox(height: 20),
            Text('Création des comptes en cours...',
                style: TextStyle(
                    color: context.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Les emails seront envoyés automatiquement.',
                style:
                TextStyle(color: context.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Résultat import ───────────────────────────────────────────────
class _ResultScreen extends ConsumerWidget {
  final ImportResult result;
  const _ResultScreen({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final success = result.created > 0;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Résultat de l\'import'),
          automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: success
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: success
                      ? AppColors.green.withValues(alpha: 0.3)
                      : AppColors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: success ? AppColors.green : AppColors.red,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              success ? 'Import réussi !' : 'Import échoué',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  _ResultRow(
                    icon:  Icons.check_circle_outline,
                    label: 'Comptes créés',
                    value: '${result.created}',
                    color: AppColors.green,
                  ),
                  if (result.skipped > 0) ...[
                    Divider(color: context.borderColor, height: 20),
                    _ResultRow(
                      icon:  Icons.skip_next_outlined,
                      label: 'Lignes ignorées',
                      value: '${result.skipped}',
                      color: AppColors.orange,
                    ),
                  ],
                  if (result.created > 0) ...[
                    Divider(color: context.borderColor, height: 20),
                    _ResultRow(
                      icon:  Icons.email_outlined,
                      label: 'Emails envoyés',
                      value: '${result.created}',
                      color: AppColors.cyan,
                    ),
                  ],
                ],
              ),
            ),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Erreurs détectées',
                        style: TextStyle(
                            color: AppColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...result.errors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.red, size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(e,
                                style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(importProvider.notifier).reset(),
                child: const Text('Voir ma classe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────

class _StatMini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatMini(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style:
            TextStyle(color: context.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: context.textSecondary, fontSize: 14)),
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CodeLine extends StatelessWidget {
  final String text;
  const _CodeLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.dark : AppColors.light,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color:      AppColors.cyan,
          fontSize:   11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}