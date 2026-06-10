import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODELE
// ══════════════════════════════════════════════════════════════════

class Departement {
  final String id;
  final String nom;
  final String description;
  final String emailChef;
  final String nomChef;
  final int nbClasses;

  const Departement({
    required this.id,
    required this.nom,
    required this.description,
    required this.emailChef,
    required this.nomChef,
    required this.nbClasses,
  });

  factory Departement.fromJson(Map<String, dynamic> j) {
    final chefs = j['chefs'] as List? ?? [];
    final chef = chefs.isNotEmpty ? chefs.first as Map<String, dynamic> : null;

    return Departement(
      id: j['id'] ?? '',
      nom: j['nom'] ?? '',
      description: j['description'] ?? '',
      emailChef: chef?['email'] ?? '',
      nomChef: chef != null
          ? '${chef['prenom'] ?? ''} ${chef['nom'] ?? ''}'.trim()
          : '',
      nbClasses: (j['_count'] as Map<String, dynamic>?)?['classes'] ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final departementsProvider =
StateNotifierProvider.autoDispose<DepartementsNotifier, AsyncValue<List<Departement>>>(
      (ref) => DepartementsNotifier(ref),
);

class DepartementsNotifier extends StateNotifier<AsyncValue<List<Departement>>> {
  final AutoDisposeRef _ref;
  DepartementsNotifier(this._ref) : super(const AsyncLoading()) {
    charger();
  }

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecté');

      final resp = await ApiClient.get('/auth/cascade/departements');

      final list = resp['departements'] as List? ?? [];
      state = AsyncData(
        list.map((d) => Departement.fromJson(d as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  void ajouterLocal(Departement dept) {
    state.whenData((current) => state = AsyncData([dept, ...current]));
  }

  void modifierLocal(String id, String nom, String description) {
    state.whenData((current) {
      state = AsyncData(
        current.map((d) => d.id == id
            ? Departement(
          id: d.id,
          nom: nom,
          description: description,
          emailChef: d.emailChef,
          nomChef: d.nomChef,
          nbClasses: d.nbClasses,
        )
            : d).toList(),
      );
    });
  }

  void supprimerLocal(String id) {
    state.whenData((current) => state = AsyncData(current.where((d) => d.id != id).toList()));
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class DepartementsScreen extends ConsumerWidget {
  const DepartementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(departementsProvider);
    final user = ref.watch(currentUserProvider);
    final primaryColor = AppColors.forRole(user?.role ?? 'admin');

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gestion", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 4),
                        Text("Départements",
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ],
                    ),
                    _HeaderAddButton(onTap: () => _showAjouterModal(context, ref)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: deptsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorState(onRetry: () => ref.read(departementsProvider.notifier).charger()),
                data: (depts) => depts.isEmpty
                    ? _EmptyState(onAction: () => _showAjouterModal(context, ref))
                    : RefreshIndicator(
                  onRefresh: () => ref.read(departementsProvider.notifier).charger(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    itemCount: depts.length,
                    itemBuilder: (_, i) => _DeptCard(dept: depts[i]),
                  ),
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
      builder: (_) => _DeptFormModal(
        onCreer: (dept) => ref.read(departementsProvider.notifier).ajouterLocal(dept),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// COMPOSANTS DESIGN
// ══════════════════════════════════════════════════════════════════

class _HeaderAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeaderAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text("Ajouter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DeptCard extends ConsumerWidget {
  final Departement dept;
  const _DeptCard({required this.dept});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeptIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept.nom,
                        style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(dept.description,
                        style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _ClasseBadge(count: dept.nbClasses),
            ],
          ),
          const SizedBox(height: 18),
          _ChefInfo(nomChef: dept.nomChef, email: dept.emailChef),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'Modifier',
                  icon: Icons.edit_note_rounded,
                  color: AppColors.blue,
                  onTap: () => _showModifierModal(context, ref),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionBtn(
                  label: 'Supprimer',
                  icon: Icons.delete_sweep_rounded,
                  color: AppColors.red,
                  onTap: () => _confirmSupprimer(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showModifierModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeptFormModal(
        dept: dept,
        onModifier: (nom, description) => ref
            .read(departementsProvider.notifier)
            .modifierLocal(dept.id, nom, description),
      ),
    );
  }

  void _confirmSupprimer(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Le département "${dept.nom}" sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: context.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiClient.delete('/auth/cascade/departement/${dept.id}');
                ref.read(departementsProvider.notifier).supprimerLocal(dept.id);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DeptIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.account_tree_rounded, color: AppColors.blue, size: 24),
    );
  }
}

class _ClasseBadge extends StatelessWidget {
  final int count;
  const _ClasseBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text("$count", style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w800, fontSize: 14)),
          const Text("cls", style: TextStyle(color: AppColors.violet, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChefInfo extends StatelessWidget {
  final String nomChef, email;
  const _ChefInfo({required this.nomChef, required this.email});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: context.borderColor, shape: BoxShape.circle),
          child: Icon(Icons.person, size: 14, color: context.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nomChef.isNotEmpty ? nomChef : "Chef non défini",
                  style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(email, style: TextStyle(color: context.textMuted, fontSize: 11)),
            ],
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
      color: color,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeptFormModal extends StatefulWidget {
  final Departement? dept;
  final void Function(Departement)? onCreer;
  final void Function(String, String)? onModifier;
  const _DeptFormModal({this.dept, this.onCreer, this.onModifier});

  @override
  State<_DeptFormModal> createState() => _DeptFormModalState();
}

class _DeptFormModalState extends State<_DeptFormModal> {
  late final TextEditingController _nom;
  late final TextEditingController _description;
  late final TextEditingController _emailChef;
  late final TextEditingController _prenomChef;
  late final TextEditingController _nomChef;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.dept?.nom ?? '');
    _description = TextEditingController(text: widget.dept?.description ?? '');
    _emailChef = TextEditingController();
    _prenomChef = TextEditingController();
    _nomChef = TextEditingController();
  }

  Future<void> _save() async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _error = 'Nom requis');
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.dept != null) {
        await ApiClient.put('/auth/cascade/departement/${widget.dept!.id}', data: {
          'nom': _nom.text.trim(),
          'description': _description.text.trim(),
        });
        widget.onModifier?.call(_nom.text.trim(), _description.text.trim());
      } else {
        final resp = await ApiClient.post('/auth/cascade/departement', data: {
          'nom': _nom.text.trim(),
          'description': _description.text.trim(),
          'emailChef': _emailChef.text.trim(),
          'prenomChef': _prenomChef.text.trim(),
          'nomChef': _nomChef.text.trim(),
        });
        widget.onCreer?.call(Departement.fromJson(resp['departement']));
      }
      setState(() {
        _loading = false;
        _done = true;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _done
          ? _SuccessView(
        titre: widget.dept != null ? 'Mis à jour !' : 'Créé !',
        message: 'Le département a été enregistré avec succès.',
        color: AppColors.blue,
        onClose: () => Navigator.pop(context),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(widget.dept != null ? 'Modifier' : 'Nouveau Département',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            _buildField(Icons.edit, "Nom", _nom),
            const SizedBox(height: 16),
            _buildField(Icons.description, "Description", _description, maxLines: 2),
            if (widget.dept == null) ...[
              const Divider(height: 40),
              const Text("Chef de Département", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildField(Icons.person, "Prénom", _prenomChef),
              const SizedBox(height: 16),
              _buildField(Icons.badge, "Nom", _nomChef),
              const SizedBox(height: 16),
              _buildField(Icons.email, "Email", _emailChef),
            ],
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: AppColors.red))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Valider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(IconData icon, String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String titre, message;
  final Color color;
  final VoidCallback onClose;
  const _SuccessView({required this.titre, required this.message, required this.color, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: color, size: 50),
        ),
        const SizedBox(height: 24),
        Text(titre, style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted, fontSize: 14)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
                backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text("Terminer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.red),
          const SizedBox(height: 16),
          const Text("Erreur de chargement", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: onRetry, child: const Text("Réessayer"))
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAction;
  const _EmptyState({required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 80, color: context.borderColor),
          const SizedBox(height: 16),
          Text("Aucun département", style: TextStyle(color: context.textMuted, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onAction, child: const Text("Créer le premier")),
        ],
      ),
    );
  }
}