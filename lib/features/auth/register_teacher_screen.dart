import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Remplissage des champs (gris très clair, comme la maquette).
  static const _fieldLight = Color(0xFFF4F6F9);
  static const _fieldDark = Color(0xFF1A2033);

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
    final isDark = context.isDark;

    return Scaffold(
      body: Container(
        // Fond : blanc en haut, bleu très clair en bas (comme la maquette)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.28, 1.0],
            colors: isDark
                ? const [AppColors.dark, Color(0xFF14243E)]
                : const [Colors.white, Color(0xFFD9E9FA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── LOGO (sans cercle ni halo coloré) ──
                    Image.asset(
                      'lib/assets/logos/logosmart.png',
                      width: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.school_rounded,
                        size: 64,
                        color: AppColors.cyan,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── TITRE / SOUS-TITRE ──
                    Text(
                      'Inscription Professeur',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Créez votre compte enseignant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── CARTE BLANCHE ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : Colors.white,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Erreur
                            if (_error != null) ...[
                              _buildErrorBox(_error!),
                              const SizedBox(height: 12),
                            ],

                            // Nom
                            _buildField(
                              controller: _nomController,
                              hint: 'Nom',
                              icon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Champ requis'
                                  : null,
                            ),

                            const SizedBox(height: 12),

                            // Prénom
                            _buildField(
                              controller: _prenomController,
                              hint: 'Prénom',
                              icon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Champ requis'
                                  : null,
                            ),

                            const SizedBox(height: 12),

                            // Email
                            _buildField(
                              controller: _emailController,
                              hint: 'Adresse e-mail',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
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

                            const SizedBox(height: 12),

                            // ID Établissement
                            _buildField(
                              controller: _etabIdController,
                              hint: 'ID de l\'établissement',
                              icon: Icons.school_outlined,
                              suffix: _isLookingUp
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
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.green
                                          .withValues(alpha: 0.3)),
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

                            // Filières enseignées (sélection : ce n'est pas un
                            // champ de saisie, le titre reste nécessaire)
                            if (_etablissement != null &&
                                _etablissement!.filieres.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Filières enseignées',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                            ],

                            const SizedBox(height: 12),

                            // Matières enseignées (saisie + ajout)
                            _buildField(
                              controller: _matiereController,
                              hint: 'Matière (ex: Algorithmique)',
                              icon: Icons.book_outlined,
                              onSubmitted: (_) => _addMatiere(),
                              suffix: IconButton(
                                onPressed: _addMatiere,
                                icon: const Icon(Icons.add_circle_rounded),
                                color: AppColors.orange,
                              ),
                            ),

                            if (_matieres.isNotEmpty) ...[
                              const SizedBox(height: 10),
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

                            const SizedBox(height: 20),

                            // Bouton soumettre
                            GradientButton(
                              label: 'Créer mon compte',
                              icon: Icons.person_add_rounded,
                              loading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _submit,
                            ),

                            const SizedBox(height: 6),

                            // Retour à la connexion
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
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
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'SmartCampus',
                      style: TextStyle(
                        color: context.textMuted.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Champ arrondi, fond gris clair, sans libellé : l'info est dans le
  /// placeholder (comme la maquette).
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    final isDark = context.isDark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(fontSize: 15, color: context.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: isDark ? _fieldDark : _fieldLight,
        prefixIcon: Icon(icon, size: 20, color: context.textMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 24),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8EDF3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
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
