import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';

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
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
          ? const Center(child: Text("Aucun utilisateur trouvé"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        itemBuilder: (ctx, i) {
          final u = _filteredUsers[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.cyan.withOpacity(0.1),
                child: Text(u['nom']?[0] ?? '?', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
              ),
              title: Text("${u['prenom']} ${u['nom']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${u['role']} • ${u['matricule'] ?? 'Pas de matricule'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () => _editUser(u),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
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