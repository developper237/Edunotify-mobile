import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL — REJOINDRE UN EXAMEN
// ══════════════════════════════════════════════════════════════════

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _rejoindre() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code d\'invitation')),
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

      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ExamSessionScreen(sessionId: session['id']),
          ));
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
      appBar: AppBar(title: const Text('Salle d\'examen')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key_rounded, size: 64, color: AppColors.cyan),
              const SizedBox(height: 20),
              Text(
                'Rejoindre un examen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Demandez le code d\'invitation à votre professeur',
                style: TextStyle(color: context.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'CODE',
                  hintStyle: TextStyle(
                    letterSpacing: 8,
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _rejoindre,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Rejoindre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN D'EXAMEN EN COURS
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

  // Détecter quand l'app passe en arrière-plan
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
      final sujets = (session?['sujets'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _session = session;
        _sujets = sujets;
        _isLoading = false;
      });

      // Démarrer le timer si l'examen a déjà commencé
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
              content: Text(resp['message'] ?? 'Vous avez été déconnecté'),
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

      setState(() => _avertissements = resp['avertissements'] ?? 0);

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

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Examen terminé'),
          content: const Text('Vos réponses ont été enregistrées.'),
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

    if (_isFinished || _sujets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Examen')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                _sujets.isEmpty ? 'Aucun sujet disponible' : 'Examen terminé !',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    final sujet = _sujets[_currentIndex];
    final options = (sujet['options'] as Map<String, dynamic>?) ?? {};

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
            // Timer
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _secondesRestantes < 300 ? AppColors.red : AppColors.cyan,
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
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Barre de progression
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _sujets.length,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(AppColors.cyan),
            ),

            // En-tête sujet
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$_avertissements avertissement(s)',
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Énoncé du sujet
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

                    // Options QCM
                    if (options.isNotEmpty)
                      ...options.entries.map((e) {
                        final selected = _reponses[sujet['id']] == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() => _reponses[sujet['id']] = e.key);
                                _soumettreReponse(sujet['id'], e.key);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.cyan.withValues(alpha: 0.1)
                                      : isDark
                                          ? AppColors.darkCard
                                          : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.cyan
                                        : context.borderColor,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.cyan
                                            : context.borderColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        e.value.toString(),
                                        style: TextStyle(
                                          color: context.textPrimary,
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

            // Navigation
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentIndex--),
                        child: const Text('Précédent'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentIndex < _sujets.length - 1
                          ? () => setState(() => _currentIndex++)
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

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}
