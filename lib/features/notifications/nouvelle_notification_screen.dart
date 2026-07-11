import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'notifications_screen.dart';

// ══════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL — tabs Notification / Sondage
// ══════════════════════════════════════════════════════════════════

class NouvelleNotificationScreen extends ConsumerStatefulWidget {
  const NouvelleNotificationScreen({super.key});

  @override
  ConsumerState<NouvelleNotificationScreen> createState() =>
      _NouvelleNotificationScreenState();
}

class _NouvelleNotificationScreenState
    extends ConsumerState<NouvelleNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role ?? 'etudiant';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // LE WRAPPER CENTRE POUR DESKTOP
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Envoyer'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: 'Notification'),
            Tab(icon: Icon(Icons.poll_outlined, size: 18), text: 'Sondage'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600), // LIMITE A 600 PX
          child: Container(
            margin: isDesktop ? const EdgeInsets.all(32) : EdgeInsets.zero,
            decoration: isDesktop ? BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ) : null,
            child: Column(
              children: [
                if (isDesktop) ...[
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Text('Nouveau Message',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: 'Notification'),
                      Tab(text: 'Sondage'),
                    ],
                  ),
                ],
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _FormulaireNotif(role: role),
                      _FormulaireSondage(role: role),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FORMULAIRE NOTIFICATION — connecté au backend
// ══════════════════════════════════════════════════════════════════

class _FormulaireNotif extends ConsumerStatefulWidget {
  final String role;
  const _FormulaireNotif({required this.role});

  @override
  ConsumerState<_FormulaireNotif> createState() => _FormulaireNotifState();
}

class _FormulaireNotifState extends ConsumerState<_FormulaireNotif> {
  final _titre = TextEditingController();
  final _message = TextEditingController();
  String _categorie = 'administratif';
  bool _urgent = false;
  String _destinataire = 'classe';
  bool _loading = false;
  bool _sent = false;
  String? _error;
  int? _nbDestinataires;

  static const _categories = ['administratif', 'examen', 'resultat', 'cours'];
  static const _catLabels = ['Administratif', 'Examen', 'Résultat', 'Cours'];
  static const _catIcons = [
    Icons.info_outline,
    Icons.assignment_outlined,
    Icons.grade_outlined,
    Icons.school_outlined
  ];
  static const _catColors = [
    AppColors.violet,
    AppColors.orange,
    AppColors.green,
    AppColors.blue
  ];

  @override
  void dispose() {
    _titre.dispose();
    _message.dispose();
    super.dispose();
  }

  List<Map<String, String>> _destinataires() {
    switch (widget.role) {
      case 'delegue':
        return [
          {'value': 'classe', 'label': 'Ma classe entière'},
          {'value': 'presents', 'label': 'Présents aujourd\'hui'},
          {'value': 'absents', 'label': 'Absents aujourd\'hui'},
        ];
      case 'chef_departement':
        return [
          {'value': 'dept', 'label': 'Tout le département'},
          {'value': 'L1', 'label': 'L1'},
          {'value': 'L2', 'label': 'L2'},
          {'value': 'L3', 'label': 'L3'},
          {'value': 'M1', 'label': 'M1'},
          {'value': 'M2', 'label': 'M2'},
        ];
      case 'admin':
        return [
          {'value': 'all', 'label': 'Tout l\'établissement'},
          {'value': 'etudiants', 'label': 'Étudiants uniquement'},
          {'value': 'staff', 'label': 'Personnel uniquement'},
        ];
      case 'super_admin':
        return [
          {'value': 'platform', 'label': 'Toute la plateforme'},
        ];
      default:
        return [
          {'value': 'classe', 'label': 'Ma classe'}
        ];
    }
  }

  Future<void> _envoyer() async {
    if (_titre.text.trim().isEmpty || _message.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.postNotif(
        '/notifications',
        data: {
          'titre': _titre.text.trim(),
          'contenu': _message.text.trim(),
          'categorie': _categorie,
          'urgence': _urgent,
          'cible': _destinataire,
        },
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
        departementId: user.departementId,
        classeId: user.classeId,
      );

      setState(() {
        _loading = false;
        _sent = true;
        _nbDestinataires = resp['nbDestinataires'] as int?;
      });

      // Recharger les notifs
      ref.read(notifsProvider.notifier).charger();
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erreur de connexion';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _SuccessView(
        icon: Icons.notifications_active_outlined,
        color: AppColors.cyan,
        titre: 'Notification envoyée !',
        message: _nbDestinataires != null
            ? 'Envoyée à $_nbDestinataires destinataire(s).'
            : 'Les destinataires ont été notifiés.',
        onReset: () => setState(() {
          _sent = false;
          _titre.clear();
          _message.clear();
          _urgent = false;
        }),
      );
    }

    final dests = _destinataires();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destinataires
          _Label('Destinataires', context),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dests.map((d) {
              final selected = _destinataire == d['value'];
              return GestureDetector(
                onTap: () => setState(() => _destinataire = d['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.cyan : context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? AppColors.cyan : context.borderColor),
                  ),
                  child: Text(d['label']!,
                      style: TextStyle(
                        color:
                            selected ? AppColors.dark : context.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Catégorie
          _Label('Catégorie', context),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_categories.length, (i) {
              final selected = _categorie == _categories[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _categorie = _categories[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: i < _categories.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _catColors[i].withValues(alpha: 0.15)
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _catColors[i] : context.borderColor,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(_catIcons[i],
                            color: selected ? _catColors[i] : context.textMuted,
                            size: 18),
                        const SizedBox(height: 4),
                        Text(_catLabels[i],
                            style: TextStyle(
                              color:
                                  selected ? _catColors[i] : context.textMuted,
                              fontSize: 9,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          _Label('Titre *', context),
          const SizedBox(height: 8),
          TextField(
            controller: _titre,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ex: Examen de Mathématiques reporté',
              prefixIcon: Icon(Icons.title, color: context.textMuted, size: 20),
            ),
          ),

          const SizedBox(height: 20),

          _Label('Message *', context),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rédigez votre message ici...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Icon(Icons.message_outlined,
                    color: context.textMuted, size: 20),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Urgent
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _urgent
                  ? AppColors.red.withValues(alpha: 0.08)
                  : context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _urgent
                    ? AppColors.red.withValues(alpha: 0.3)
                    : context.borderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.priority_high_rounded,
                      color: AppColors.red, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marquer comme urgent',
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text('La notification sera mise en avant',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                  activeColor: AppColors.red,
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ||
                      _titre.text.trim().isEmpty ||
                      _message.text.trim().isEmpty
                  ? null
                  : _envoyer,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_loading ? 'Envoi...' : 'Envoyer la notification'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FORMULAIRE SONDAGE — compatible avec le nouveau backend
// ══════════════════════════════════════════════════════════════════

class _QuestionSondageBloc {
  final TextEditingController questionController;
  final List<TextEditingController> choixControllers;
  bool obligatoire;

  _QuestionSondageBloc({
    required this.questionController,
    required this.choixControllers,
    this.obligatoire = false,
  });
}

class _FormulaireSondage extends ConsumerStatefulWidget {
  final String role;
  const _FormulaireSondage({required this.role});

  @override
  ConsumerState<_FormulaireSondage> createState() => _FormulaireSondageState();
}

class _FormulaireSondageState extends ConsumerState<_FormulaireSondage> {
  final _titre = TextEditingController(); // Ajout du contrôleur de titre
  final List<_QuestionSondageBloc> _questions = [
    _QuestionSondageBloc(
      questionController: TextEditingController(),
      choixControllers: [
        TextEditingController(),
        TextEditingController(),
      ],
      obligatoire: false,
    ),
  ];

  String _destinataire = 'classe';
  bool _loading = false;
  bool _sent = false;
  String? _error;
  int? _nbDestinataires;

  @override
  void dispose() {
    _titre.dispose(); // Dispose du titre
    for (final q in _questions) {
      q.questionController.dispose();
      for (final c in q.choixControllers) c.dispose();
    }
    super.dispose();
  }

  void _ajouterQuestion() {
    setState(() {
      _questions.add(
        _QuestionSondageBloc(
          questionController: TextEditingController(),
          choixControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          obligatoire: false,
        ),
      );
    });
  }

  void _supprimerQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      final q = _questions[index];
      q.questionController.dispose();
      for (final c in q.choixControllers) c.dispose();
      _questions.removeAt(index);
    });
  }

  void _ajouterChoix(int questionIndex) {
    if (_questions[questionIndex].choixControllers.length >= 4) return;
    setState(() {
      _questions[questionIndex].choixControllers.add(TextEditingController());
    });
  }

  void _supprimerChoix(int questionIndex, int choixIndex) {
    if (_questions[questionIndex].choixControllers.length <= 2) return;
    setState(() {
      final c = _questions[questionIndex].choixControllers[choixIndex];
      c.dispose();
      _questions[questionIndex].choixControllers.removeAt(choixIndex);
    });
  }

  Future<void> _envoyer() async {
    // Validation du titre
    if (_titre.text.trim().isEmpty) {
      setState(() => _error = 'Donnez un objet à ce sondage.');
      return;
    }

    final questionsPayload = <Map<String, dynamic>>[];

    for (final q in _questions) {
      final questionText = q.questionController.text.trim();
      final choixValides = q.choixControllers
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => c.text.trim())
          .toList();

      if (questionText.isEmpty) {
        setState(() => _error = 'Chaque question doit avoir un texte.');
        return;
      }

      if (choixValides.length < 2) {
        setState(() => _error = 'Chaque question doit avoir au moins 2 choix.');
        return;
      }

      questionsPayload.add({
        'question': questionText,
        'choix': choixValides,
        'required': q.obligatoire,
      });
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider)!;
      final resp = await ApiClient.postNotif(
        '/notifications/sondage',
        data: {
          'titre': _titre.text.trim(), // Envoi du titre
          'questions': questionsPayload,
          'cible': _destinataire,
        },
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
        departementId: user.departementId,
        classeId: user.classeId,
      );

      setState(() {
        _loading = false;
        _sent = true;
        _nbDestinataires = resp['nbDestinataires'] as int?;
      });

      ref.read(notifsProvider.notifier).charger();
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erreur de connexion';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _SuccessView(
        icon: Icons.poll_outlined,
        color: AppColors.violet,
        titre: 'Sondage envoyé !',
        message: _nbDestinataires != null
            ? 'Envoyé à $_nbDestinataires destinataire(s).'
            : 'Les destinataires peuvent maintenant voter.',
        onReset: () {
          setState(() {
            _sent = false;
            _titre.clear(); // Reset titre
            _error = null;
            _nbDestinataires = null;
            _questions.clear();
            _questions.add(
              _QuestionSondageBloc(
                questionController: TextEditingController(),
                choixControllers: [
                  TextEditingController(),
                  TextEditingController(),
                ],
              ),
            );
          });
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Destinataires', context),
          const SizedBox(height: 10),
          _DestinataireSelector(
            role: widget.role,
            selected: _destinataire,
            onChanged: (v) => setState(() => _destinataire = v),
          ),
          const SizedBox(height: 24),

          // ── CHAMP TITRE ──────────────────────────────────────────
          _Label('Objet du sondage *', context),
          const SizedBox(height: 8),
          TextField(
            controller: _titre,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ex: Disponibilité pour le cours de rattrapage',
              prefixIcon: Icon(Icons.poll_outlined,
                  color: context.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              _Label('Questions du sondage', context),
              const Spacer(),
              TextButton.icon(
                onPressed: _ajouterQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une question'),
              ),
            ],
          ),
          // ... reste du code (boucle for qIndex)

          const SizedBox(height: 12),
          for (int qIndex = 0; qIndex < _questions.length; qIndex++) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Question ${qIndex + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text('Obligatoire',
                                style: TextStyle(
                                    color: context.textMuted, fontSize: 12)),
                            const SizedBox(width: 6),
                            Switch.adaptive(
                              value: _questions[qIndex].obligatoire,
                              onChanged: (value) {
                                setState(() =>
                                    _questions[qIndex].obligatoire = value);
                              },
                              activeColor: AppColors.violet,
                            ),
                          ],
                        ),
                        if (_questions.length > 1)
                          IconButton(
                            onPressed: () => _supprimerQuestion(qIndex),
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red),
                            tooltip: 'Supprimer cette question',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _questions[qIndex].questionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Ex: Êtes-vous disponible pour un cours de rattrapage ?',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.help_outline,
                              color: context.textMuted, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Label('Choix de réponse *', context),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _ajouterChoix(qIndex),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter un choix'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int cIndex = 0;
                        cIndex < _questions[qIndex].choixControllers.length;
                        cIndex++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller:
                                    _questions[qIndex].choixControllers[cIndex],
                                decoration: InputDecoration(
                                  hintText: 'Choix ${cIndex + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (_questions[qIndex].choixControllers.length >
                                2) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _supprimerChoix(qIndex, cIndex),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: AppColors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style:
                          const TextStyle(color: AppColors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _envoyer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.poll_outlined, size: 18),
              label: Text(_loading ? 'Envoi...' : 'Lancer le sondage'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════

class _DestinataireSelector extends StatelessWidget {
  final String role, selected;
  final void Function(String) onChanged;
  const _DestinataireSelector({
    required this.role,
    required this.selected,
    required this.onChanged,
  });

  List<Map<String, String>> get _options {
    switch (role) {
      case 'delegue':
        return [
          {'value': 'classe', 'label': 'Ma classe'},
          {'value': 'presents', 'label': 'Présents'},
          {'value': 'absents', 'label': 'Absents'},
        ];
      case 'chef_departement':
        return [
          {'value': 'dept', 'label': 'Département'},
          {'value': 'L1', 'label': 'L1'},
          {'value': 'L2', 'label': 'L2'},
          {'value': 'L3', 'label': 'L3'},
          {'value': 'M1', 'label': 'M1'},
          {'value': 'M2', 'label': 'M2'},
        ];
      case 'admin':
        return [
          {'value': 'all', 'label': 'Tous'},
          {'value': 'etudiants', 'label': 'Étudiants'},
          {'value': 'staff', 'label': 'Personnel'},
        ];
      case 'super_admin':
        return [
          {'value': 'platform', 'label': 'Plateforme'}
        ];
      default:
        return [
          {'value': 'classe', 'label': 'Ma classe'}
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((d) {
        final isSelected = selected == d['value'];
        return GestureDetector(
          onTap: () => onChanged(d['value']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.violet : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? AppColors.violet : context.borderColor),
            ),
            child: Text(d['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
        );
      }).toList(),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titre, message;
  final VoidCallback onReset;
  const _SuccessView({
    required this.icon,
    required this.color,
    required this.titre,
    required this.message,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 24),
            Text(titre,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: context.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  side: BorderSide(color: context.borderColor),
                ),
                child: const Text('Nouveau message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _Label(this.text, this.ctx);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: ctx.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));
}
