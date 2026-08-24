import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  final DateTime createdAt;
  final bool estMien;

  const MessagePrive({
    required this.id,
    required this.texte,
    required this.userId,
    this.userNom,
    this.userPrenom,
    required this.createdAt,
    this.estMien = false,
  });

  factory MessagePrive.fromJson(Map<String, dynamic> j, String currentUserId) {
    final user = j['user'] as Map<String, dynamic>?;
    return MessagePrive(
      id: j['id'] ?? '',
      texte: j['texte'] ?? '',
      userId: j['userId'] ?? '',
      userNom: user?['nom'],
      userPrenom: user?['prenom'],
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      estMien: j['userId'] == currentUserId,
    );
  }

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

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  List<ConversationPrivee> _conversations = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _charger();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _charger(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          actions: [
            IconButton(
              onPressed: _nouvelleConversation,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Nouvelle conversation',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Privés'),
              Tab(text: 'Groupes'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _nouvelleConversation,
          mini: true,
          backgroundColor: AppColors.cyan,
          child: const Icon(Icons.add_rounded, color: Colors.white),
          tooltip: 'Nouvelle conversation',
        ),
        body: TabBarView(
          children: [
            // ── Conversations privées ──
            _isLoading
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
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 12),
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
                            return ListTile(
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
                                      DateFormat('HH:mm')
                                          .format(c.dernierMessageLe!),
                                      style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 11),
                                    ),
                                  if (c.nonLus > 0) ...[
                                    const SizedBox(width: 8),
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
                            );
                          },
                        ),
                      ),
            // ── Groupes (seulement ceux rejoints) ──
            const ChatGroupScreen(embarque: true),
          ],
        ),
      ),
    );
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

  const _PrivateChatScreen({
    required this.conversationId,
    required this.titre,
  });

  @override
  ConsumerState<_PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends ConsumerState<_PrivateChatScreen> {
  final _msgController = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessagePrive> _messages = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chargerMessages();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _chargerMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerMessages({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.getChat(
        '/chat/privates/${widget.conversationId}/messages',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      final messages = (resp['messages'] as List? ?? [])
          .map((e) => MessagePrive.fromJson(e as Map<String, dynamic>, user.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      if (_scrollCtrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _envoyer() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final user = ref.read(currentUserProvider);
    try {
      await ApiClient.postChat(
        '/chat/privates/${widget.conversationId}/messages',
        data: {'texte': text},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      // IMPORTANT : le Scaffold redimensionne déjà le body quand le clavier
      // s'ouvre (resizeToAvoidBottomInset). On ne doit PAS ajouter
      // viewInsets.bottom en padding, sinon la zone de saisie est poussée
      // deux fois et un grand vide apparaît entre elle et le clavier.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.titre, style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
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
                          return Align(
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
                                  bottomRight:
                                      isMe ? const Radius.circular(4) : null,
                                  bottomLeft:
                                      !isMe ? const Radius.circular(4) : null,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  Text(
                                    DateFormat('HH:mm').format(msg.createdAt),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : context.textMuted,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ],
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
      ),
    );
  }
}
