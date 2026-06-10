import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class EtudiantPresent {
  final String matricule;
  final String nom;
  final String prenom;
  final DateTime? confirmedAt;
  final String methode;

  const EtudiantPresent({
    required this.matricule,
    required this.nom,
    required this.prenom,
    this.confirmedAt,
    this.methode = 'code_session',
  });

  factory EtudiantPresent.fromJson(Map<String, dynamic> j) {
    // Le backend retourne confirmeA (pas confirmedAt)
    final dateStr = (j['confirmeA'] ?? j['confirmedAt']) as String?;
    return EtudiantPresent(
      matricule:   j['matricule'] as String? ?? '',
      nom:         j['nom']      as String? ?? '',
      prenom:      j['prenom']   as String? ?? '',
      confirmedAt: dateStr != null ? DateTime.parse(dateStr) : null,
      methode:     j['methode']  as String? ?? 'code_session',
    );
  }
}

class EtudiantAbsent {
  final String matricule;
  final String nom;
  final String prenom;

  const EtudiantAbsent({
    required this.matricule,
    required this.nom,
    required this.prenom,
  });

  factory EtudiantAbsent.fromJson(Map<String, dynamic> j) {
    return EtudiantAbsent(
      matricule: j['matricule'] as String? ?? '',
      nom:       j['nom']      as String? ?? '',
      prenom:    j['prenom']   as String? ?? '',
    );
  }
}

class SessionArchive {
  final String id;
  final String matiere;
  final String professeur;
  final String salle;
  final String type;
  final DateTime debutLe;
  final DateTime finLe;
  final List<EtudiantPresent> presents;
  final List<EtudiantAbsent> absents;
  // Valeurs réelles du backend pour la vue liste (avant chargement du détail)
  final int? nbPresentsReel;
  final int? nbTotalReel;

  const SessionArchive({
    required this.id,
    required this.matiere,
    required this.professeur,
    required this.salle,
    required this.type,
    required this.debutLe,
    required this.finLe,
    required this.presents,
    required this.absents,
    this.nbPresentsReel,
    this.nbTotalReel,
  });

  // Utilise les valeurs réelles si disponibles, sinon compte les listes
  int get total      => nbTotalReel   ?? (presents.length + absents.length);
  int get nbPresents => nbPresentsReel ?? presents.where((e) => e.matricule.isNotEmpty).length;
  int get nbAbsents  => total - nbPresents;
  double get tauxPresence =>
      total == 0 ? 0 : (nbPresents / total * 100);
  Duration get duree => finLe.difference(debutLe);
  String get dureeLabel {
    final m = duree.inMinutes;
    if (m < 60) return '${m}min';
    return '${duree.inHours}h${(m % 60).toString().padLeft(2, '0')}';
  }

  factory SessionArchive.fromJson(Map<String, dynamic> j) {
    // Listes détaillées (disponibles après fermeture ou GET detail)
    final presentsList = (j['presents'] as List<dynamic>? ?? [])
        .map((e) => EtudiantPresent.fromJson(e as Map<String, dynamic>))
        .toList();
    final absentsList = (j['absents'] as List<dynamic>? ?? [])
        .map((e) => EtudiantAbsent.fromJson(e as Map<String, dynamic>))
        .toList();

    // Le backend retourne ouverteLe/fermeeLe
    final debutStr = (j['debutLe'] ?? j['ouverteLe']) as String?;
    final finStr   = (j['finLe']   ?? j['fermeeLe'])  as String?;

    // Valeurs réelles du backend pour la vue liste
    final nbPres  = j['nbPresents'] as int?;
    final nbTotal = j['nbTotal']    as int?;

    return SessionArchive(
      id:             j['id']         as String? ?? '',
      matiere:        j['matiere']    as String? ?? '',
      professeur:     j['professeur'] as String? ?? '',
      salle:          j['salle']      as String? ?? '',
      type:           j['type']       as String? ?? '',
      debutLe:        debutStr != null ? DateTime.parse(debutStr) : DateTime.now(),
      finLe:          finStr   != null ? DateTime.parse(finStr)   : DateTime.now(),
      presents:       presentsList,
      absents:        absentsList,
      // Stocker les compteurs réels pour affichage correct dans la liste
      nbPresentsReel: nbPres,
      nbTotalReel:    nbTotal,
    );
  }

  // Utilisé pour ajouter localement après fermeture de session
  SessionArchive copyWithLists({
    List<EtudiantPresent>? presents,
    List<EtudiantAbsent>? absents,
  }) {
    return SessionArchive(
      id:              id,
      matiere:         matiere,
      professeur:      professeur,
      salle:           salle,
      type:            type,
      debutLe:         debutLe,
      finLe:           finLe,
      presents:        presents ?? this.presents,
      absents:         absents  ?? this.absents,
      nbPresentsReel:  null, // reset car on a les vraies listes
      nbTotalReel:     null,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER HISTORIQUE — données réelles
// ══════════════════════════════════════════════════════════════════

final archivesProvider =
StateNotifierProvider<ArchivesNotifier, List<SessionArchive>>(
      (ref) => ArchivesNotifier(ref),
);

class ArchivesNotifier extends StateNotifier<List<SessionArchive>> {
  final Ref _ref;
  bool _loaded = false;

  ArchivesNotifier(this._ref) : super([]);

  /// Charge l'historique depuis le backend (presence-service)
  Future<void> charger() async {
    if (_loaded) return;
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    if (user.classeId == null || user.classeId!.isEmpty) return;

    try {
      final resp = await ApiClient.getPresence(
        '/presence/sessions/historique',
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      final liste = (resp['sessions'] as List<dynamic>? ?? [])
          .map((e) => SessionArchive.fromJson(e as Map<String, dynamic>))
          .toList();

      state   = liste;
      _loaded = true;
    } catch (_) {
      // En cas d'erreur réseau on garde la liste vide
    }
  }

  /// Ajoute une session locale juste après fermeture (avant rechargement)
  void ajouter(SessionArchive archive) {
    state = [archive, ...state];
  }

  /// Force le rechargement au prochain appel
  void invalider() => _loaded = false;
}

// ══════════════════════════════════════════════════════════════════
// GÉNÉRATION PDF
// ══════════════════════════════════════════════════════════════════

Future<Uint8List> genererPdfPresence(SessionArchive a) async {
  final pdf = pw.Document();

  final dateStr =
      '${a.debutLe.day.toString().padLeft(2, '0')}/'
      '${a.debutLe.month.toString().padLeft(2, '0')}/'
      '${a.debutLe.year}  '
      '${a.debutLe.hour.toString().padLeft(2, '0')}:'
      '${a.debutLe.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('EduNotify',
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange700)),
              pw.Text('Rapport de présence',
                  style: pw.TextStyle(
                      fontSize: 13, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(color: PdfColors.orange200, thickness: 1.5),
          pw.SizedBox(height: 6),
        ],
      ),
      build: (_) => [
        // Infos session
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfInfoRow('Matière',    a.matiere),
              _pdfInfoRow('Professeur', a.professeur),
              _pdfInfoRow('Salle',      a.salle),
              _pdfInfoRow('Type',       a.type),
              _pdfInfoRow('Date',       dateStr),
              _pdfInfoRow('Durée',      a.dureeLabel),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Stats
        pw.Row(children: [
          _pdfStat('Total',    '${a.total}',      PdfColors.grey700),
          _pdfStat('Présents', '${a.nbPresents}', PdfColors.green700),
          _pdfStat('Absents',  '${a.nbAbsents}',  PdfColors.red700),
          _pdfStat('Taux',
              '${a.tauxPresence.toStringAsFixed(0)}%',
              a.tauxPresence >= 75
                  ? PdfColors.green700
                  : a.tauxPresence >= 50
                  ? PdfColors.orange700
                  : PdfColors.red700),
        ]),
        pw.SizedBox(height: 20),

        // Tableau présents
        if (a.presents.isNotEmpty) ...[
          pw.Text('Étudiants présents (${a.nbPresents})',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green50),
                children: [
                  _pdfHeader('Matricule'),
                  _pdfHeader('Nom & Prénom'),
                  _pdfHeader('Heure'),
                  _pdfHeader('Méthode'),
                ],
              ),
              ...a.presents.map((e) => pw.TableRow(
                children: [
                  _pdfCell(e.matricule),
                  _pdfCell('${e.prenom} ${e.nom}'),
                  _pdfCell(
                    e.confirmedAt != null
                        ? '${e.confirmedAt!.hour.toString().padLeft(2, '0')}:'
                        '${e.confirmedAt!.minute.toString().padLeft(2, '0')}'
                        : '--:--',
                  ),
                  _pdfCell(
                    e.methode == 'manuel' ? 'Manuel' : 'Code OTP',
                  ),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Tableau absents
        if (a.absents.isNotEmpty) ...[
          pw.Text('Étudiants absents (${a.nbAbsents})',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red50),
                children: [
                  _pdfHeader('Matricule'),
                  _pdfHeader('Nom & Prénom'),
                ],
              ),
              ...a.absents.map((e) => pw.TableRow(
                children: [
                  _pdfCell(e.matricule),
                  _pdfCell('${e.prenom} ${e.nom}'),
                ],
              )),
            ],
          ),
        ],

        pw.SizedBox(height: 32),
        pw.Divider(color: PdfColors.grey300),
        pw.Text(
          'Document généré par EduNotify — ${DateTime.now().day}/'
              '${DateTime.now().month}/${DateTime.now().year}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfInfoRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(children: [
    pw.SizedBox(
      width: 90,
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold)),
    ),
    pw.Text(value,
        style: const pw.TextStyle(fontSize: 11)),
  ]),
);

pw.Widget _pdfStat(String label, String value, PdfColor color) =>
    pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
        ]),
      ),
    );

pw.Widget _pdfHeader(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text,
      style: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold)),
);

pw.Widget _pdfCell(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text,
      style: const pw.TextStyle(fontSize: 10)),
);

// ══════════════════════════════════════════════════════════════════
// ÉCRAN HISTORIQUE
// ══════════════════════════════════════════════════════════════════

class HistoriqueScreen extends ConsumerStatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  ConsumerState<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends ConsumerState<HistoriqueScreen> {
  @override
  void initState() {
    super.initState();
    // Charge les archives au premier affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(archivesProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final archives = ref.watch(archivesProvider);
    final s        = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.rollCallHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.read(archivesProvider.notifier).invalider();
              ref.read(archivesProvider.notifier).charger();
            },
          ),
        ],
      ),
      body: archives.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: context.textMuted),
            const SizedBox(height: 12),
            Text(s.noArchive,
                style: TextStyle(
                    color: context.textMuted, fontSize: 14)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: archives.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ArchiveTile(
          archive: archives[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DetailSessionScreen(archive: archives[i]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE ARCHIVE
// ══════════════════════════════════════════════════════════════════

class _ArchiveTile extends ConsumerWidget {
  final SessionArchive archive;
  final VoidCallback onTap;

  const _ArchiveTile({required this.archive, required this.onTap});

  Color _tauxColor(double t) {
    if (t >= 75) return AppColors.green;
    if (t >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s    = ref.watch(stringsProvider);
    final d    = archive.debutLe;
    final now  = DateTime.now();
    final diff = now.difference(d).inDays;

    String dateLabel;
    if (diff == 0)      dateLabel = s.today;
    else if (diff == 1) dateLabel = s.yesterday;
    else dateLabel =
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

    final heureLabel =
        '${d.hour.toString().padLeft(2, '0')}h'
        '${d.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Expanded(
                  child: Text(archive.matiere,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text(archive.professeur,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.door_front_door_outlined,
                    size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text(archive.salle,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(archive.type,
                      style: const TextStyle(
                          color: AppColors.violet,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.schedule, size: 12, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$dateLabel à $heureLabel · ${archive.dureeLabel}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: context.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN DÉTAIL SESSION
// ══════════════════════════════════════════════════════════════════

class DetailSessionScreen extends ConsumerStatefulWidget {
  final SessionArchive archive;
  const DetailSessionScreen({super.key, required this.archive});

  @override
  ConsumerState<DetailSessionScreen> createState() =>
      _DetailSessionScreenState();
}

class _DetailSessionScreenState
    extends ConsumerState<DetailSessionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _generatingPdf = false;
  bool _loading       = true;
  SessionArchive? _detail; // version enrichie depuis le backend

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _chargerDetail();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Charge le vrai détail depuis GET /presence/sessions/:id/detail
  Future<void> _chargerDetail() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.getPresence(
        '/presence/sessions/${widget.archive.id}/detail',
        userId:   user.id,
        role:     user.role,
        classeId: user.classeId,
      );

      final s        = resp['session'] as Map<String, dynamic>? ?? {};
      final rawPres  = (s['presents'] as List<dynamic>? ?? []);
      final rawAbs   = (s['absents']  as List<dynamic>? ?? []);

      final presents = rawPres.map((p) {
        final m = p as Map<String, dynamic>;
        final dateStr = m['confirmeA'] as String?;
        return EtudiantPresent(
          matricule:   m['matricule'] as String? ?? '',
          nom:         m['nom']       as String? ?? '',
          prenom:      m['prenom']    as String? ?? '',
          confirmedAt: dateStr != null ? DateTime.parse(dateStr) : null,
        );
      }).toList();

      final absents = rawAbs.map((p) {
        final m = p as Map<String, dynamic>;
        return EtudiantAbsent(
          matricule: m['matricule'] as String? ?? '',
          nom:       m['nom']       as String? ?? '',
          prenom:    m['prenom']    as String? ?? '',
        );
      }).toList();

      final debutStr = (s['ouverteLe'] ?? s['debutLe']) as String?;
      final finStr   = (s['fermeeLe'] ?? s['finLe'])    as String?;

      setState(() {
        _detail = SessionArchive(
          id:         widget.archive.id,
          matiere:    s['matiere']    as String? ?? widget.archive.matiere,
          professeur: s['professeur'] as String? ?? widget.archive.professeur,
          salle:      s['salle']      as String? ?? widget.archive.salle,
          type:       s['type']       as String? ?? widget.archive.type,
          debutLe:    debutStr != null
              ? DateTime.parse(debutStr)
              : widget.archive.debutLe,
          finLe:      finStr != null
              ? DateTime.parse(finStr)
              : widget.archive.finLe,
          presents: presents,
          absents:  absents,
        );
        _loading = false;
      });
    } catch (_) {
      // Fallback sur l'archive locale si erreur
      setState(() {
        _detail  = widget.archive;
        _loading = false;
      });
    }
  }

  Future<void> _telechargerPdf() async {
    final archive = _detail ?? widget.archive;
    setState(() => _generatingPdf = true);
    try {
      final pdfBytes = await genererPdfPresence(archive);
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'presence_${archive.matiere.replaceAll(' ', '_')}_'
            '${archive.debutLe.day}'
            '${archive.debutLe.month}'
            '${archive.debutLe.year}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF : $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.archive.matiere)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final a = _detail ?? widget.archive;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.matiere),
        actions: [
          // ── Bouton télécharger PDF ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _generatingPdf
                ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2),
              ),
            )
                : IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Télécharger PDF',
              onPressed: _telechargerPdf,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '${s.presentsTab} (${a.nbPresents})'),
            Tab(text: '${s.absentsTab} (${a.nbAbsents})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Résumé
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _ResumeItem(
                      label: s.rate,
                      value:
                      '${a.tauxPresence.toStringAsFixed(0)}%',
                      color: a.tauxPresence >= 75
                          ? AppColors.green
                          : a.tauxPresence >= 50
                          ? AppColors.orange
                          : AppColors.red,
                    ),
                    _divider(context),
                    _ResumeItem(
                        label: s.presentsTab,
                        value: '${a.nbPresents}',
                        color: AppColors.green),
                    _divider(context),
                    _ResumeItem(
                        label: s.absentsTab,
                        value: '${a.nbAbsents}',
                        color: AppColors.red),
                    _divider(context),
                    _ResumeItem(
                        label: s.duration,
                        value: a.dureeLabel,
                        color: AppColors.cyan),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.total == 0
                        ? 0
                        : a.nbPresents / a.total,
                    backgroundColor:
                    AppColors.red.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.green),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                // Bouton téléchargement visible dans le résumé aussi
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                    _generatingPdf ? null : _telechargerPdf,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: const BorderSide(
                          color: AppColors.orange),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                    ),
                    icon: _generatingPdf
                        ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.orange))
                        : const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18),
                    label: Text(_generatingPdf
                        ? 'Génération...'
                        : 'Télécharger le rapport PDF'),
                  ),
                ),
              ],
            ),
          ),

          // Onglets
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ListePresents(presents: a.presents),
                _ListeAbsents(absents: a.absents),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: context.borderColor,
  );
}

// ══════════════════════════════════════════════════════════════════
// LISTES PRÉSENTS / ABSENTS
// ══════════════════════════════════════════════════════════════════

class _ListePresents extends ConsumerWidget {
  final List<EtudiantPresent> presents;
  const _ListePresents({required this.presents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (presents.isEmpty) {
      return Center(
        child: Text(s.nonePresent,
            style: TextStyle(color: context.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: presents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = presents[i];
        final dt = e.confirmedAt;
        final h  = dt != null ? dt.hour.toString().padLeft(2, '0') : '--';
        final m  = dt != null ? dt.minute.toString().padLeft(2, '0') : '--';
        return _EtudiantTile(
          nom:       e.nom,
          prenom:    e.prenom,
          matricule: e.matricule,
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$h:$m',
                  style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (e.methode == 'manuel')
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Manuel',
                      style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          color: AppColors.green,
          icon:  Icons.check_circle_outline,
        );
      },
    );
  }
}

class _ListeAbsents extends ConsumerWidget {
  final List<EtudiantAbsent> absents;
  const _ListeAbsents({required this.absents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (absents.isEmpty) {
      return Center(
        child: Text(s.noneAbsent,
            style: TextStyle(color: context.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: absents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = absents[i];
        return _EtudiantTile(
          nom:       e.nom,
          prenom:    e.prenom,
          matricule: e.matricule,
          trailing: Text(s.absentsTab,
              style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          color: AppColors.red,
          icon:  Icons.cancel_outlined,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════

class _EtudiantTile extends StatelessWidget {
  final String nom, prenom, matricule;
  final Widget trailing;
  final Color color;
  final IconData icon;

  const _EtudiantTile({
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.trailing,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$prenom $nom',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(matricule,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 11)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ResumeItem extends StatelessWidget {
  final String label, value;
  final Color color;

  const _ResumeItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: context.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}