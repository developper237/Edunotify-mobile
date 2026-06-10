import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODELE
// ══════════════════════════════════════════════════════════════════

class Etablissement {
  final String id;
  final String nom;
  final String ville;
  final String plan;
  final int etudiants;
  final bool actif;
  final String? emailAdmin;
  final String? logoUrl;

  const Etablissement({
    required this.id,
    required this.nom,
    required this.ville,
    required this.plan,
    required this.etudiants,
    required this.actif,
    this.emailAdmin,
    this.logoUrl,
  });

  bool get isPremium => plan == 'premium';

  factory Etablissement.fromJson(Map<String, dynamic> j) => Etablissement(
    id:         j['id'] ?? '',
    nom:        j['nom'] ?? '',
    ville:      j['ville'] ?? '',
    plan:       j['plan'] ?? 'free',
    etudiants:  j['_count']?['users'] ?? j['etudiants'] ?? 0,
    actif:      j['actif'] ?? true,
    emailAdmin: j['emailAdmin'],
    logoUrl:    j['logoUrl'],
  );

  Etablissement copyWith({bool? actif, String? plan}) => Etablissement(
    id:         id,
    nom:        nom,
    ville:      ville,
    plan:       plan  ?? this.plan,
    etudiants:  etudiants,
    actif:      actif ?? this.actif,
    emailAdmin: emailAdmin,
    logoUrl:    logoUrl,
  );
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER — connecté au backend
// ══════════════════════════════════════════════════════════════════

final etablissementsProvider =
StateNotifierProvider<EtablissementsNotifier,
    AsyncValue<List<Etablissement>>>(
      (ref) => EtablissementsNotifier(ref),
);

class EtablissementsNotifier
    extends StateNotifier<AsyncValue<List<Etablissement>>> {
  final Ref _ref;

  EtablissementsNotifier(this._ref) : super(const AsyncLoading()) {
    charger();
  }

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecté');

      final resp = await ApiClient.get('/auth/cascade/etablissements');

      final liste = (resp['etablissements'] as List<dynamic>? ?? [])
          .map((e) => Etablissement.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncData(liste);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> toggleActif(String id) async {
    final etabs = state.value ?? [];
    final etab  = etabs.firstWhere((e) => e.id == id);

    state = AsyncData(
      etabs.map((e) => e.id == id ? e.copyWith(actif: !e.actif) : e).toList(),
    );

    try {
      await ApiClient.patch(
        '/auth/cascade/etablissement/$id/statut',
        data: {'actif': !etab.actif},
      );
    } catch (_) {
      state = AsyncData(
        (state.value ?? []).map((e) => e.id == id ? e.copyWith(actif: etab.actif) : e).toList(),
      );
    }
  }

  Future<void> togglePlan(String id) async {
    final etabs   = state.value ?? [];
    final etab    = etabs.firstWhere((e) => e.id == id);
    final newPlan = etab.isPremium ? 'free' : 'premium';

    state = AsyncData(
      etabs.map((e) => e.id == id ? e.copyWith(plan: newPlan) : e).toList(),
    );

    try {
      await ApiClient.patch(
        '/auth/cascade/etablissement/$id/plan',
        data: {'plan': newPlan},
      );
    } catch (_) {
      state = AsyncData(
        (state.value ?? []).map((e) => e.id == id ? e.copyWith(plan: etab.plan) : e).toList(),
      );
    }
  }

  void ajouter(Etablissement etab) {
    final current = state.value ?? [];
    state = AsyncData([etab, ...current]);
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class EtablissementsScreen extends ConsumerWidget {
  const EtablissementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s          = ref.watch(stringsProvider);
    final etabsAsync = ref.watch(etablissementsProvider);
    const primaryColor = AppColors.dark;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          // Header dégradé fidèle aux autres écrans
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Color(0xFF454545)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Plateforme SaaS", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        IconButton(
                          onPressed: () => ref.read(etablissementsProvider.notifier).charger(),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.schools, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                        GestureDetector(
                          onTap: () => _showAjouterModal(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Liste avec l'arrondi caractéristique
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: etabsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: context.textMuted),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement', style: TextStyle(color: context.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(etablissementsProvider.notifier).charger(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
                data: (etabs) => etabs.isEmpty
                    ? Center(child: Text('Aucun établissement', style: TextStyle(color: context.textMuted)))
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  itemCount: etabs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _EtabTile(etab: etabs[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAjouterModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AjouterEtabModal(
        onAjouter: (etab) => ref.read(etablissementsProvider.notifier).ajouter(etab),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE ÉPURÉE
// ══════════════════════════════════════════════════════════════════

class _EtabTile extends ConsumerWidget {
  final Etablissement etab;
  const _EtabTile({required this.etab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: etab.actif ? context.borderColor : AppColors.red.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.cyan, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etab.nom,
                        style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(etab.emailAdmin ?? etab.ville,
                        style: TextStyle(color: context.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              _PlanBadge(etab: etab),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoMini(Icons.location_on_rounded, etab.ville, context),
              const SizedBox(width: 16),
              _infoMini(Icons.people_alt_rounded, '${etab.etudiants} étud.', context),
              const Spacer(),
              _StatusIndicator(actif: etab.actif),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'Détails',
                  icon: Icons.visibility_rounded,
                  color: AppColors.dark,
                  onTap: () => _showDetailsModal(context),
                ),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: etab.actif ? 'Bloquer' : 'Activer',
                icon: etab.actif ? Icons.block_rounded : Icons.check_circle_rounded,
                color: etab.actif ? AppColors.red : AppColors.green,
                onTap: () => _confirmToggleActif(context, ref),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: etab.isPremium ? 'Free' : 'Premium',
                icon: Icons.star_rounded,
                color: AppColors.yellow,
                onTap: () => _confirmTogglePlan(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoMini(IconData icon, String text, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: context.textMuted, fontSize: 12)),
      ],
    );
  }

  void _showDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsModal(etab: etab),
    );
  }

  void _confirmToggleActif(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(etab.actif ? 'Désactiver ?' : 'Activer ?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(etab.actif
            ? 'Les utilisateurs de ${etab.nom} ne pourront plus accéder à la plateforme.'
            : 'L\'accès sera rétabli pour ${etab.nom}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: context.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: etab.actif ? AppColors.red : AppColors.green),
            onPressed: () {
              Navigator.pop(context);
              ref.read(etablissementsProvider.notifier).toggleActif(etab.id);
            },
            child: Text(etab.actif ? 'Confirmer' : 'Activer', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmTogglePlan(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(etab.isPremium ? 'Rétrograder ?' : 'Passer Premium ?', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: context.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
            onPressed: () {
              Navigator.pop(context);
              ref.read(etablissementsProvider.notifier).togglePlan(etab.id);
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PETITS COMPOSANTS DE STYLE
// ══════════════════════════════════════════════════════════════════

class _PlanBadge extends StatelessWidget {
  final Etablissement etab;
  const _PlanBadge({required this.etab});

  @override
  Widget build(BuildContext context) {
    final color = etab.isPremium ? AppColors.yellow : context.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        etab.plan.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool actif;
  const _StatusIndicator({required this.actif});

  @override
  Widget build(BuildContext context) {
    final color = actif ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(actif ? 'ACTIF' : 'BLOQUÉ', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL DETAILS DESIGN
// ══════════════════════════════════════════════════════════════════

class _DetailsModal extends StatelessWidget {
  final Etablissement etab;
  const _DetailsModal({required this.etab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.school_outlined, color: AppColors.cyan, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etab.nom, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Établissement rattaché', style: TextStyle(color: context.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.dark : AppColors.light,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                _statDashboard('Inscrits', '${etab.etudiants}', AppColors.cyan),
                _statDashboard('Plan', etab.plan.toUpperCase(), etab.isPremium ? AppColors.yellow : AppColors.textMuted),
                _statDashboard('Statut', etab.actif ? 'Actif' : 'Inactif', etab.actif ? AppColors.green : AppColors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _infoRow(context, Icons.map_rounded, 'Localisation', etab.ville),
          _infoRow(context, Icons.email_rounded, 'Email Administrateur', etab.emailAdmin ?? 'Non renseigné'),
          _infoRow(context, Icons.fingerprint_rounded, 'Identifiant Unique', etab.id),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDashboard(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textMuted),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: context.textMuted, fontSize: 11)),
              Text(value, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL AJOUTER ETABLISSEMENT
// ══════════════════════════════════════════════════════════════════

class _AjouterEtabModal extends StatefulWidget {
  final void Function(Etablissement) onAjouter;
  const _AjouterEtabModal({required this.onAjouter});

  @override
  State<_AjouterEtabModal> createState() => _AjouterEtabModalState();
}

class _AjouterEtabModalState extends State<_AjouterEtabModal> {
  final _nom = TextEditingController();
  final _ville = TextEditingController();
  final _email = TextEditingController();
  final _prenomAdmin = TextEditingController();
  final _nomAdmin = TextEditingController();
  String _plan = 'free';
  bool _loading = false;
  bool _done = false;
  Uint8List? _logoBytes;
  String? _logoName;
  String? _error;

  @override
  void dispose() {
    _nom.dispose(); _ville.dispose(); _email.dispose();
    _prenomAdmin.dispose(); _nomAdmin.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _logoBytes = result.files.first.bytes;
        _logoName = result.files.first.name;
      });
    }
  }

  Future<void> _ajouter() async {
    setState(() => _error = null);
    if (_nom.text.trim().isEmpty || _ville.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez remplir les champs obligatoires');
      return;
    }

    setState(() => _loading = true);
    try {
      final resp = await ApiClient.post('/auth/cascade/etablissement', data: {
        'nom': _nom.text.trim(),
        'ville': _ville.text.trim(),
        'plan': _plan,
        'emailAdmin': _email.text.trim(),
        'prenomAdmin': _prenomAdmin.text.trim(),
        'nomAdmin': _nomAdmin.text.trim(),
      });

      final etabJson = resp['etablissement'] as Map<String, dynamic>?;
      final etab = Etablissement(
        id: etabJson?['id'] ?? 'etab-${DateTime.now().millisecondsSinceEpoch}',
        nom: _nom.text.trim(), ville: _ville.text.trim(),
        plan: _plan, etudiants: 0, actif: true, emailAdmin: _email.text.trim(),
      );

      widget.onAjouter(etab);
      setState(() { _loading = false; _done = true; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Échec de la création'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _done
          ? _SuccessView(
        titre: 'Félicitations !',
        message: 'L\'établissement ${_nom.text} a été créé. Les accès admin ont été envoyés à ${_email.text}.',
        onClose: () => Navigator.pop(context),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Nouvel établissement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // Section Logo
            _FieldLabel('Logo de l\'institution', context),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.isDark ? AppColors.dark : AppColors.light,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _logoBytes != null ? AppColors.cyan : context.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_logoBytes != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded, color: _logoBytes != null ? AppColors.green : context.textMuted),
                    const SizedBox(width: 12),
                    Text(_logoName ?? 'Choisir un logo (PNG/JPG)', style: TextStyle(color: context.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _buildInput(_nom, 'Nom de l\'établissement', Icons.school_rounded, context),
            _buildInput(_ville, 'Ville', Icons.location_on_rounded, context),

            const Divider(height: 40),
            const Text('Administrateur Principal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cyan)),
            const SizedBox(height: 16),

            _buildInput(_prenomAdmin, 'Prénom', Icons.person_rounded, context),
            _buildInput(_nomAdmin, 'Nom', Icons.person_outline_rounded, context),
            _buildInput(_email, 'Email professionnel', Icons.alternate_email_rounded, context),

            const SizedBox(height: 10),
            _FieldLabel('Plan d\'abonnement', context),
            const SizedBox(height: 10),
            Row(
              children: ['free', 'premium'].map((p) {
                final selected = _plan == p;
                final color = p == 'premium' ? AppColors.yellow : AppColors.cyan;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _plan = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: p == 'free' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? color : context.borderColor, width: selected ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Icon(p == 'premium' ? Icons.workspace_premium_rounded : Icons.star_border_rounded, color: selected ? color : context.textMuted),
                          const SizedBox(height: 4),
                          Text(p.toUpperCase(), style: TextStyle(color: selected ? color : context.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13))),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _loading ? null : _ajouter,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CRÉER L\'ÉTABLISSEMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: context.textMuted),
          filled: true,
          fillColor: context.isDark ? AppColors.dark.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS DE STYLE
// ══════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _FieldLabel(this.text, this.ctx);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(text, style: TextStyle(color: ctx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _SuccessView extends StatelessWidget {
  final String titre, message;
  final VoidCallback onClose;
  const _SuccessView({required this.titre, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 80),
        const SizedBox(height: 20),
        Text(titre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted, height: 1.5)),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: onClose,
            child: const Text('TERMINER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
