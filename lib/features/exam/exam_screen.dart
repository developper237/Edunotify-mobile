import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL — EXAMEN (ÉTUDIANT)
// Affiche : formulaire code + liste des examens passés/archivés
// ══════════════════════════════════════════════════════════════════

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _resultats = [];
  bool _loadingArchives = true;

  @override
  void initState() {
    super.initState();
    _chargerResultats();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _chargerResultats() async {
    setState(() => _loadingArchives = true);
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.getExam(
        '/exam/sessions/mes-resultats',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      setState(() {
        _resultats = (resp['resultats'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loadingArchives = false;
      });
    } catch (_) {
      setState(() => _loadingArchives = false);
    }
  }

  Future<void> _rejoindre() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entrez le code d'invitation")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.postExam(
        '/exam/sessions/$code/join',
        data: {},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );

      final session = resp['session'] as Map<String, dynamic>?;
      if (session == null) throw Exception('Session invalide');

      // Vérifier si la session est terminée
      final statut = session['statut'] as String?;
      if (statut == 'termine' || statut == 'annule') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cette session est terminée')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Vérifier si l'étudiant a déjà passé cet examen
      final participant = resp['participant'] as Map<String, dynamic>?;
      if (participant != null && participant['statut'] == 'termine') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous avez déjà passé cet examen')),
          );
        }
        setState(() => _isLoading = false);
        _chargerResultats();
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ExamSessionScreen(sessionId: session['id']),
        ),
      ).then((_) => _chargerResultats());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Salle d'examen")),
      body: RefreshIndicator(
        onRefresh: _chargerResultats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Formulaire code d'invitation ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.vpn_key_rounded,
                        size: 48, color: AppColors.cyan),
                    const SizedBox(height: 12),
                    Text(
                      'Rejoindre un examen',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Demandez le code d'invitation à votre professeur",
                      style:
                          TextStyle(color: context.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'CODE',
                        hintStyle: TextStyle(
                          letterSpacing: 6,
                          color: context.textMuted,
                        ),
                      ),
                      maxLength: 8,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                          null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _rejoindre,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Rejoindre'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Section examens passés ──
            Text(
              'Mes examens passés',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (_loadingArchives)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_resultats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 40, color: context.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun examen passé',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._resultats.map((r) => _buildArchiveCard(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveCard(Map<String, dynamic> r) {
    final statut = r['statut'] as String? ?? '';
    final matiere = r['matiere'] as String? ?? '';
    final titre = r['titre'] as String? ?? '';
    final noteSur20 = r['noteSur20'] as double?;
    final score = r['score'] as double?;
    final totalPoints = r['totalPoints'] as int? ?? 0;
    final debut = r['debut'] as String?;
    final fin = r['fin'] as String?;
    final dateCreation = r['dateCreation'] as String?;
    final profNom = r['profNom'] as String? ?? '';
    final statutParticipant = r['statutParticipant'] as String? ?? '';

    // Date affichée
    String dateStr = '';
    if (debut != null) {
      try {
        final dt = DateTime.parse(debut);
        dateStr = DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(dt);
      } catch (_) {
        dateStr = debut;
      }
    } else if (dateCreation != null) {
      try {
        final dt = DateTime.parse(dateCreation);
        dateStr = DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(dt);
      } catch (_) {}
    }

    final estInvalide = statutParticipant == 'invalide';
    final borderColor = estInvalide
        ? AppColors.red
        : statut == 'termine'
            ? AppColors.cyan
            : AppColors.orange;

    final noteColor = estInvalide
        ? AppColors.red
        : noteSur20 != null
            ? (noteSur20 >= 10 ? AppColors.green : AppColors.orange)
            : context.textMuted;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: noteColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: estInvalide
                ? const Icon(Icons.block_rounded,
                    color: AppColors.red, size: 24)
                : noteSur20 != null
                    ? Text(
                        '${noteSur20.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: noteColor,
                        ),
                      )
                    : Text(
                        '??',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                        ),
                      ),
          ),
        ),
        title: Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              matiere,
              style: TextStyle(
                  color: AppColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (dateStr.isNotEmpty) ...[
                  Icon(Icons.schedule_rounded,
                      size: 12, color: context.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      dateStr,
                      style:
                          TextStyle(color: context.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    estInvalide
                        ? 'Invalide'
                        : statut == 'termine'
                            ? 'Corrigé'
                            : 'Terminé',
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: noteSur20 != null
            ? Text(
                '/20',
                style: TextStyle(
                  fontSize: 11,
                  color: context.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        onTap: () => _afficherDetailResultat(r),
      ),
    );
  }

  void _afficherDetailResultat(Map<String, dynamic> r) {
    final titre = r['titre'] as String? ?? '';
    final matiere = r['matiere'] as String? ?? '';
    final noteSur20 = r['noteSur20'] as double?;
    final score = r['score'] as double?;
    final totalPoints = r['totalPoints'] as int? ?? 0;
    final avertissements = r['avertissements'] as int? ?? 0;
    final statutParticipant = r['statutParticipant'] as String? ?? '';
    final debut = r['debut'] as String?;
    final profNom = r['profNom'] as String? ?? '';
    final nbSujets = r['nbSujets'] as int? ?? 0;

    String dateStr = '';
    if (debut != null) {
      try {
        final dt = DateTime.parse(debut);
        dateStr = DateFormat('dd MMMM yyyy • HH:mm', 'fr_FR').format(dt);
      } catch (_) {}
    }

    final estInvalide = statutParticipant == 'invalide';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              estInvalide
                  ? Icons.block_rounded
                  : Icons.emoji_events_rounded,
              size: 48,
              color: estInvalide ? AppColors.red : AppColors.orange,
            ),
            const SizedBox(height: 12),
            if (estInvalide)
              const Text(
                'Session invalidée',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ),
              )
            else if (noteSur20 != null)
              Text(
                '${noteSur20.toStringAsFixed(1)} / 20',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cyan,
                ),
              ),
            const SizedBox(height: 12),
            _detailRow('Matière', matiere),
            if (profNom.isNotEmpty) _detailRow('Professeur', profNom),
            if (dateStr.isNotEmpty) _detailRow('Date', dateStr),
            _detailRow('Questions', '$nbSujets'),
            if (score != null)
              _detailRow('Points', '${score.toInt()} / $totalPoints'),
            if (avertissements > 0)
              _detailRow('Avertissements', '$avertissements'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: context.textMuted, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN D'EXAMEN EN COURS (ÉTUDIANT)
// ══════════════════════════════════════════════════════════════════

class _ExamSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const _ExamSessionScreen({required this.sessionId});

  @override
  ConsumerState<_ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends ConsumerState<_ExamSessionScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _sujets = [];
  int _currentIndex = 0;
  Map<String, String> _reponses = {};
  int _avertissements = 0;
  Timer? _timer;
  int _secondesRestantes = 0;
  bool _isFinished = false;
  bool _isLoading = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chargerSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isFinished) {
      _signalerAvertissement('quit');
    }
  }

  Future<void> _chargerSession() async {
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.getExam(
        '/exam/sessions/${widget.sessionId}',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );

      final session = resp['session'] as Map<String, dynamic>?;
      final statut = session?['statut'] as String?;

      // Si la session est déjà terminée ou annulée, on ne peut plus y accéder
      if (statut == 'termine' || statut == 'annule') {
        setState(() {
          _erreur = 'cette session est terminée';
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cette session est déjà terminée')),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
        return;
      }

      // Vérifier si le participant a déjà soumis ou est invalidé
      final participants = session?['participants'] as List? ?? [];
      if (participants.isNotEmpty) {
        final p = participants.first;
        final pStatut = p['statut'] as String?;
        if (pStatut == 'termine') {
          setState(() {
            _isFinished = true;
            _isLoading = false;
          });
          return;
        }
        if (pStatut == 'invalide') {
          setState(() {
            _erreur = 'Votre session a été invalidée';
            _isLoading = false;
          });
          return;
        }
      }

      final sujets = (session?['sujets'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _session = session;
        _sujets = sujets;
        _isLoading = false;
      });

      if (session?['fin'] != null) {
        _demarrerTimer(DateTime.parse(session!['fin']));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _demarrerTimer(DateTime fin) {
    _timer?.cancel();
    _secondesRestantes = fin.difference(DateTime.now()).inSeconds;
    if (_secondesRestantes <= 0) {
      _terminerExamen();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secondesRestantes--;
        if (_secondesRestantes <= 0) {
          t.cancel();
          _terminerExamen();
        }
      });
    });
  }

  Future<void> _signalerAvertissement(String type) async {
    if (_isFinished) return;
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.postExam(
        '/exam/sessions/${widget.sessionId}/warning',
        data: {'type': type},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );

      if (resp['invalide'] == true) {
        _timer?.cancel();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Session invalidée'),
              content:
                  Text(resp['message'] ?? 'Vous avez été déconnecté'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Retour'),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() =>
          _avertissements = resp['avertissements'] ?? 0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp['message'] ?? 'Avertissement'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _soumettreReponse(String sujetId, String reponse) async {
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.postExam(
        '/exam/sessions/${widget.sessionId}/answer',
        data: {'sujetId': sujetId, 'reponse': reponse},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
    } catch (_) {}
  }

  Future<void> _terminerExamen() async {
    if (_isFinished) return;
    setState(() => _isFinished = true);
    _timer?.cancel();

    int totalPoints = 0;
    int pointsObtenus = 0;
    for (final sujet in _sujets) {
      final points = (sujet['points'] as int?) ?? 1;
      totalPoints += points;
      final options =
          (sujet['options'] as Map<String, dynamic>?) ?? {};
      final correctKey = options['correct'];
      if (correctKey != null &&
          _reponses[sujet['id']] == correctKey) {
        pointsObtenus += points;
      }
    }
    final note20 = totalPoints > 0
        ? (pointsObtenus / totalPoints * 20).toStringAsFixed(1)
        : '0.0';

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Examen terminé !'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 48, color: AppColors.orange),
              const SizedBox(height: 12),
              Text(
                'Votre note : $note20 / 20',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$pointsObtenus / $totalPoints points',
                style: TextStyle(
                    color: context.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos réponses ont été enregistrées et corrigées.',
                style: TextStyle(
                    color: context.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTemps(int secondes) {
    final m = secondes ~/ 60;
    final s = secondes % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Examen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Session terminée — afficher un message
    if (_erreur != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Examen')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: context.textMuted, size: 56),
              const SizedBox(height: 12),
              Text(
                _erreur!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    // Déjà soumis
    if (_isFinished || _sujets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Examen')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle,
                  color: AppColors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                _sujets.isEmpty
                    ? 'Aucun sujet disponible'
                    : 'Examen terminé !',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sujet = _sujets[_currentIndex];
    final options =
        (sujet['options'] as Map<String, dynamic>?) ?? {};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _signalerAvertissement('quit');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_session?['titre'] ?? 'Examen'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondesRestantes < 300
                    ? AppColors.red
                    : AppColors.cyan,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatTemps(_secondesRestantes),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _sujets.length,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(AppColors.cyan),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Question ${_currentIndex + 1}/${_sujets.length}',
                      style: const TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_avertissements > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.orange,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$_avertissements avertissement(s)',
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sujet['intitule'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      sujet['enonce'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (options.isNotEmpty)
                      ...options.entries.map((e) {
                        final selected =
                            _reponses[sujet['id']] == e.key;
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() =>
                                    _reponses[sujet['id']] =
                                        e.key);
                                _soumettreReponse(
                                    sujet['id'], e.key);
                              },
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 200),
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.cyan
                                          .withValues(
                                              alpha: 0.1)
                                      : isDark
                                          ? AppColors.darkCard
                                          : AppColors
                                              .lightCard,
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.cyan
                                        : context
                                            .borderColor,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration:
                                          BoxDecoration(
                                        color: selected
                                            ? AppColors.cyan
                                            : context
                                                .borderColor,
                                        shape:
                                            BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          e.key,
                                          style:
                                              const TextStyle(
                                            color: Colors
                                                .white,
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 12),
                                    Expanded(
                                      child: Text(
                                        e.value.toString(),
                                        style: TextStyle(
                                          color: context
                                              .textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(
                            () => _currentIndex--),
                        child: const Text('Précédent'),
                      ),
                    ),
                  if (_currentIndex > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentIndex <
                              _sujets.length - 1
                          ? () =>
                              setState(() => _currentIndex++)
                          : _terminerExamen,
                      child: Text(
                        _currentIndex < _sujets.length - 1
                            ? 'Suivant'
                            : 'Terminer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get isDark =>
      Theme.of(context).brightness == Brightness.dark;
}
