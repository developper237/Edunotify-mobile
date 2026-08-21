import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PROFESSEUR — GESTION DES EXAMENS
// ══════════════════════════════════════════════════════════════════

class ProfExamScreen extends ConsumerStatefulWidget {
  const ProfExamScreen({super.key});

  @override
  ConsumerState<ProfExamScreen> createState() => _ProfExamScreenState();
}

class _ProfExamScreenState extends ConsumerState<ProfExamScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerSessions();
  }

  Future<void> _chargerSessions() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.getExam(
        '/exam/sessions/mes-sessions',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      setState(() {
        _sessions = (resp['sessions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Examens'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _CreerExamenScreen()),
            ).then((_) => _chargerSessions()),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Créer un examen',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 56, color: context.textMuted),
                      const SizedBox(height: 12),
                      Text('Aucun examen',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Créez votre premier examen',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _chargerSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = _sessions[i];
                      final statut = s['statut'] ?? 'en_preparation';
                      final code = s['codeInvitation'] ?? '';
                      final nbParticipants = s['_count']?['participants'] ?? 0;
                      final nbSujets = s['_count']?['sujets'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _statutColor(statut).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _statutIcon(statut),
                              color: _statutColor(statut),
                            ),
                          ),
                          title: Text(
                            s['titre'] ?? 'Sans titre',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${s['matiere'] ?? ''} • $nbSujets question(s)',
                                style: TextStyle(
                                    color: context.textMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statutColor(statut)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _statutLabel(statut),
                                      style: TextStyle(
                                        color: _statutColor(statut),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$nbParticipants participant(s)',
                                    style: TextStyle(
                                        color: context.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: statut == 'en_preparation'
                              ? IconButton(
                                  onPressed: () => _lancerExamen(s['id']),
                                  icon: const Icon(Icons.play_arrow_rounded,
                                      color: AppColors.green),
                                  tooltip: 'Lancer',
                                )
                              : statut == 'en_cours'
                                  ? IconButton(
                                      onPressed: () => _terminerExamen(s['id']),
                                      icon: const Icon(Icons.stop_rounded,
                                          color: AppColors.red),
                                      tooltip: 'Terminer',
                                    )
                                  : statut == 'termine'
                                      ? IconButton(
                                          onPressed: () => _afficherResultats(s['id'], s['titre'] ?? ''),
                                          icon: const Icon(Icons.bar_chart_rounded,
                                              color: AppColors.cyan),
                                          tooltip: 'Résultats',
                                        )
                                      : null,
                          onTap: statut == 'termine'
                              ? () => _afficherResultats(s['id'], s['titre'] ?? '')
                              : () => _afficherCode(s['codeInvitation'], s['titre']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _afficherCode(String code, String titre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Code — $titre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Partagez ce code avec vos étudiants :',
                style: TextStyle(color: context.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: AppColors.cyan,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copié !')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copier'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherResultats(String sessionId, String titre) async {
    // Afficher un loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.getExam(
        '/exam/sessions/$sessionId/results',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      final participants = (resp['participants'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('${participants.length} participant(s)',
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 40, color: context.textMuted),
                            const SizedBox(height: 8),
                            Text('Aucun participant',
                                style: TextStyle(color: context.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: participants.length,
                        itemBuilder: (c, i) {
                          final p = participants[i];
                          final user = p['user'] as Map<String, dynamic>? ?? {};
                          final nom = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
                          final email = user['email'] as String? ?? '';
                          final rawScore = p['score'];
                          final score = rawScore is num ? rawScore.toDouble() : (rawScore as double?);
                          final pStatut = p['statut'] as String? ?? '';
                          final avertissements = p['avertissements'] as int? ?? 0;
                          final nbReponses = (p['reponses'] as List?)?.length ?? 0;

                          // Calculer la note sur 20
                          final totalPoints = participants.isNotEmpty && i == 0
                              ? (p['reponses'] as List?)?.fold<int>(0, (sum, r) => sum + ((r as Map)['pointsObtenus'] as int? ?? 0)) ?? 0
                              : 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: pStatut == 'invalide'
                                  ? AppColors.red.withValues(alpha: 0.12)
                                  : AppColors.cyan.withValues(alpha: 0.12),
                              child: Text(
                                nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: pStatut == 'invalide' ? AppColors.red : AppColors.cyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(email,
                                style: TextStyle(color: context.textMuted, fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (score != null)
                                  Text(
                                    '${score.toInt()} pts',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: pStatut == 'invalide' ? AppColors.red : AppColors.cyan,
                                    ),
                                  ),
                                if (pStatut == 'invalide')
                                  Text('Invalide',
                                      style: TextStyle(color: AppColors.red, fontSize: 10)),
                                if (avertissements > 0)
                                  Text('$avertissements avt.',
                                      style: TextStyle(color: AppColors.orange, fontSize: 10)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _lancerExamen(String id) async {
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.postExam(
        '/exam/sessions/$id/start',
        data: {},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examen lancé !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _terminerExamen(String id) async {
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.postExam(
        '/exam/sessions/$id/finish',
        data: {},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examen terminé et corrigé !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'en_preparation': return AppColors.orange;
      case 'en_cours': return AppColors.green;
      case 'termine': return AppColors.cyan;
      default: return context.textMuted;
    }
  }

  IconData _statutIcon(String statut) {
    switch (statut) {
      case 'en_preparation': return Icons.edit_note_rounded;
      case 'en_cours': return Icons.timer_rounded;
      case 'termine': return Icons.check_circle_rounded;
      default: return Icons.help_outline;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'en_preparation': return 'Préparation';
      case 'en_cours': return 'En cours';
      case 'termine': return 'Terminé';
      default: return statut;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN CRÉATION D'EXAMEN
// ══════════════════════════════════════════════════════════════════

class _CreerExamenScreen extends ConsumerStatefulWidget {
  const _CreerExamenScreen();

  @override
  ConsumerState<_CreerExamenScreen> createState() => _CreerExamenScreenState();
}

class _CreerExamenScreenState extends ConsumerState<_CreerExamenScreen> {
  final _titreController = TextEditingController();
  final _matiereController = TextEditingController();
  final _descController = TextEditingController();
  final _dureeController = TextEditingController(text: '60');

  final List<_QuestionForm> _questions = [_QuestionForm()];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titreController.dispose();
    _matiereController.dispose();
    _descController.dispose();
    _dureeController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _ajouterQuestion() {
    setState(() => _questions.add(_QuestionForm()));
  }

  void _supprimerQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  Future<void> _creer() async {
    if (_titreController.text.trim().isEmpty ||
        _matiereController.text.trim().isEmpty ||
        _dureeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez tous les champs')),
      );
      return;
    }

    // Valider toutes les questions
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.intituleController.text.trim().isEmpty ||
          q.enonceController.text.trim().isEmpty ||
          q.correctAnswer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} : remplissez tous les champs')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final sujets = _questions.asMap().entries.map((entry) {
        final i = entry.key;
        final q = entry.value;
        final options = <String, String>{};
        for (int j = 0; j < q.optionControllers.length; j++) {
          final letter = String.fromCharCode(65 + j); // A, B, C, D
          options[letter] = q.optionControllers[j].text.trim();
        }
        return {
          'intitule': q.intituleController.text.trim(),
          'enonce': q.enonceController.text.trim(),
          'type': 'qcm',
          'options': options,
          'points': int.tryParse(q.pointsController.text) ?? 1,
        };
      }).toList();

      final user = ref.read(currentUserProvider);
      await ApiClient.postExam(
        '/exam/sessions',
        data: {
          'titre': _titreController.text.trim(),
          'matiere': _matiereController.text.trim(),
          'description': _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          'dureeMinutes': int.tryParse(_dureeController.text) ?? 60,
          'sujets': sujets,
        },
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examen créé avec succès !')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un examen'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _creer,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Infos générales
            Text('Informations',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _titreController,
              decoration: const InputDecoration(
                hintText: 'Titre de l\'examen',
                prefixIcon: Icon(Icons.title, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matiereController,
              decoration: const InputDecoration(
                hintText: 'Matière',
                prefixIcon: Icon(Icons.book_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.description_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dureeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Durée en minutes',
                prefixIcon: Icon(Icons.timer_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 24),

            // Questions
            Row(
              children: [
                Text('Questions (${_questions.length})',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _ajouterQuestion,
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.cyan),
                  tooltip: 'Ajouter une question',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Liste des questions
            ..._questions.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              return _buildQuestionCard(i, q);
            }),

            const SizedBox(height: 32),

            // Bouton créer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _creer,
                icon: const Icon(Icons.save_rounded),
                label: Text(_isSubmitting ? 'Création...' : 'Créer l\'examen'),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, _QuestionForm q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (_questions.length > 1)
                  IconButton(
                    onPressed: () => _supprimerQuestion(index),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.red, size: 20),
                    tooltip: 'Supprimer',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: q.intituleController,
              decoration: const InputDecoration(
                hintText: 'Titre de la question',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: q.enonceController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Énoncé de la question',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: q.pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Points (défaut: 1)',
                prefixIcon: Icon(Icons.star_outline, size: 20),
              ),
            ),

            const SizedBox(height: 12),

            // Options QCM
            Text('Options (cochez la bonne réponse)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted)),
            const SizedBox(height: 8),

            ...q.optionControllers.asMap().entries.map((optEntry) {
              final j = optEntry.key;
              final ctrl = optEntry.value;
              final letter = String.fromCharCode(65 + j);
              final isCorrect = q.correctAnswer == letter;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Radio pour bonne réponse
                    GestureDetector(
                      onTap: () =>
                          setState(() => q.correctAnswer = letter),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppColors.green
                              : context.borderColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(letter,
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.white
                                    : context.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              )),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: 'Option $letter',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    if (j > 3)
                      IconButton(
                        onPressed: () => setState(() {
                          ctrl.dispose();
                          q.optionControllers.removeAt(j);
                        }),
                        icon: const Icon(Icons.close,
                            size: 16, color: AppColors.red),
                      ),
                  ],
                ),
              );
            }),

            if (q.optionControllers.length < 6)
              TextButton.icon(
                onPressed: () => setState(() {
                  q.optionControllers.add(TextEditingController());
                }),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter une option',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODÈLE QUESTION FORM
// ══════════════════════════════════════════════════════════════════

class _QuestionForm {
  final intituleController = TextEditingController();
  final enonceController = TextEditingController();
  final pointsController = TextEditingController(text: '1');
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String? correctAnswer; // A, B, C, D...

  void dispose() {
    intituleController.dispose();
    enonceController.dispose();
    pointsController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}
