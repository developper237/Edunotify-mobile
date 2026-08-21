import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/widgets/ui_kit.dart';
import 'login_screen.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLE ÉTABLISSEMENT
// ══════════════════════════════════════════════════════════════════

class EtablissementInfo {
  final String id;
  final String nom;
  final String ville;
  final List<String> filieres;

  const EtablissementInfo({
    required this.id,
    required this.nom,
    required this.ville,
    this.filieres = const [],
  });

  factory EtablissementInfo.fromJson(Map<String, dynamic> j) {
    // Filières retournées par le backend (depuis la table Classe)
    final backendFilieres = (j['filieres'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Liste complète de fallback (toutes les filières connues)
    const defaultFilieres = [
      'Génie Logiciel',
      'Administration et Sécurité des Réseaux',
      'Génie Informatique',
      'Génie Réseau et Télécommunications',
      "Mention des technologies de l'information et du numérique",
      'Génie Électrique et Informatique Industrielle',
      'Mécatronique',
      'Génie Industriel et Maintenance',
      'Génie Mécanique et Productique',
      'Logistique Industrielle',
      'Génie Thermique et Énergie',
      "Économie d'Énergie et Environnement",
      'Valorisation des Énergies Renouvelables',
      'Génie Civil',
      'Génie des Mines',
      'Génie Métallurgique',
      'Génie Ferroviaire',
      'Météorologie',
      'Licence en Pétrole et Gaz',
      'Génie Biomédical',
      'Chimie Pharmaceutique',
      'Qualité, Hygiène et Salubrité des Aliments',
      'Chimie Industrielle et Pharmaceutique',
      'Gestion des Entreprises et des Administrations',
      'Génie Logistique et Transport',
      'Techniques de Commercialisation',
      'Négociation Vente',
      'Gestion des Ressources Humaines',
      'Assistant Manager',
      'Organisation et Gestion Administrative',
      'Gestion Appliquée aux Petites et Moyennes Organisations',
      'Gestion Comptable et Financière',
      'Gestion Bancaire et Financière',
      'Banque et Finances',
    ];

    // Merger : backend d'abord, puis défaut sans doublons
    final all = {...backendFilieres, ...defaultFilieres}.toList()..sort();

    return EtablissementInfo(
      id: j['id'] ?? '',
      nom: j['nom'] ?? '',
      ville: j['ville'] ?? '',
      filieres: all,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN D'INSCRIPTION PROFESSEUR
// ══════════════════════════════════════════════════════════════════

class RegisterTeacherScreen extends ConsumerStatefulWidget {
  const RegisterTeacherScreen({super.key});

  @override
  ConsumerState<RegisterTeacherScreen> createState() =>
      _RegisterTeacherScreenState();
}

class _RegisterTeacherScreenState
    extends ConsumerState<RegisterTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _etabIdController = TextEditingController();
  final _matiereController = TextEditingController();

  EtablissementInfo? _etablissement;
  bool _isLookingUp = false;
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  // Filières sélectionnées
  final List<String> _selectedFilieres = [];
  // Matières saisies
  final List<String> _matieres = [];

  Timer? _debounce;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _etabIdController.dispose();
    _matiereController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Recherche automatique de l'établissement ──────────────────────
  Future<void> _lookupEtablissement(String codeId) async {
    if (codeId.trim().length < 3) {
      setState(() {
        _etablissement = null;
        _selectedFilieres.clear();
      });
      return;
    }

    setState(() => _isLookingUp = true);

    try {
      final resp = await ApiClient.getPublic(
        '/auth/etablissement/${codeId.trim()}',
      );

      if (resp != null && resp['etablissement'] != null) {
        final etab =
            EtablissementInfo.fromJson(resp['etablissement'] as Map<String, dynamic>);
        setState(() {
          _etablissement = etab;
          _isLookingUp = false;
          _error = null;
        });
      } else {
        setState(() {
          _etablissement = null;
          _selectedFilieres.clear();
          _isLookingUp = false;
          _error = 'Établissement introuvable';
        });
      }
    } catch (e) {
      setState(() {
        _etablissement = null;
        _selectedFilieres.clear();
        _isLookingUp = false;
        _error = 'Établissement introuvable';
      });
    }
  }

  // ── Ajouter une matière ──────────────────────────────────────────
  void _addMatiere() {
    final text = _matiereController.text.trim();
    if (text.isEmpty || _matieres.contains(text)) return;
    setState(() {
      _matieres.add(text);
      _matiereController.clear();
    });
  }

  void _removeMatiere(String matiere) {
    setState(() => _matieres.remove(matiere));
  }

  // ── Soumettre le formulaire ──────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_etablissement == null) {
      setState(() => _error = 'Veuillez sélectionner un établissement valide');
      return;
    }
    if (_selectedFilieres.isEmpty) {
      setState(() => _error = 'Veuillez sélectionner au moins une filière');
      return;
    }
    if (_matieres.isEmpty) {
      setState(() => _error = 'Veuillez ajouter au moins une matière');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final resp = await ApiClient.postPublic('/auth/register-teacher', data: {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'email': _emailController.text.trim(),
        'etablissementId': _etablissement!.id,
        'filieres': _selectedFilieres,
        'matieres': _matieres,
      });

      if (resp != null && resp['message'] != null) {
        setState(() {
          _success = resp['message'] as String;
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _error = 'Erreur inattendue';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('email existe déjà')
            ? 'Un compte avec cet email existe déjà'
            : 'Erreur lors de l\'inscription. Veuillez réessayer.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // ── Succès ──────────────────────────────────────────────────────
    if (_success != null) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 60, color: AppColors.green),
                ),
                const SizedBox(height: 24),
                Text(
                  'Inscription réussie !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _success!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          size: 20, color: AppColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vérifiez votre boîte email pour vos identifiants de connexion.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'Se connecter',
                  icon: Icons.login_rounded,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Formulaire ──────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Row(
        children: [
          // Partie décorative (Desktop)
          if (isDesktop)
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'lib/assets/logos/univ.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.red.withValues(alpha: 0.85),
                            AppColors.orange.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded,
                              size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Inscription Professeur",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const Text(
                          "SmartCampus",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Formulaire
          Container(
            width: isDesktop ? 550 : screenWidth,
            height: double.infinity,
            color: isDesktop ? Colors.transparent : context.bgColor,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  40,
                  MediaQuery.of(context).padding.top + 24,
                  40,
                  24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Titre
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.school_rounded,
                                      size: 24, color: AppColors.orange),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Inscription Professeur',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Créez votre compte enseignant',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Erreur
                            if (_error != null) ...[
                              _buildErrorBox(_error!),
                              const SizedBox(height: 16),
                            ],

                            // Nom
                            _buildLabel('Nom *'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nomController,
                              decoration: const InputDecoration(
                                hintText: 'Votre nom',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Champ requis'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // Prénom
                            _buildLabel('Prénom *'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _prenomController,
                              decoration: const InputDecoration(
                                hintText: 'Votre prénom',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    size: 20),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Champ requis'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            // Email
                            _buildLabel('Adresse e-mail *'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'professeur@email.com',
                                prefixIcon: Icon(Icons.email_outlined,
                                    size: 20),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Champ requis';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(v.trim())) {
                                  return 'Email invalide';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ID Établissement
                            _buildLabel('ID Établissement *'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _etabIdController,
                              decoration: InputDecoration(
                                hintText: 'Entrez l\'ID de votre établissement',
                                prefixIcon: const Icon(Icons.school_outlined,
                                    size: 20),
                                suffixIcon: _isLookingUp
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : _etablissement != null
                                        ? const Icon(Icons.check_circle,
                                            color: AppColors.green, size: 20)
                                        : null,
                              ),
                              onChanged: (value) {
                                _debounce?.cancel();
                                _debounce = Timer(
                                    const Duration(milliseconds: 500), () {
                                  _lookupEtablissement(value);
                                });
                              },
                              validator: (v) => _etablissement == null
                                  ? 'Vérifiez l\'ID de l\'établissement'
                                  : null,
                            ),

                            // Affichage de l'établissement trouvé
                            if (_etablissement != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          AppColors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 18, color: AppColors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _etablissement!.nom,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: context.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            _etablissement!.ville,
                                            style: TextStyle(
                                              color: context.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Filières enseignées
                            if (_etablissement != null &&
                                _etablissement!.filieres.isNotEmpty) ...[
                              _buildLabel('Filières enseignées *'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    _etablissement!.filieres.map((filiere) {
                                  final selected =
                                      _selectedFilieres.contains(filiere);
                                  return FilterChip(
                                    label: Text(filiere),
                                    selected: selected,
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
                                          _selectedFilieres.add(filiere);
                                        } else {
                                          _selectedFilieres.remove(filiere);
                                        }
                                      });
                                    },
                                    selectedColor:
                                        AppColors.orange.withValues(alpha: 0.2),
                                    checkmarkColor: AppColors.orange,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Matières enseignées
                            _buildLabel('Matières enseignées *'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _matiereController,
                                    decoration: const InputDecoration(
                                      hintText: 'Ex: Algorithmique',
                                      prefixIcon: Icon(Icons.book_outlined,
                                          size: 20),
                                    ),
                                    onSubmitted: (_) => _addMatiere(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addMatiere,
                                  icon: const Icon(Icons.add_circle_rounded),
                                  color: AppColors.orange,
                                ),
                              ],
                            ),
                            if (_matieres.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _matieres.map((m) {
                                  return Chip(
                                    label: Text(m),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 16),
                                    onDeleted: () => _removeMatiere(m),
                                    backgroundColor:
                                        AppColors.orange.withValues(alpha: 0.1),
                                    side: BorderSide(
                                        color: AppColors.orange
                                            .withValues(alpha: 0.3)),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 28),

                            // Bouton soumettre
                            GradientButton(
                              label: 'Créer mon compte',
                              icon: Icons.person_add_rounded,
                              loading: _isSubmitting,
                              onPressed:
                                  _isSubmitting ? null : _submit,
                            ),

                            const SizedBox(height: 16),

                            // Retour à la connexion
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Déjà un compte ? Se connecter',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
