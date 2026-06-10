import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class PublicationResume {
  final String id;
  final String titre;
  final String semestre;
  final DateTime publieLe;
  final int nbNotes;
  final double? moyenne;
  final bool? admis;

  const PublicationResume({
    required this.id,
    required this.titre,
    required this.semestre,
    required this.publieLe,
    required this.nbNotes,
    this.moyenne,
    this.admis,
  });

  factory PublicationResume.fromJson(Map<String, dynamic> j) =>
      PublicationResume(
        id:       j['id']       as String? ?? '',
        titre:    j['titre']    as String? ?? '',
        semestre: j['semestre'] as String? ?? '',
        publieLe: j['publieLe'] != null
            ? DateTime.parse(j['publieLe'] as String)
            : DateTime.now(),
        nbNotes:  j['nbNotes']  as int?    ?? 0,
        moyenne:  (j['moyenne'] as num?)?.toDouble(),
        admis:    j['admis']    as bool?,
      );
}

class NoteDetail {
  final String id;
  final String matiereId;
  final String matiere;
  final int coefficient;
  final double valeur;
  final String mention;

  const NoteDetail({
    required this.id,
    required this.matiereId,
    required this.matiere,
    required this.coefficient,
    required this.valeur,
    required this.mention,
  });

  factory NoteDetail.fromJson(Map<String, dynamic> j) => NoteDetail(
    id:          j['id']          as String? ?? '',
    matiereId:   j['matiereId']   as String? ?? '',
    matiere:     j['matiere']     as String? ?? '',
    coefficient: j['coefficient'] as int?    ?? 1,
    valeur:      (j['valeur'] as num?)?.toDouble() ?? 0,
    mention:     j['mention']     as String? ?? '',
  );
}

class BulletinPublication {
  final PublicationResume publication;
  final String nom;
  final String prenom;
  final String matricule;
  final String? classe;
  final List<NoteDetail> notes;
  final double? moyenne;
  final String? mention;
  final bool admis;

  const BulletinPublication({
    required this.publication,
    required this.nom,
    required this.prenom,
    required this.matricule,
    this.classe,
    required this.notes,
    this.moyenne,
    this.mention,
    required this.admis,
  });

  factory BulletinPublication.fromJson(Map<String, dynamic> j) {
    final pubMap = j['publication'] as Map<String, dynamic>? ?? {};
    final etMap  = j['etudiant']   as Map<String, dynamic>? ?? {};
    return BulletinPublication(
      publication: PublicationResume(
        id:       pubMap['id']       as String? ?? '',
        titre:    pubMap['titre']    as String? ?? '',
        semestre: pubMap['semestre'] as String? ?? '',
        publieLe: pubMap['publieLe'] != null
            ? DateTime.parse(pubMap['publieLe'] as String)
            : DateTime.now(),
        nbNotes: 0,
      ),
      nom:       etMap['nom']       as String? ?? '',
      prenom:    etMap['prenom']    as String? ?? '',
      matricule: etMap['matricule'] as String? ?? '',
      classe:    etMap['classe']    as String?,
      notes:     (j['notes'] as List<dynamic>? ?? [])
          .map((e) => NoteDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      moyenne: (j['moyenne'] as num?)?.toDouble(),
      mention: j['mention'] as String?,
      admis:   j['admis']   as bool? ?? false,
    );
  }
}

class RequeteNote {
  final String id;
  final String statut;
  final String motif;
  final String? reponse;
  final String matiere;
  final double noteActuelle;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RequeteNote({
    required this.id,
    required this.statut,
    required this.motif,
    this.reponse,
    required this.matiere,
    required this.noteActuelle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RequeteNote.fromJson(Map<String, dynamic> j) => RequeteNote(
    id:           j['id']      as String? ?? '',
    statut:       j['statut']  as String? ?? 'en_attente',
    motif:        j['motif']   as String? ?? '',
    reponse:      j['reponse'] as String?,
    matiere:      j['matiere'] as String? ?? '',
    noteActuelle: (j['noteActuelle'] as num?)?.toDouble() ?? 0,
    createdAt:    j['createdAt'] != null
        ? DateTime.parse(j['createdAt'] as String)
        : DateTime.now(),
    updatedAt:    j['updatedAt'] != null
        ? DateTime.parse(j['updatedAt'] as String)
        : DateTime.now(),
  );
}

class ClasseInfo {
  final String id;
  final String nom;
  final String filiere;
  final String niveau;
  final String formation;
  final String codeGenere;
  final int nbEtudiants;

  const ClasseInfo({
    required this.id,
    required this.nom,
    required this.filiere,
    required this.niveau,
    required this.formation,
    required this.codeGenere,
    required this.nbEtudiants,
  });

  factory ClasseInfo.fromJson(Map<String, dynamic> j) => ClasseInfo(
    id:          j['id']          as String? ?? '',
    nom:         j['nom']         as String? ?? '',
    filiere:     j['filiere']     as String? ?? '',
    niveau:      j['niveau']      as String? ?? '',
    formation:   j['formation']   as String? ?? '',
    codeGenere:  j['codeGenere']  as String? ?? '',
    nbEtudiants: j['nbEtudiants'] as int?    ?? 0,
  );

  String get label => '$filiere · $niveau · $formation';
}

// ══════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════

// Badge notes étudiant
final notesBadgeProvider =
StateNotifierProvider<NotesBadgeNotifier, int>((_) => NotesBadgeNotifier());

class NotesBadgeNotifier extends StateNotifier<int> {
  NotesBadgeNotifier() : super(0);
  DateTime? _derniereConsultation;

  Future<void> charger(String userId, String role) async {
    try {
      final params = _derniereConsultation != null
          ? {'depuis': _derniereConsultation!.toIso8601String()}
          : <String, dynamic>{};
      final resp = await ApiClient.getAcademic(
        '/academic/badge',
        userId: userId, role: role, params: params,
      );
      state = resp['count'] as int? ?? 0;
    } catch (_) {}
  }

  void marquerConsulte() {
    _derniereConsultation = DateTime.now();
    state = 0;
  }
}

// Publications étudiant
final mesPublicationsProvider = StateNotifierProvider<
    MesPublicationsNotifier, AsyncValue<List<PublicationResume>>>(
        (_) => MesPublicationsNotifier());

class MesPublicationsNotifier
    extends StateNotifier<AsyncValue<List<PublicationResume>>> {
  MesPublicationsNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getAcademic(
        '/academic/mes-publications', userId: userId, role: role,
      );
      final liste = (resp['publications'] as List<dynamic>? ?? [])
          .map((e) => PublicationResume.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(liste);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Bulletin d'une publication
final bulletinPublicationProvider = StateNotifierProvider.family<
    BulletinPublicationNotifier,
    AsyncValue<BulletinPublication>,
    String>((_, id) => BulletinPublicationNotifier(id));

class BulletinPublicationNotifier
    extends StateNotifier<AsyncValue<BulletinPublication>> {
  final String publicationId;
  BulletinPublicationNotifier(this.publicationId)
      : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getAcademic(
        '/academic/publications/$publicationId/bulletin',
        userId: userId, role: role,
      );
      state = AsyncValue.data(BulletinPublication.fromJson(resp));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Requêtes étudiant
final mesRequetesProvider = StateNotifierProvider<
    MesRequetesNotifier, AsyncValue<List<RequeteNote>>>(
        (_) => MesRequetesNotifier());

class MesRequetesNotifier
    extends StateNotifier<AsyncValue<List<RequeteNote>>> {
  MesRequetesNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getAcademic(
        '/academic/requetes/mes-requetes', userId: userId, role: role,
      );
      final liste = (resp['requetes'] as List<dynamic>? ?? [])
          .map((e) => RequeteNote.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(liste);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void ajouter(RequeteNote r) {
    final actuel = state.valueOrNull ?? [];
    state = AsyncValue.data([r, ...actuel]);
  }
}

// Classes chef
final mesClassesProvider = StateNotifierProvider<
    MesClassesNotifier, AsyncValue<Map<String, List<ClasseInfo>>>>(
        (_) => MesClassesNotifier());

class MesClassesNotifier
    extends StateNotifier<AsyncValue<Map<String, List<ClasseInfo>>>> {
  MesClassesNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getAcademic(
        '/academic/mes-classes', userId: userId, role: role,
      );
      final raw    = resp['filieres'] as Map<String, dynamic>? ?? {};
      final result = <String, List<ClasseInfo>>{};
      for (final e in raw.entries) {
        result[e.key] = (e.value as List<dynamic>)
            .map((x) => ClasseInfo.fromJson(x as Map<String, dynamic>))
            .toList();
      }
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Requêtes chef
final requetesChefProvider = StateNotifierProvider<
    RequetesChefNotifier, AsyncValue<List<Map<String, dynamic>>>>(
        (_) => RequetesChefNotifier());

class RequetesChefNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  RequetesChefNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getAcademic(
        '/academic/requetes', userId: userId, role: role,
      );
      state = AsyncValue.data(
          (resp['requetes'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void traiter(String id, String statut) {
    final actuel = state.valueOrNull ?? [];
    state = AsyncValue.data(actuel
        .map((r) => r['id'] == id ? {...r, 'statut': statut} : r)
        .toList());
  }
}

// ══════════════════════════════════════════════════════════════════
// ROUTER
// ══════════════════════════════════════════════════════════════════

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role ?? 'etudiant';
    if (role == 'chef_departement' || role == 'admin') {
      return const _NotesChef();
    }
    return const _NotesEtudiant();
  }
}

// ══════════════════════════════════════════════════════════════════
// VUE ÉTUDIANT — Liste des publications
// ══════════════════════════════════════════════════════════════════

class _NotesEtudiant extends ConsumerStatefulWidget {
  const _NotesEtudiant();

  @override
  ConsumerState<_NotesEtudiant> createState() => _NotesEtudiantState();
}

class _NotesEtudiantState extends ConsumerState<_NotesEtudiant>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _charger() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(mesPublicationsProvider.notifier).charger(user.id, user.role);
    ref.read(mesRequetesProvider.notifier).charger(user.id, user.role);
    // Marquer comme consulté pour le badge
    ref.read(notesBadgeProvider.notifier).marquerConsulte();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes notes'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_outlined), onPressed: _charger),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Mes résultats'),
            Tab(text: 'Mes requêtes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PublicationsEtudiantTab(),
          _RequetesEtudiantTab(),
        ],
      ),
    );
  }
}

// ── Liste des publications ────────────────────────────────────────
class _PublicationsEtudiantTab extends ConsumerWidget {
  const _PublicationsEtudiantTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubs = ref.watch(mesPublicationsProvider);

    return pubs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErreurView(
        message: 'Impossible de charger les résultats',
        onRetry: () {
          final user = ref.read(currentUserProvider);
          if (user != null)
            ref.read(mesPublicationsProvider.notifier).charger(user.id, user.role);
        },
      ),
      data: (liste) {
        if (liste.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: context.textMuted),
                const SizedBox(height: 16),
                Text('Aucun résultat publié',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Vos résultats apparaîtront ici\ndès que le chef de département les publiera.',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Grouper par semestre
        final groupes = <String, List<PublicationResume>>{};
        for (final p in liste) {
          groupes.putIfAbsent(p.semestre, () => []).add(p);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: groupes.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value.length} publication(s)',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                ...entry.value
                    .map((p) => _PublicationCard(pub: p))
                    .toList(),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Carte publication ─────────────────────────────────────────────
class _PublicationCard extends ConsumerWidget {
  final PublicationResume pub;
  const _PublicationCard({required this.pub});

  Color get _couleurMoy {
    if (pub.moyenne == null) return AppColors.cyan;
    if (pub.moyenne! >= 14) return AppColors.green;
    if (pub.moyenne! >= 10) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = pub.publieLe;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _BulletinDetailScreen(publication: pub),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // En-tête coloré
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _couleurMoy.withValues(alpha: 0.15),
                    _couleurMoy.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color:        _couleurMoy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_rounded,
                        color: _couleurMoy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pub.titre,
                          style: TextStyle(
                            color:      context.textPrimary,
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Publié le $dateStr · ${pub.nbNotes} matière(s)',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),

            // Moyenne
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  if (pub.moyenne != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Votre moyenne',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          pub.moyenne!.toStringAsFixed(2),
                          style: TextStyle(
                            color:      _couleurMoy,
                            fontSize:   24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (pub.admis != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (pub.admis! ? AppColors.green : AppColors.red)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pub.admis!
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: pub.admis! ? AppColors.green : AppColors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pub.admis! ? 'Admis' : 'Non admis',
                            style: TextStyle(
                              color: pub.admis!
                                  ? AppColors.green
                                  : AppColors.red,
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text('Voir le détail',
                      style: TextStyle(
                          color:      _couleurMoy,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN DÉTAIL BULLETIN
// ══════════════════════════════════════════════════════════════════

class _BulletinDetailScreen extends ConsumerStatefulWidget {
  final PublicationResume publication;
  const _BulletinDetailScreen({required this.publication});

  @override
  ConsumerState<_BulletinDetailScreen> createState() =>
      _BulletinDetailScreenState();
}

class _BulletinDetailScreenState
    extends ConsumerState<_BulletinDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref
            .read(bulletinPublicationProvider(widget.publication.id).notifier)
            .charger(user.id, user.role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bulletin =
    ref.watch(bulletinPublicationProvider(widget.publication.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.publication.titre, maxLines: 1,
          overflow: TextOverflow.ellipsis)),
      body: bulletin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErreurView(
          message: 'Impossible de charger ce bulletin',
          onRetry: () {
            final user = ref.read(currentUserProvider);
            if (user != null) {
              ref
                  .read(bulletinPublicationProvider(widget.publication.id)
                  .notifier)
                  .charger(user.id, user.role);
            }
          },
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Carte moyenne
              if (data.moyenne != null)
                _MoyenneCard(
                  moyenne: data.moyenne!,
                  mention: data.mention ?? '',
                  admis:   data.admis,
                  titre:   data.publication.titre,
                  semestre: data.publication.semestre,
                ),

              const SizedBox(height: 16),

              // Infos étudiant
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        context.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset:     const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        color: context.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${data.prenom} ${data.nom}  •  ${data.matricule}',
                        style: TextStyle(
                            color: context.textSecondary, fontSize: 13),
                      ),
                    ),
                    if (data.classe != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(data.classe!,
                            style: const TextStyle(
                                color:      AppColors.cyan,
                                fontSize:   11,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // En-tête liste notes
              Row(
                children: [
                  Text('Notes par matière',
                      style: TextStyle(
                          color:      context.textPrimary,
                          fontSize:   16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${data.notes.length} matière(s)',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),

              ...data.notes.map((n) => _NoteTile(note: n)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte moyenne ─────────────────────────────────────────────────
class _MoyenneCard extends StatelessWidget {
  final double moyenne;
  final String mention;
  final bool admis;
  final String titre;
  final String semestre;

  const _MoyenneCard({
    required this.moyenne,
    required this.mention,
    required this.admis,
    required this.titre,
    required this.semestre,
  });

  Color get _couleur {
    if (moyenne >= 14) return AppColors.green;
    if (moyenne >= 10) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_couleur, _couleur.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      _couleur.withValues(alpha: 0.3),
            blurRadius: 16,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Moyenne générale',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                moyenne.toStringAsFixed(2),
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(mention,
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(semestre,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color:  Colors.white.withValues(alpha: 0.2),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2),
                ),
                child: Icon(
                  admis ? Icons.emoji_events_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size:  28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                admis ? 'Admis ✓' : 'Non admis',
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Note tile avec bouton requête ─────────────────────────────────
class _NoteTile extends ConsumerWidget {
  final NoteDetail note;
  const _NoteTile({required this.note});

  Color get _couleur {
    if (note.valeur >= 14) return AppColors.green;
    if (note.valeur >= 10) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color:        _couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                note.valeur.toStringAsFixed(1),
                style: TextStyle(
                  color:      _couleur,
                  fontSize:   16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.matiere,
                    style: TextStyle(
                        color:      context.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Coeff. ${note.coefficient}',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 11)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        _couleur.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(note.mention,
                          style: TextStyle(
                              color:      _couleur,
                              fontSize:   10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _RequeteModal(note: note),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded,
                      color: AppColors.orange, size: 13),
                  SizedBox(width: 4),
                  Text('Requête',
                      style: TextStyle(
                          color:      AppColors.orange,
                          fontSize:   11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal requête étudiant ────────────────────────────────────────
class _RequeteModal extends ConsumerStatefulWidget {
  final NoteDetail note;
  const _RequeteModal({required this.note});

  @override
  ConsumerState<_RequeteModal> createState() => _RequeteModalState();
}

class _RequeteModalState extends ConsumerState<_RequeteModal> {
  final _motifCtrl = TextEditingController();
  bool    _loading = false;
  String? _erreur;

  @override
  void dispose() { _motifCtrl.dispose(); super.dispose(); }

  Future<void> _soumettre() async {
    if (_motifCtrl.text.trim().length < 10) {
      setState(() => _erreur = 'Décrivez le problème en au moins 10 caractères');
      return;
    }
    setState(() { _loading = true; _erreur = null; });
    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.postAcademic(
        '/academic/requetes',
        data:   {'noteId': widget.note.id, 'motif': _motifCtrl.text.trim()},
        userId: user.id, role: user.role,
      );
      final r = resp['requete'] as Map<String, dynamic>;
      ref.read(mesRequetesProvider.notifier).ajouter(RequeteNote(
        id: r['id'] as String? ?? '', statut: r['statut'] as String? ?? 'en_attente',
        motif: r['motif'] as String? ?? '', matiere: widget.note.matiere,
        noteActuelle: widget.note.valeur, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Requête soumise avec succès'),
          backgroundColor: AppColors.green,
        ));
      }
    } on ApiException catch (e) {
      setState(() { _loading = false; _erreur = e.message; });
    } catch (_) {
      setState(() { _loading = false; _erreur = 'Erreur de connexion'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.borderColor,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Soumettre une requête',
              style: TextStyle(color: context.textPrimary,
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.grade_rounded,
                    color: AppColors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.note.matiere,
                    style: TextStyle(color: context.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600))),
                Text('${widget.note.valeur}/20',
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Décrivez le problème',
              style: TextStyle(color: context.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _motifCtrl, maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ex: Ma note de TP n\'a pas été prise en compte...',
              hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 8),
            Text(_erreur!, style: const TextStyle(
                color: AppColors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _soumettre,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Envoyer la requête'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet requêtes étudiant ──────────────────────────────────────
class _RequetesEtudiantTab extends ConsumerWidget {
  const _RequetesEtudiantTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requetes = ref.watch(mesRequetesProvider);
    return requetes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErreurView(
        message: 'Impossible de charger les requêtes',
        onRetry: () {
          final user = ref.read(currentUserProvider);
          if (user != null)
            ref.read(mesRequetesProvider.notifier).charger(user.id, user.role);
        },
      ),
      data: (liste) {
        if (liste.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: context.textMuted),
                const SizedBox(height: 16),
                Text('Aucune requête soumise',
                    style: TextStyle(color: context.textMuted, fontSize: 14)),
                const SizedBox(height: 8),
                Text('Ouvrez un bulletin et appuyez sur\n"Requête" sur une note pour signaler une erreur.',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: liste.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RequeteTileEtudiant(r: liste[i]),
        );
      },
    );
  }
}

class _RequeteTileEtudiant extends StatelessWidget {
  final RequeteNote r;
  const _RequeteTileEtudiant({required this.r});

  @override
  Widget build(BuildContext context) {
    final color = r.statut == 'en_attente' ? AppColors.orange
        : r.statut == 'traitee' ? AppColors.green : AppColors.red;
    final label = r.statut == 'en_attente' ? 'En attente'
        : r.statut == 'traitee' ? 'Traitée' : 'Rejetée';
    final icon = r.statut == 'en_attente' ? Icons.hourglass_empty_rounded
        : r.statut == 'traitee' ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: r.statut == 'en_attente'
              ? context.borderColor
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.matiere,
                  style: TextStyle(color: context.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 12),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: color,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Note concernée : ${r.noteActuelle}/20',
              style: TextStyle(color: context.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(r.motif, style: TextStyle(
              color: context.textSecondary, fontSize: 12, height: 1.4)),
          if (r.reponse != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Réponse du chef',
                      style: TextStyle(color: color,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(r.reponse!, style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// VUE CHEF — Import + Publications + Requêtes
// ══════════════════════════════════════════════════════════════════

class _NotesChef extends ConsumerStatefulWidget {
  const _NotesChef();

  @override
  ConsumerState<_NotesChef> createState() => _NotesChefState();
}

class _NotesChefState extends ConsumerState<_NotesChef>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _charger() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(mesClassesProvider.notifier).charger(user.id, user.role);
    ref.read(requetesChefProvider.notifier).charger(user.id, user.role);
  }

  @override
  Widget build(BuildContext context) {
    final requetes   = ref.watch(requetesChefProvider);
    final nbEnAttente = requetes.valueOrNull
        ?.where((r) => r['statut'] == 'en_attente').length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des notes'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_outlined), onPressed: _charger),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Publier des notes'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requêtes'),
                  if (nbEnAttente > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color:        AppColors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$nbEnAttente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ImportNotesTab(), _RequetesChefTab()],
      ),
    );
  }
}

// ── Import notes ──────────────────────────────────────────────────
class _ImportNotesTab extends ConsumerStatefulWidget {
  const _ImportNotesTab();

  @override
  ConsumerState<_ImportNotesTab> createState() => _ImportNotesTabState();
}

class _ImportNotesTabState extends ConsumerState<_ImportNotesTab> {
  String?     _filiereSelectionnee;
  ClasseInfo? _classeSelectionnee;
  PlatformFile? _fichier;

  final _titreCtrl = TextEditingController();
  String  _semestre = 'Semestre 1';
  bool    _publier  = false;
  bool    _loading  = false;
  String? _erreur;
  String? _succes;

  // Historique publications pour la classe sélectionnée
  List<Map<String, dynamic>> _historique = [];
  bool _historiqueLoading = false;

  static const _semestres = ['Semestre 1', 'Semestre 2'];

  @override
  void dispose() { _titreCtrl.dispose(); super.dispose(); }

  Future<void> _choisirFichier() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fichier = result.files.first; _succes = null; _erreur = null; });
    }
  }

  Future<void> _chargerHistorique(String classeId) async {
    setState(() => _historiqueLoading = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.getAcademic(
        '/academic/classes/$classeId/publications',
        userId: user.id, role: user.role,
      );
      setState(() {
        _historique        = (resp['publications'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _historiqueLoading = false;
      });
    } catch (_) {
      setState(() => _historiqueLoading = false);
    }
  }

  Future<void> _importer() async {
    if (_classeSelectionnee == null) {
      setState(() => _erreur = 'Sélectionnez une classe');
      return;
    }
    if (_titreCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Donnez un titre à cette publication');
      return;
    }
    if (_fichier == null || _fichier!.bytes == null) {
      setState(() => _erreur = 'Sélectionnez un fichier Excel');
      return;
    }

    setState(() { _loading = true; _erreur = null; _succes = null; });

    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.postAcademicFormData(
        '/academic/import',
        fileBytes: _fichier!.bytes!,
        filename:  _fichier!.name,
        fields: {
          'classeId': _classeSelectionnee!.id,
          'titre':    _titreCtrl.text.trim(),
          'semestre': _semestre,
          'publier':  _publier.toString(),
        },
        userId: user.id, role: user.role,
      );
      setState(() {
        _loading = false;
        _succes  = '${resp['message']} — "${_titreCtrl.text.trim()}"';
        _fichier = null;
        _titreCtrl.clear();
      });
      // Recharger l'historique
      await _chargerHistorique(_classeSelectionnee!.id);
    } on ApiException catch (e) {
      setState(() { _loading = false; _erreur = e.message; });
    } catch (e) {
      setState(() { _loading = false; _erreur = 'Erreur : ${e.toString()}'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(mesClassesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Info format ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.cyan, size: 16),
                    SizedBox(width: 8),
                    Text('Format du fichier Excel',
                        style: TextStyle(color: AppColors.cyan,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Col. A : Matricule  |  Col. B : Nom  |  Col. C : Prénom\n'
                      'Colonnes suivantes : une colonne par matière\n'
                      'Notes sur 20',
                  style: TextStyle(color: context.textSecondary,
                      fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Sélecteur filière / classe ───────────────────────
          Text('Filière et classe',
              style: TextStyle(color: context.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          classesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => Text('Impossible de charger les classes',
                style: const TextStyle(color: AppColors.red, fontSize: 12)),
            data: (filieres) {
              if (filieres.isEmpty) {
                return Text('Aucune classe dans votre département',
                    style: TextStyle(color: context.textMuted));
              }
              final filiereNoms = filieres.keys.toList()..sort();
              return Column(
                children: [
                  // Filière
                  _DropdownContainer(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:       _filiereSelectionnee,
                        isExpanded:  true,
                        hint:        Text('Choisir une filière',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 14)),
                        dropdownColor: context.cardColor,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: context.textMuted),
                        items: filiereNoms.map((f) => DropdownMenuItem(
                          value: f,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.violet.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(f, style: const TextStyle(
                                    color:      AppColors.violet,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              Text('${filieres[f]!.length} classe(s)',
                                  style: TextStyle(
                                      color: context.textMuted, fontSize: 12)),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() {
                          _filiereSelectionnee = v;
                          _classeSelectionnee  = null;
                          _historique          = [];
                        }),
                      ),
                    ),
                  ),

                  // Niveau
                  if (_filiereSelectionnee != null) ...[
                    const SizedBox(height: 10),
                    _DropdownContainer(
                      highlight: _classeSelectionnee != null,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ClasseInfo>(
                          value:       _classeSelectionnee,
                          isExpanded:  true,
                          hint:        Text('Choisir un niveau',
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 14)),
                          dropdownColor: context.cardColor,
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: context.textMuted),
                          items: (filieres[_filiereSelectionnee] ?? [])
                              .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Text(c.label,
                                    style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 14)),
                                const Spacer(),
                                Text('${c.nbEtudiants} étudiants',
                                    style: TextStyle(
                                        color: context.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                          )).toList(),
                          onChanged: (v) {
                            setState(() { _classeSelectionnee = v; });
                            if (v != null) _chargerHistorique(v.id);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Titre publication ────────────────────────────────
          Text('Titre de la publication',
              style: TextStyle(color: context.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _titreCtrl,
            decoration: InputDecoration(
              hintText: 'Ex: Résultats examens session normale S1',
              prefixIcon: Icon(Icons.assignment_rounded,
                  color: context.textMuted, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // ── Semestre ─────────────────────────────────────────
          Text('Semestre',
              style: TextStyle(color: context.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: _semestres.map((s) {
              final selected = _semestre == s;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _semestre = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: s == _semestres.first ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.violet : context.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.violet
                            : context.borderColor,
                      ),
                    ),
                    child: Text(s,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : context.textSecondary,
                          fontSize:   13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Toggle publier ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Publier immédiatement',
                          style: TextStyle(color: context.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Les étudiants verront les notes après publication',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value:     _publier,
                  onChanged: (v) => setState(() => _publier = v),
                  activeColor: AppColors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Fichier sélectionné ──────────────────────────────
          if (_fichier != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                    color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: AppColors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_fichier!.name,
                      style: TextStyle(
                          color: context.textPrimary, fontSize: 13))),
                  GestureDetector(
                    onTap: () => setState(() => _fichier = null),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.red, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Boutons ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _choisirFichier,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cyan,
                side: const BorderSide(color: AppColors.cyan),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(_fichier == null
                  ? 'Choisir un fichier Excel'
                  : 'Changer de fichier'),
            ),
          ),

          if (_fichier != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _importer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, size: 20),
                label: const Text('Importer et publier'),
              ),
            ),
          ],

          // ── Messages ─────────────────────────────────────────
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            _MessageBanner(message: _erreur!, isSuccess: false),
          ],
          if (_succes != null) ...[
            const SizedBox(height: 12),
            _MessageBanner(message: _succes!, isSuccess: true),
          ],

          // ── Historique publications ──────────────────────────
          if (_classeSelectionnee != null) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Text('Publications de ${_classeSelectionnee!.codeGenere}',
                    style: TextStyle(color: context.textPrimary,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_historiqueLoading)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),

            if (_historique.isEmpty && !_historiqueLoading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: context.borderColor),
                ),
                child: Text('Aucune publication pour cette classe',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 13)),
              )
            else
              ..._historique.map((p) => _HistoriquePubTile(pub: p)).toList(),
          ],
        ],
      ),
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  final Widget child;
  final bool highlight;
  const _DropdownContainer({required this.child, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: highlight
              ? AppColors.green.withValues(alpha: 0.4)
              : context.borderColor,
        ),
      ),
      child: child,
    );
  }
}

class _HistoriquePubTile extends StatelessWidget {
  final Map<String, dynamic> pub;
  const _HistoriquePubTile({required this.pub});

  @override
  Widget build(BuildContext context) {
    final publieLe = pub['publieLe'] != null
        ? DateTime.parse(pub['publieLe'] as String)
        : DateTime.now();
    final d = publieLe;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded,
                color: AppColors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pub['titre'] as String? ?? '',
                    style: TextStyle(color: context.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${pub['semestre']} · Publié le $dateStr · ${pub['nbNotes']} notes',
                    style: TextStyle(color: context.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Publié',
                style: TextStyle(color: AppColors.green,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;
  const _MessageBanner({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

// ── Requêtes chef ─────────────────────────────────────────────────
class _RequetesChefTab extends ConsumerWidget {
  const _RequetesChefTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requetes = ref.watch(requetesChefProvider);
    return requetes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _ErreurView(
        message: 'Impossible de charger les requêtes',
        onRetry: () {
          final user = ref.read(currentUserProvider);
          if (user != null)
            ref.read(requetesChefProvider.notifier).charger(user.id, user.role);
        },
      ),
      data: (liste) {
        final enAttente = liste.where((r) => r['statut'] == 'en_attente').toList();
        final traitees  = liste.where((r) => r['statut'] != 'en_attente').toList();

        if (liste.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: context.textMuted),
                const SizedBox(height: 16),
                Text('Aucune requête reçue',
                    style: TextStyle(color: context.textMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (enAttente.isNotEmpty) ...[
              _SectionHeader('⏳ En attente (${enAttente.length})', AppColors.orange),
              const SizedBox(height: 10),
              ...enAttente.map((r) => _RequeteTileChef(requete: r)),
              const SizedBox(height: 16),
            ],
            if (traitees.isNotEmpty) ...[
              _SectionHeader('✅ Traitées (${traitees.length})', AppColors.green),
              const SizedBox(height: 10),
              ...traitees.map((r) => _RequeteTileChef(requete: r)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titre;
  final Color color;
  const _SectionHeader(this.titre, this.color);

  @override
  Widget build(BuildContext context) => Text(titre,
      style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700));
}

class _RequeteTileChef extends ConsumerWidget {
  final Map<String, dynamic> requete;
  const _RequeteTileChef({required this.requete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statut    = requete['statut'] as String? ?? 'en_attente';
    final enAttente = statut == 'en_attente';
    final etudiant  = requete['etudiant'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: enAttente
              ? AppColors.orange.withValues(alpha: 0.3)
              : context.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${etudiant['prenom'] ?? ''} ${etudiant['nom'] ?? ''}',
                        style: TextStyle(color: context.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(etudiant['matricule'] as String? ?? '',
                        style: TextStyle(color: context.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (enAttente)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _TraiterRequeteModal(
                      requeteId:   requete['id']     as String? ?? '',
                      etudiantNom: '${etudiant['prenom'] ?? ''} ${etudiant['nom'] ?? ''}',
                      matiere:     requete['matiere']      as String? ?? '',
                      motif:       requete['motif']        as String? ?? '',
                      note: (requete['noteActuelle'] as num?)?.toDouble() ?? 0,
                      onTraite: (s) => ref.read(requetesChefProvider.notifier)
                          .traiter(requete['id'] as String? ?? '', s),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:        AppColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(
                          color: AppColors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Traiter',
                        style: TextStyle(color: AppColors.orange,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.grade_rounded, size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Text('${requete['matiere'] ?? ''} — ${requete['noteActuelle'] ?? ''}/20',
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(requete['motif'] as String? ?? '',
              style: TextStyle(color: context.textSecondary,
                  fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Modal traiter requête chef ────────────────────────────────────
class _TraiterRequeteModal extends ConsumerStatefulWidget {
  final String requeteId, etudiantNom, matiere, motif;
  final double note;
  final void Function(String) onTraite;

  const _TraiterRequeteModal({
    required this.requeteId, required this.etudiantNom,
    required this.matiere,   required this.motif,
    required this.note,      required this.onTraite,
  });

  @override
  ConsumerState<_TraiterRequeteModal> createState() =>
      _TraiterRequeteModalState();
}

class _TraiterRequeteModalState extends ConsumerState<_TraiterRequeteModal> {
  final _reponseCtrl      = TextEditingController();
  final _nouvelleNoteCtrl = TextEditingController();
  bool    _loading  = false;
  String? _erreur;
  bool    _corriger = false;

  @override
  void dispose() { _reponseCtrl.dispose(); _nouvelleNoteCtrl.dispose(); super.dispose(); }

  Future<void> _traiter(String statut) async {
    if (_reponseCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Une réponse est obligatoire');
      return;
    }
    setState(() { _loading = true; _erreur = null; });
    try {
      final user = ref.read(currentUserProvider)!;
      final body = <String, dynamic>{
        'statut': statut, 'reponse': _reponseCtrl.text.trim(),
      };
      if (_corriger && _nouvelleNoteCtrl.text.trim().isNotEmpty)
        body['nouvelleNote'] = double.tryParse(_nouvelleNoteCtrl.text.trim());

      await ApiClient.patchAcademic(
        '/academic/requetes/${widget.requeteId}',
        data: body, userId: user.id, role: user.role,
      );
      widget.onTraite(statut);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(statut == 'traitee'
              ? 'Traitée — email envoyé à l\'étudiant'
              : 'Rejetée — email envoyé à l\'étudiant'),
          backgroundColor:
          statut == 'traitee' ? AppColors.green : AppColors.red,
        ));
      }
    } on ApiException catch (e) {
      setState(() { _loading = false; _erreur = e.message; });
    } catch (_) {
      setState(() { _loading = false; _erreur = 'Erreur de connexion'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Traiter la requête',
                style: TextStyle(color: context.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.etudiantNom,
                style: TextStyle(color: context.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.matiere} — ${widget.note}/20',
                      style: TextStyle(color: context.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(widget.motif, style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _corriger,
                  onChanged: (v) => setState(() => _corriger = v ?? false),
                  activeColor: AppColors.cyan,
                ),
                Text('Corriger la note',
                    style: TextStyle(color: context.textSecondary, fontSize: 13)),
              ],
            ),
            if (_corriger) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _nouvelleNoteCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Nouvelle note (0-20)',
                  prefixIcon: Icon(Icons.edit_rounded,
                      color: context.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Votre réponse',
                style: TextStyle(color: context.textSecondary,
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _reponseCtrl, maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ce message sera envoyé par email à l\'étudiant.',
                hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(
                  color: AppColors.red, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _traiter('rejetee'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                    ),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('Rejeter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _traiter('traitee'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white),
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGET ERREUR
// ══════════════════════════════════════════════════════════════════

class _ErreurView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErreurView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: context.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}