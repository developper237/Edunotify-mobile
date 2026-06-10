import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';

// ── Providers pour les listes API ────────────────────────────────
final departementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final resp = await ApiClient.get('/departements');
  final list = resp['data'] as List<dynamic>;
  return list.map((e) => e as Map<String, dynamic>).toList();
});

final classesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, departementId) async {
    final resp = await ApiClient.get('/classes', params: {'departementId': departementId});
    final list = resp['data'] as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  },
);

// ── Screen ───────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Étape 1
  final _prenom    = TextEditingController();
  final _nom       = TextEditingController();
  final _email     = TextEditingController();
  final _password  = TextEditingController();
  final _password2 = TextEditingController();
  bool _showPass   = false;

  // Étape 2
  final _matricule        = TextEditingController();
  String? _departementId;
  String? _classeId;
  String? _niveau;
  String? _formation;
  bool _showFormation = false;

  bool _loading = false;
  String? _error;
  bool _done = false;


  @override
  void dispose() {
    _pageController.dispose();
    _prenom.dispose(); _nom.dispose();
    _email.dispose(); _password.dispose(); _password2.dispose();
    _matricule.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validation étape 1
    if (_prenom.text.trim().isEmpty ||
        _nom.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Remplis tous les champs obligatoires');
      return;
    }
    if (_password.text != _password2.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Mot de passe : minimum 8 caractères');
      return;
    }
    setState(() { _error = null; _currentPage = 1; });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    setState(() { _error = null; _currentPage = 0; });
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    if (_matricule.text.trim().isEmpty ||
        _departementId == null ||
        _classeId == null ||
        _niveau == null) {
      setState(() => _error = 'Remplis tous les champs obligatoires');
      return;
    }
    if (_showFormation && _formation == null) {
      setState(() => _error = 'Choisis ta formation (jour ou soir)');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.post('/auth/register', data: {
        'prenom':       _prenom.text.trim(),
        'nom':          _nom.text.trim(),
        'email':        _email.text.trim(),
        'password':     _password.text,
        'matricule':    _matricule.text.trim(),
        'departementId': _departementId,
        'classeId':     _classeId,
        'niveau':       _niveau,
        if (_formation != null) 'formation': _formation,
        'role':         'etudiant',
      });
      setState(() { _done = true; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; });
    } catch (_) {
      setState(() { _error = 'Erreur lors de l\'inscription'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _SuccessView(onBack: () => Navigator.pop(context));

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => _currentPage == 0
              ? Navigator.pop(context)
              : _prevPage(),
        ),
        title: const Text('Créer un compte'),
      ),
      body: Column(
        children: [
          // ── Indicateur de progression ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage >= 1
                          ? AppColors.cyan
                          : AppColors.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Étape ${_currentPage + 1} sur 2',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _currentPage == 0 ? 'Informations personnelles' : 'Infos académiques',
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Erreur ──
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: AppColors.red, fontSize: 13))),
                  ],
                ),
              ),
            ),

          // ── Pages ──
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Page1(
                  prenom: _prenom, nom: _nom,
                  email: _email, password: _password, password2: _password2,
                  showPass: _showPass,
                  onTogglePass: () => setState(() => _showPass = !_showPass),
                  onNext: _nextPage,
                ),
                _Page2(
                  matricule: _matricule,
                  departementId: _departementId,
                  classeId: _classeId,
                  niveau: _niveau,
                  formation: _formation,
                  showFormation: _showFormation,
                  loading: _loading,
                  onDepartementChanged: (id) => setState(() {
                    _departementId = id;
                    _classeId = null;
                  }),
                  onClasseChanged: (id) => setState(() => _classeId = id),
                  onNiveauChanged: (n) => setState(() {
                    _niveau = n;
                    _showFormation = n == 'L1' || n == 'L2';
                    if (!_showFormation) _formation = null;
                  }),
                  onFormationChanged: (f) => setState(() => _formation = f),
                  onSubmit: _submit,
                  ref: ref,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Étape 1 — Infos personnelles ─────────────────────────────────
class _Page1 extends StatelessWidget {
  final TextEditingController prenom, nom, email, password, password2;
  final bool showPass;
  final VoidCallback onTogglePass, onNext;

  const _Page1({
    required this.prenom, required this.nom,
    required this.email, required this.password, required this.password2,
    required this.showPass, required this.onTogglePass, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _Row2(
            left: _Field(label: 'Prénom', controller: prenom, hint: 'Jean'),
            right: _Field(label: 'Nom', controller: nom, hint: 'Dupont'),
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Email',
            controller: email,
            hint: 'jean.dupont@iut.cm',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Mot de passe',
            controller: password,
            hint: 'Min. 8 caractères',
            obscure: !showPass,
            suffix: IconButton(
              icon: Icon(
                showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textMuted, size: 20,
              ),
              onPressed: onTogglePass,
            ),
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'Confirmer le mot de passe',
            controller: password2,
            hint: '••••••••',
            obscure: !showPass,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNext,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}

// ── Étape 2 — Infos académiques ──────────────────────────────────
class _Page2 extends StatelessWidget {
  final TextEditingController matricule;
  final String? departementId, classeId, niveau, formation;
  final bool showFormation, loading;
  final void Function(String?) onDepartementChanged;
  final void Function(String?) onClasseChanged;
  final void Function(String?) onNiveauChanged;
  final void Function(String?) onFormationChanged;
  final VoidCallback onSubmit;
  final WidgetRef ref;

  const _Page2({
    required this.matricule,
    required this.departementId, required this.classeId,
    required this.niveau, required this.formation,
    required this.showFormation, required this.loading,
    required this.onDepartementChanged, required this.onClasseChanged,
    required this.onNiveauChanged, required this.onFormationChanged,
    required this.onSubmit, required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final departements = ref.watch(departementsProvider);
    final classes = departementId != null
        ? ref.watch(classesProvider(departementId!))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _Field(
            label: 'Matricule',
            controller: matricule,
            hint: 'Ex: 21G0001',
          ),
          const SizedBox(height: 16),

          // Département
          _Label('Département'),
          const SizedBox(height: 8),
          departements.when(
            loading: () => _LoadingDropdown(),
            error: (_, __) => _ErrorDropdown('Impossible de charger les départements'),
            data: (list) => _Dropdown(
              hint: 'Sélectionne ton département',
              value: departementId,
              items: list.map((d) => DropdownMenuItem<String>(
                value: d['id'] as String,
                child: Text(d['nom'] as String,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              )).toList(),
              onChanged: onDepartementChanged,
            ),
          ),
          const SizedBox(height: 16),

          // Classe
          _Label('Classe / Salle'),
          const SizedBox(height: 8),
          if (departementId == null)
            _ErrorDropdown('Sélectionne d\'abord un département')
          else
            classes!.when(
              loading: () => _LoadingDropdown(),
              error: (_, __) => _ErrorDropdown('Impossible de charger les classes'),
              data: (list) => _Dropdown(
                hint: 'Sélectionne ta classe',
                value: classeId,
                items: list.map((c) => DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(c['nom'] as String,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                )).toList(),
                onChanged: onClasseChanged,
              ),
            ),
          const SizedBox(height: 16),

          // Niveau
          _Label('Niveau'),
          const SizedBox(height: 8),
          _Dropdown(
            hint: 'Sélectionne ton niveau',
            value: niveau,
            items: ['L1', 'L2', 'L3', 'M1', 'M2'].map((n) => DropdownMenuItem(
              value: n,
              child: Text(n, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            )).toList(),
            onChanged: onNiveauChanged,
          ),

          // Formation (L1 / L2 seulement)
          if (showFormation) ...[
            const SizedBox(height: 16),
            _Label('Formation'),
            const SizedBox(height: 8),
            _Dropdown(
              hint: 'Cours du jour ou du soir',
              value: formation,
              items: ['Cours du jour', 'Cours du soir'].map((f) => DropdownMenuItem(
                value: f,
                child: Text(f, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              )).toList(),
              onChanged: onFormationChanged,
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                : const Text('Créer mon compte'),
          ),
        ],
      ),
    );
  }
}

// ── Écran succès ──────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onBack;
  const _SuccessView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.green, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Compte créé !',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text(
                'Un email de confirmation t\'a été envoyé.\nClique sur le lien pour activer ton compte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: onBack,
                child: const Text('Retour à la connexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ],
    );
  }
}

class _Row2 extends StatelessWidget {
  final Widget left, right;
  const _Row2({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary,
          fontSize: 13, fontWeight: FontWeight.w500));
}

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final void Function(String?)? onChanged;

  const _Dropdown({
    required this.hint, required this.value,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          isExpanded: true,
          dropdownColor: AppColors.darkCard,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LoadingDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Row(
        children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)),
          SizedBox(width: 12),
          Text('Chargement...', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorDropdown extends StatelessWidget {
  final String message;
  const _ErrorDropdown(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}