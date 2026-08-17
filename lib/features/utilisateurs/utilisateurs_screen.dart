import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/ui_kit.dart';

class UtilisateursScreen extends ConsumerStatefulWidget {
  const UtilisateursScreen({super.key});

  @override
  ConsumerState<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends ConsumerState<UtilisateursScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  Future<void> _loadUsers() async {
    try {
      // Note : Le backend gère déjà le filtrage par etablissement via le token
      final resp = await ApiClient.get('/auth/utilisateurs');
      setState(() {
        _users = resp['data'] ?? [];
        _filteredUsers = _users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filterUsers() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((u) {
        final nom = (u['nom'] ?? '').toString().toLowerCase();
        final prenom = (u['prenom'] ?? '').toString().toLowerCase();
        final matricule = (u['matricule'] ?? '').toString().toLowerCase();
        return nom.contains(query) || prenom.contains(query) || matricule.contains(query);
      }).toList();
    });
  }

  // --- ACTIONS ---

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer l'utilisateur ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient.delete('/auth/utilisateurs/$id');
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la suppression")));
      }
    }
  }

  Future<void> _editUser(dynamic u) async {
    final nomCtrl = TextEditingController(text: u['nom']);
    final prenomCtrl = TextEditingController(text: u['prenom']);
    final matriculeCtrl = TextEditingController(text: u['matricule'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier l'utilisateur"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: "Nom")),
              const SizedBox(height: 12),
              TextField(controller: prenomCtrl, decoration: const InputDecoration(labelText: "Prénom")),
              const SizedBox(height: 12),
              TextField(controller: matriculeCtrl, decoration: const InputDecoration(labelText: "Matricule / Identifiant")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiClient.patch('/auth/utilisateurs/${u['id']}', data: {
                  'nom': nomCtrl.text.trim(),
                  'prenom': prenomCtrl.text.trim(),
                  'matricule': matriculeCtrl.text.trim(),
                });
                Navigator.pop(ctx);
                _loadUsers();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur mis à jour")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la modification")));
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Utilisateurs"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Rechercher un nom ou matricule...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const ListSkeleton()
          : _filteredUsers.isEmpty
          ? const EmptyStateView(
              icon: Icons.people_outline,
              title: "Aucun utilisateur trouvé",
              message: "Modifiez votre recherche ou ajoutez de nouveaux utilisateurs.",
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        itemBuilder: (ctx, i) {
          final u = _filteredUsers[i];
          final role = (u['role'] ?? 'etudiant').toString();
          final roleColor = AppColors.forRole(role);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: roleColor.withValues(alpha: 0.12),
                child: Text(
                  '${u['prenom']?[0] ?? u['nom']?[0] ?? '?'}'
                      .toUpperCase(),
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                "${u['prenom']} ${u['nom']}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    TagBadge(label: role, color: roleColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        u['matricule'] ?? 'Pas de matricule',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.blue),
                    onPressed: () => _editUser(u),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.red),
                    onPressed: () => _deleteUser(u['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}