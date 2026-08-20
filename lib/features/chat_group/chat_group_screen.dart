import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class GroupeChat {
  final String id;
  final String nom;
  final int nbMembres;
  final String? dernierMessage;
  final DateTime? dernierMessageLe;

  const GroupeChat({
    required this.id,
    required this.nom,
    this.nbMembres = 0,
    this.dernierMessage,
    this.dernierMessageLe,
  });

  factory GroupeChat.fromJson(Map<String, dynamic> j) => GroupeChat(
    id: j['id'] ?? '',
    nom: j['nom'] ?? '',
    nbMembres: (j['_count']?['membres'] as int?) ?? (j['nbMembres'] as int?) ?? 0,
    dernierMessage: j['dernierMessage'] as String?,
    dernierMessageLe: j['dernierMessageLe'] != null
        ? DateTime.tryParse(j['dernierMessageLe'])
        : null,
  );
}

class MessageChat {
  final String id;
  final String texte;
  final String userId;
  final String? userNom;
  final String? userPrenom;
  final DateTime createdAt;
  final bool estMien;

  const MessageChat({
    required this.id,
    required this.texte,
    required this.userId,
    this.userNom,
    this.userPrenom,
    required this.createdAt,
    this.estMien = false,
  });

  factory MessageChat.fromJson(Map<String, dynamic> j, String currentUserId) {
    final user = j['user'] as Map<String, dynamic>?;
    return MessageChat(
      id: j['id'] ?? '',
      texte: j['texte'] ?? '',
      userId: j['userId'] ?? '',
      userNom: user?['nom'],
      userPrenom: user?['prenom'],
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) ?? DateTime.now() : DateTime.now(),
      estMien: j['userId'] == currentUserId,
    );
  }

  String get initialise => '${(userPrenom ?? '')[0]}${(userNom ?? '')[0]}'.toUpperCase();
  String get displayNom => '${userPrenom ?? ''} ${userNom ?? ''}'.trim();
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN LISTE DES GROUPES
// ══════════════════════════════════════════════════════════════════

class ChatGroupScreen extends ConsumerStatefulWidget {
  const ChatGroupScreen({super.key});

  @override
  ConsumerState<ChatGroupScreen> createState() => _ChatGroupScreenState();
}

class _ChatGroupScreenState extends ConsumerState<ChatGroupScreen> {
  List<GroupeChat> _groupes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerGroupes();
  }

  Future<void> _chargerGroupes() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.getBilling(
        '/chat/groups',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );

      final groupes = (resp['groupes'] as List? ?? [])
          .map((e) => GroupeChat.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _groupes = groupes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _creerGroupe() async {
    final nomController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer un groupe'),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(hintText: 'Nom du groupe'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nomController.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed.isEmpty) return;

    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.post('/chat/groups',
        data: {'nom': confirmed},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerGroupes();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            onPressed: _creerGroupe,
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Créer un groupe',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56, color: context.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun groupe',
                        style: TextStyle(color: context.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Créez un groupe ou attendez une invitation',
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _chargerGroupes,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _groupes.length,
                    itemBuilder: (ctx, i) {
                      final g = _groupes[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
                          child: Text(
                            g.nom.substring(0, g.nom.length.clamp(0, 2)).toUpperCase(),
                            style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(g.nom, style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          g.dernierMessage ?? '${g.nbMembres} membre(s)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.textMuted, fontSize: 12),
                        ),
                        trailing: g.dernierMessageLe != null
                            ? Text(
                                DateFormat('HH:mm').format(g.dernierMessageLe!),
                                style: TextStyle(color: context.textMuted, fontSize: 11),
                              )
                            : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => _ChatRoomScreen(groupeId: g.id, nom: g.nom),
                        )),
                      );
                    },
                  ),
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN DE CONVERSATION
// ══════════════════════════════════════════════════════════════════

class _ChatRoomScreen extends ConsumerStatefulWidget {
  final String groupeId;
  final String nom;
  const _ChatRoomScreen({required this.groupeId, required this.nom});

  @override
  ConsumerState<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<_ChatRoomScreen> {
  final _msgController = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageChat> _messages = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _chargerMessages();
    // Polling toutes les 5 secondes
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _chargerMessages(silent: true));
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
      final resp = await ApiClient.getBilling(
        '/chat/groups/${widget.groupeId}/messages',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );

      final messages = (resp['messages'] as List? ?? [])
          .map((e) => MessageChat.fromJson(e as Map<String, dynamic>, user.id))
          .toList();

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Auto-scroll en bas
      if (_scrollCtrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _envoyer() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.post(
        '/chat/groups/${widget.groupeId}/messages',
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
    final userId = ref.read(currentUserProvider)?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.nom, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun message. Soyez le premier !',
                          style: TextStyle(color: context.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg.estMien;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.cyan
                                    : isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? const Radius.circular(4) : null,
                                  bottomLeft: !isMe ? const Radius.circular(4) : null,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    Text(
                                      msg.displayNom,
                                      style: TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    msg.texte,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : context.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('HH:mm').format(msg.createdAt),
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : context.textMuted,
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
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
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
                    decoration: InputDecoration(
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
