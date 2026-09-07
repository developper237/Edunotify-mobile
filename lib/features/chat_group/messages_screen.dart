import '../../core/locale.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'chat_group_screen.dart';

// ══════════════════════════════════════════════════════════════════
// PROVIDER BADGE MESSAGES NON LUS
// ══════════════════════════════════════════════════════════════════

final chatNonLusProvider =
    StateNotifierProvider<ChatNonLusNotifier, int>((_) => ChatNonLusNotifier());

class ChatNonLusNotifier extends StateNotifier<int> {
  ChatNonLusNotifier() : super(0);

  Future<void> charger(String userId, String role, String? etablissementId) async {
    try {
      state = await ApiClient.getChatNonLus(
          userId: userId, role: role, etablissementId: etablissementId);
    } catch (_) {}
  }

  void reset() => state = 0;
}

// ══════════════════════════════════════════════════════════════════
// MODÈLES CHAT PRIVÉ
// ══════════════════════════════════════════════════════════════════

class ConversationPrivee {
  final String id;
  final String autreId;
  final String autreNom;
  final String autrePrenom;
  final String? autrePhotoUrl;
  final String? dernierMessage;
  final DateTime? dernierMessageLe;
  final bool dernierMessageDeMoi;
  final int nonLus;

  const ConversationPrivee({
    required this.id,
    required this.autreId,
    required this.autreNom,
    required this.autrePrenom,
    this.autrePhotoUrl,
    this.dernierMessage,
    this.dernierMessageLe,
    this.dernierMessageDeMoi = false,
    this.nonLus = 0,
  });

  factory ConversationPrivee.fromJson(Map<String, dynamic> j) =>
      ConversationPrivee(
        id: j['id'] ?? '',
        autreId: j['autreId'] ?? '',
        autreNom: j['autreNom'] ?? '',
        autrePrenom: j['autrePrenom'] ?? '',
        autrePhotoUrl: j['autrePhotoUrl'] as String?,
        dernierMessage: j['dernierMessage'] as String?,
        dernierMessageLe: j['dernierMessageLe'] != null
            ? DateTime.tryParse(j['dernierMessageLe'])
            : null,
        dernierMessageDeMoi: j['dernierMessageDeMoi'] == true,
        nonLus: (j['nonLus'] as int?) ?? 0,
      );

  String get displayNom => '${autrePrenom} ${autreNom}'.trim();
  String get initiales => autrePrenom.isNotEmpty && autreNom.isNotEmpty
      ? '${autrePrenom[0]}${autreNom[0]}'.toUpperCase()
      : (autrePrenom.isNotEmpty ? autrePrenom[0].toUpperCase() : '?');
}

class UtilisateurEtab {
  final String id;
  final String nom;
  final String prenom;
  final String role;
  final String? photoUrl;

  const UtilisateurEtab({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.role,
    this.photoUrl,
  });

  factory UtilisateurEtab.fromJson(Map<String, dynamic> j) => UtilisateurEtab(
        id: j['id'] ?? '',
        nom: j['nom'] ?? '',
        prenom: j['prenom'] ?? '',
        role: j['role'] ?? '',
        photoUrl: j['photoUrl'] as String?,
      );

  String get displayNom => '${prenom} ${nom}'.trim();
  String get initiales => prenom.isNotEmpty && nom.isNotEmpty
      ? '${prenom[0]}${nom[0]}'.toUpperCase()
      : (prenom.isNotEmpty ? prenom[0].toUpperCase() : '?');
}

class MessagePrive {
  final String id;
  final String texte;
  final String userId;
  final String? userNom;
  final String? userPrenom;
  final PieceJointe? pieceJointe;
  final DateTime createdAt;
  final bool estMien;
  final bool lu;
  // Statut local (hors-ligne) — utilisé uniquement pour nos propres messages
  final MessageStatut statut;

  const MessagePrive({
    required this.id,
    required this.texte,
    required this.userId,
    this.userNom,
    this.userPrenom,
    this.pieceJointe,
    required this.createdAt,
    this.estMien = false,
    this.lu = false,
    this.statut = MessageStatut.envoye,
  });

  factory MessagePrive.fromJson(Map<String, dynamic> j, String currentUserId) {
    final user = j['user'] as Map<String, dynamic>?;
    final pj = j['pieceJointe'];
    return MessagePrive(
      id: j['id'] ?? '',
      texte: j['texte'] ?? '',
      userId: j['userId'] ?? '',
      userNom: user?['nom'],
      userPrenom: user?['prenom'],
      pieceJointe: pj is Map<String, dynamic>
          ? PieceJointe.fromJson(pj)
          : null,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      estMien: j['userId'] == currentUserId,
      lu: j['lu'] == true,
    );
  }

  MessagePrive copyWith({
    MessageStatut? statut,
    bool? lu,
  }) =>
      MessagePrive(
        id: id,
        texte: texte,
        userId: userId,
        userNom: userNom,
        userPrenom: userPrenom,
        pieceJointe: pieceJointe,
        createdAt: createdAt,
        estMien: estMien,
        lu: lu ?? this.lu,
        statut: statut ?? this.statut,
      );

  String get displayNom => '${userPrenom ?? ''} ${userNom ?? ''}'.trim();
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN MESSAGES (HUB : conversations privées + groupes)
// ══════════════════════════════════════════════════════════════════

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  List<ConversationPrivee> _conversations = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  late TabController _tabController;

  // ── Mode desktop (deux panneaux) : conversation sélectionnée ──
  ConversationPrivee? _selPrivee;
  GroupeChat? _selGroupe;
  final ValueNotifier<int> _groupRefreshTick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _charger();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _charger(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _groupRefreshTick.dispose();
    super.dispose();
  }

  Future<void> _charger({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.getChat(
        '/chat/privates',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      final conversations = (resp['conversations'] as List? ?? [])
          .map((e) => ConversationPrivee.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        // Rafraîchir aussi les badges des groupes
        _groupRefreshTick.value++;
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _nouvelleConversation() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Charger les utilisateurs de l'établissement
    List<UtilisateurEtab> utilisateurs = [];
    try {
      final resp = await ApiClient.getChat(
        '/chat/utilisateurs',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      utilisateurs = (resp['utilisateurs'] as List? ?? [])
          .map((e) => UtilisateurEtab.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    if (!mounted) return;

    final selected = await showModalBottomSheet<UtilisateurEtab>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RechercheUtilisateursSheet(
        utilisateurs: utilisateurs,
        dejaEnConversation: _conversations.map((c) => c.autreId).toSet(),
      ),
    );

    if (selected == null || !mounted) return;

    try {
      final resp = await ApiClient.postChat(
        '/chat/privates',
        data: {'autreId': selected.id},
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      final convId = (resp['conversation'] as Map<String, dynamic>?)?['id'] ??
          resp['conversation']?['id'] ??
          (resp['id'] as String?);
      if (convId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de démarrer la conversation')),
          );
        }
        return;
      }
      await _charger(silent: true);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PrivateChatScreen(
            conversationId: convId,
            titre: selected.displayNom,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _ouvrirConversation(ConversationPrivee c) async {
    final user = ref.read(currentUserProvider);
    if (!mounted || user == null) return;

    // Mode desktop : on affiche la conversation dans le panneau droit
    if (MediaQuery.of(context).size.width >= 760) {
      setState(() {
        _selPrivee = c;
        _selGroupe = null;
      });
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PrivateChatScreen(
          conversationId: c.id,
          titre: c.displayNom,
        ),
      ),
    );
    // Rafraîchir la liste + le badge après retour
    await _charger(silent: true);
    if (mounted && user.id.isNotEmpty) {
      ref.read(chatNonLusProvider.notifier).charger(
          user.id, user.role, user.etablissementId);
    }
  }

  void _ouvrirGroupeDesktop(GroupeChat g) {
    if (!mounted) return;
    setState(() {
      _selGroupe = g;
      _selPrivee = null;
    });
  }

  Future<void> _supprimerConversation(ConversationPrivee c) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: Text(
            'Voulez-vous supprimer la conversation avec ${c.displayNom} ? Les messages seront perdus pour vous et pour l\'autre personne.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.deleteChat(
        '/chat/privates/${c.id}',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      if (mounted && _selPrivee?.id == c.id) {
        setState(() => _selPrivee = null);
      }
      await _charger(silent: true);
      ref.read(chatNonLusProvider.notifier)
          .charger(user.id, user.role, user.etablissementId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // Liste des conversations privées (utilisée dans le panneau gauche)
  Widget _listePrivees() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined,
                        size: 56, color: context.textMuted),
                    const SizedBox(height: 12),
                    Text('Aucune conversation',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Touchez + pour discuter avec quelqu\'un',
                      style:
                          TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _charger(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: context.borderColor),
                  itemBuilder: (ctx, i) {
                    final c = _conversations[i];
                    final selected = _selPrivee?.id == c.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: AppColors.cyan.withValues(alpha: 0.08),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.cyan.withValues(alpha: 0.15),
                        backgroundImage:
                            c.autrePhotoUrl != null &&
                                    c.autrePhotoUrl!.isNotEmpty
                                ? NetworkImage(c.autrePhotoUrl!)
                                : null,
                        child: c.autrePhotoUrl == null ||
                                c.autrePhotoUrl!.isEmpty
                            ? Text(c.initiales,
                                style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontWeight: FontWeight.w700))
                            : null,
                      ),
                      title: Text(c.displayNom,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        c.dernierMessage == null
                            ? 'Dites bonjour !'
                            : '${c.dernierMessageDeMoi ? 'Vous : ' : ''}${c.dernierMessage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.nonLus > 0
                                ? context.textPrimary
                                : context.textMuted,
                            fontWeight: c.nonLus > 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.dernierMessageLe != null)
                            Text(
                              DateFormat('HH:mm').format(c.dernierMessageLe!),
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 11),
                            ),
                          if (c.nonLus > 0) ...[const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${c.nonLus}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _ouvrirConversation(c),
                      onLongPress: () => _supprimerConversation(c),
                    );
                  },
                ),
              );
  }

  // Panneau droit (desktop) : conversation ouverte ou placeholder
  Widget _panneauDroit() {
    if (_selPrivee != null) {
      // key : force la recréation immédiate de l'état quand on change de
      // conversation (sinon Flutter réutilise l'état de l'ancienne)
      return _PrivateChatScreen(
        key: ValueKey('prive-${_selPrivee!.id}'),
        conversationId: _selPrivee!.id,
        titre: _selPrivee!.displayNom,
        embarque: true,
      );
    }
    if (_selGroupe != null) {
      return ChatRoomScreen(
        key: ValueKey('groupe-${_selGroupe!.id}'),
        groupeId: _selGroupe!.id,
        nom: _selGroupe!.nom,
        photoUrl: _selGroupe!.photoUrl,
        creeParId: _selGroupe!.creeParId,
        embarque: true,
        onGroupChanged: () {
          // Rafraîchit la liste des groupes après une modif (photo/suppression)
          _groupRefreshTick.value++;
          if (_selGroupe != null && mounted) {
            setState(() => _selGroupe = null);
          }
        },
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined,
              size: 64, color: context.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Sélectionnez une conversation',
              style: TextStyle(
                  color: context.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Choisissez une discussion dans la liste',
              style:
                  TextStyle(color: context.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final onglets = TabBar(
      controller: _tabController,
      indicatorColor: AppColors.cyan,
      indicatorWeight: 3,
      labelColor: AppColors.cyan,
      unselectedLabelColor: context.textMuted,
      labelStyle:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [
        Tab(text: 'Privés'),
        Tab(text: 'Groupes'),
      ],
    );

    final panneauGauche = Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.borderColor)),
          ),
          child: onglets,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Conversations privées ──
              _listePrivees(),
              // ── Groupes (seulement ceux rejoints) ──
              ChatGroupScreen(
                embarque: true,
                refreshSignal: _groupRefreshTick,
                onOuvrirGroupe: isWide ? _ouvrirGroupeDesktop : null,
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: _nouvelleConversation,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Nouvelle conversation',
          ),
        ],
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: _nouvelleConversation,
              mini: true,
              backgroundColor: AppColors.cyan,
              tooltip: 'Nouvelle conversation',
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
      body: isWide
          ? Row(
              children: [
                // ── Liste des conversations (gauche) ──
                SizedBox(width: 360, child: panneauGauche),
                VerticalDivider(width: 1, color: context.borderColor),
                // ── Conversation ouverte (droite) ──
                Expanded(child: _panneauDroit()),
              ],
            )
          : panneauGauche,
    );
  }
}

// Statut d'un message privé envoyé (type WhatsApp)
class _StatutMessagePrive extends StatelessWidget {
  final MessageStatut statut;
  final bool lu;

  const _StatutMessagePrive({required this.statut, required this.lu});

  @override
  Widget build(BuildContext context) {
    if (statut == MessageStatut.enAttente) {
      return const Icon(Icons.schedule_rounded,
          size: 12, color: Colors.white70);
    }
    if (lu) {
      return const Icon(Icons.done_all_rounded,
          size: 13, color: Color(0xFF8AB4F8));
    }
    return const Icon(Icons.done_rounded, size: 13, color: Colors.white70);
  }
}

// ══════════════════════════════════════════════════════════════════
// RECHERCHE D'UTILISATEURS (bottom sheet)
// ══════════════════════════════════════════════════════════════════

class _RechercheUtilisateursSheet extends StatefulWidget {
  final List<UtilisateurEtab> utilisateurs;
  final Set<String> dejaEnConversation;

  const _RechercheUtilisateursSheet({
    required this.utilisateurs,
    required this.dejaEnConversation,
  });

  @override
  State<_RechercheUtilisateursSheet> createState() =>
      _RechercheUtilisateursSheetState();
}

class _RechercheUtilisateursSheetState
    extends State<_RechercheUtilisateursSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.utilisateurs.where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return u.displayNom.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher un étudiant, professeur...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: context.bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final u = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
                      backgroundImage: u.photoUrl != null && u.photoUrl!.isNotEmpty
                          ? NetworkImage(u.photoUrl!)
                          : null,
                      child: u.photoUrl == null || u.photoUrl!.isEmpty
                          ? Text(u.initiales,
                              style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                    title: Text(u.displayNom,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(u.role,
                        style: TextStyle(
                            color: context.textMuted, fontSize: 11)),
                    trailing: widget.dejaEnConversation.contains(u.id)
                        ? Icon(Icons.check_circle_rounded,
                            color: Colors.green.shade400, size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SALLE DE CHAT PRIVÉ
// ══════════════════════════════════════════════════════════════════

class _PrivateChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String titre;
  // quand true : pas de Scaffold/AppBar propre (panneau droit desktop)
  final bool embarque;

  const _PrivateChatScreen({
    super.key,
    required this.conversationId,
    required this.titre,
    this.embarque = false,
  });

  @override
  ConsumerState<_PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends ConsumerState<_PrivateChatScreen> {
  Strings get s => ref.watch(stringsProvider);
  final _msgController = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessagePrive> _messages = [];
  List<MessagePrive> _pending = []; // messages hors-ligne (en attente)
  DateTime? _dernierMsgLe; // curseur incrémental (dernier message serveur chargé)
  bool _isLoading = true;
  Timer? _pollTimer;

  String get _cleFileAttente => 'chat_pending_prive_${widget.conversationId}';

  @override
  void initState() {
    super.initState();
    _chargerMessages();
    _chargerFileAttente();
    // Polling toutes les 5 secondes : messages + renvoi des messages en attente
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _chargerMessages(silent: true);
      _flusherFileAttente();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── File d'attente hors-ligne (persistée en local) ────────────
  Future<void> _chargerFileAttente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cleFileAttente);
      if (raw == null || !mounted) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final user = ref.read(currentUserProvider);
      setState(() {
        _pending = list.map((m) => MessagePrive(
              id: m['id'] ?? '',
              texte: m['texte'] ?? '',
              userId: user?.id ?? '',
              userNom: user?.nom,
              userPrenom: user?.prenom,
              pieceJointe: m['pieceJointe'] != null
                  ? PieceJointe.fromJson(m['pieceJointe'])
                  : null,
              createdAt: DateTime.tryParse(m['createdAt'] ?? '') ??
                  DateTime.now(),
              estMien: true,
              statut: MessageStatut.enAttente,
            )).toList();
      });
    } catch (_) {}
  }

  Future<void> _sauverFileAttente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cleFileAttente,
          jsonEncode(_pending
              .map((m) => {
                    'id': m.id,
                    'texte': m.texte,
                    'pieceJointe': m.pieceJointe?.toJson(),
                    'createdAt': m.createdAt.toIso8601String(),
                  })
              .toList()));
    } catch (_) {}
  }

  // Renvoie les messages en attente ; retire ceux qui partent enfin
  Future<void> _flusherFileAttente() async {
    if (_pending.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final restant = <MessagePrive>[];
    for (final m in _pending) {
      try {
        await ApiClient.postChat(
          '/chat/privates/${widget.conversationId}/messages',
          data: {'texte': m.texte, 'pieceJointe': m.pieceJointe?.toJson()},
          userId: user.id,
          role: user.role,
          etablissementId: user.etablissementId,
        );
      } catch (_) {
        restant.add(m); // toujours hors-ligne, on réessaiera
      }
    }
    if (restant.length != _pending.length || restant.isEmpty) {
      if (mounted) setState(() => _pending = restant);
      _sauverFileAttente();
      _chargerMessages(silent: true);
    }
  }

  Future<void> _chargerMessages({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{};
      // Récupération incrémentale : on ne recharge que les messages plus
      // récents que le dernier déjà chargé (allége le polling toutes les 5 s).
      if (_dernierMsgLe != null) {
        params['apres'] = _dernierMsgLe!.toIso8601String();
      }
      final resp = await ApiClient.getChat(
        '/chat/privates/${widget.conversationId}/messages',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
        params: params,
      );
      final nouveaux = (resp['messages'] as List? ?? [])
          .map((e) => MessagePrive.fromJson(e as Map<String, dynamic>, user.id))
          .toList();
      if (!mounted) return;
      setState(() {
        if (params['apres'] != null) {
          // Mode incrémental : fusionner sans créer de doublon (par id)
          if (nouveaux.isNotEmpty) {
            final ids = _messages.map((m) => m.id).toSet();
            _messages = [
              ..._messages,
              ...nouveaux.where((m) => !ids.contains(m.id)),
            ];
          }
        } else {
          // Chargement initial : messages en attente puis historique serveur
          _messages = [...nouveaux, ..._pending];
        }
        _isLoading = false;
      });
      // Le curseur ne suit que les messages réellement persistés (pas les
      // messages en attente aux ids locaux).
      if (nouveaux.isNotEmpty) {
        _dernierMsgLe = nouveaux.last.createdAt;
      } else if (params['apres'] == null && _messages.isNotEmpty) {
        _dernierMsgLe = _messages.last.createdAt;
      }
      if (_scrollCtrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  // Ajoute le message localement (même sans connexion) puis tente l'envoi
  Future<void> _envoyer() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final user = ref.read(currentUserProvider);
    final localMsg = MessagePrive(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      texte: text,
      userId: user?.id ?? '',
      userNom: user?.nom,
      userPrenom: user?.prenom,
      createdAt: DateTime.now(),
      estMien: true,
      statut: MessageStatut.enAttente,
    );

    // Le message apparaît immédiatement dans le chat (type WhatsApp)
    setState(() {
      _pending.add(localMsg);
      _messages = [..._messages, localMsg];
    });
    _sauverFileAttente();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });

    await _flusherFileAttente();
  }

  Future<void> _envoyerPieceJointe() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'zip',
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'txt'
      ],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le fichier dépasse 20 Mo')),
        );
      }
      return;
    }
    if (file.path == null) return;

    try {
      final user = ref.read(currentUserProvider);
      final fileBytes = await File(file.path!).readAsBytes();
      final resp = await ApiClient.uploadChatFichier(
        '/chat/privates/${widget.conversationId}/pieces-jointes',
        fileBytes: fileBytes,
        filename: file.name,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      // Ajout local immédiat puis envoi (file d'attente hors-ligne)
      final pj = PieceJointe.fromJson(resp);
      final localMsg = MessagePrive(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        texte: '',
        userId: user?.id ?? '',
        userNom: user?.nom,
        userPrenom: user?.prenom,
        pieceJointe: pj,
        createdAt: DateTime.now(),
        estMien: true,
        statut: MessageStatut.enAttente,
      );
      setState(() {
        _pending.add(localMsg);
        _messages = [..._messages, localMsg];
      });
      _sauverFileAttente();
      await _flusherFileAttente();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e')),
        );
      }
    }
  }

  Future<void> _envoyerAudio(List<int> bytes, String nom, String mime) async {
    try {
      final user = ref.read(currentUserProvider);
      final resp = await ApiClient.uploadChatFichier(
        '/chat/privates/${widget.conversationId}/pieces-jointes',
        fileBytes: bytes,
        filename: nom,
        mimeType: mime,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      final pj = PieceJointe.fromJson(resp);
      final localMsg = MessagePrive(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        texte: '',
        userId: user?.id ?? '',
        userNom: user?.nom,
        userPrenom: user?.prenom,
        pieceJointe: pj,
        createdAt: DateTime.now(),
        estMien: true,
        statut: MessageStatut.enAttente,
      );
      setState(() {
        _pending.add(localMsg);
        _messages = [..._messages, localMsg];
      });
      _sauverFileAttente();
      await _flusherFileAttente();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi vocal : $e')),
        );
      }
    }
  }

  Future<void> _supprimerMessage(MessagePrive msg) async {
    if (!msg.estMien) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Voulez-vous supprimer ce message ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.deleteChat(
        '/chat/privates/${widget.conversationId}/messages/${msg.id}',
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final corps = Column(
      children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun message. Dites bonjour !',
                          style: TextStyle(color: context.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg.estMien;
                          return GestureDetector(
                            onLongPress: msg.estMien
                                ? () => _supprimerMessage(msg)
                                : null,
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.cyan
                                      : isDark
                                          ? AppColors.darkCard
                                          : AppColors.lightCard,
                                  borderRadius:
                                      BorderRadius.circular(16).copyWith(
                                    bottomRight: isMe
                                        ? const Radius.circular(4)
                                        : null,
                                    bottomLeft: !isMe
                                        ? const Radius.circular(4)
                                        : null,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msg.pieceJointe != null) ...[
                                      FichierJoint(
                                          pj: msg.pieceJointe!, dark: isMe),
                                      const SizedBox(height: 6),
                                    ],
                                    if (msg.texte.isNotEmpty)
                                      Text(
                                        msg.texte,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : context.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(msg.createdAt),
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white70
                                                : context.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isMe) ...[const SizedBox(width: 4),
                                          _StatutMessagePrive(
                                            statut: msg.statut,
                                            lu: msg.lu,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Champ de saisie
          Container(
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _envoyerPieceJointe,
                  icon: const Icon(Icons.attach_file_rounded),
                  color: context.textMuted,
                  tooltip: 'Pièce jointe',
                ),
                EnregistreurAudio(
                    onEnvoye: _envoyerAudio, couleur: AppColors.cyan),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Votre message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _envoyer(),
                  ),
                ),
                IconButton(
                  onPressed: _envoyer,
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.cyan,
                ),
              ],
            ),
          ),
        ],
    );

    if (widget.embarque) {
      // Mode panneau droit (desktop) : en-tête compact + conversation
      return Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                Text(widget.titre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          Expanded(child: corps),
        ],
      );
    }

    return Scaffold(
      // IMPORTANT : le Scaffold redimensionne déjà le body quand le clavier
      // s'ouvre (resizeToAvoidBottomInset). On ne doit PAS ajouter
      // viewInsets.bottom en padding, sinon la zone de saisie est poussée
      // deux fois et un grand vide apparaît entre elle et le clavier.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.titre, style: const TextStyle(fontSize: 16)),
      ),
      body: corps,
    );
  }
}
