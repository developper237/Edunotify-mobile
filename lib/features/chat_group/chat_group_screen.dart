import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? codeInvitation;
  final int nbMembres;
  final int nonLus;
  final String? dernierMessage;
  final DateTime? dernierMessageLe;

  const GroupeChat({
    required this.id,
    required this.nom,
    this.codeInvitation,
    this.nbMembres = 0,
    this.nonLus = 0,
    this.dernierMessage,
    this.dernierMessageLe,
  });

  factory GroupeChat.fromJson(Map<String, dynamic> j) => GroupeChat(
        id: j['id'] ?? '',
        nom: j['nom'] ?? '',
        codeInvitation: j['codeInvitation'] as String?,
        nbMembres:
            (j['_count']?['membres'] as int?) ?? (j['nbMembres'] as int?) ?? 0,
        nonLus: (j['nonLus'] as int?) ?? 0,
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
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      estMien: j['userId'] == currentUserId,
    );
  }

  String get initialise =>
      '${(userPrenom ?? '')[0]}${(userNom ?? '')[0]}'.toUpperCase();
  String get displayNom => '${userPrenom ?? ''} ${userNom ?? ''}'.trim();
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN LISTE DES GROUPES
// ══════════════════════════════════════════════════════════════════

class ChatGroupScreen extends ConsumerStatefulWidget {
  // quand true : pas de Scaffold/AppBar propre (utilisé dans un TabBarView)
  final bool embarque;
  // En mode desktop (deux panneaux), on remonte la sélection au hub
  final void Function(GroupeChat groupe)? onOuvrirGroupe;
  // Signal de rafraîchissement externe (pour rafraîchir les badges)
  final ValueListenable<int>? refreshSignal;
  const ChatGroupScreen({
    super.key,
    this.embarque = false,
    this.onOuvrirGroupe,
    this.refreshSignal,
  });

  @override
  ConsumerState<ChatGroupScreen> createState() => _ChatGroupScreenState();
}

class _ChatGroupScreenState extends ConsumerState<ChatGroupScreen> {
  List<GroupeChat> _groupes = [];
  bool _isLoading = true;
  VoidCallback? _onRefreshSignal;

  @override
  void initState() {
    super.initState();
    _chargerGroupes();
    final signal = widget.refreshSignal;
    if (signal != null) {
      _onRefreshSignal = () => _chargerGroupes(silent: true);
      signal.addListener(_onRefreshSignal!);
    }
  }

  @override
  void dispose() {
    final signal = widget.refreshSignal;
    if (signal != null && _onRefreshSignal != null) {
      signal.removeListener(_onRefreshSignal!);
    }
    super.dispose();
  }

  Future<void> _chargerGroupes({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (!silent) setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.getChat(
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
      if (!silent) setState(() => _isLoading = false);
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
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
      final resp = await ApiClient.postChat(
        '/chat/groups',
        data: {'nom': confirmed},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      _chargerGroupes();
      // Afficher le code d'invitation après création
      final code = resp['codeInvitation'] as String?;
      if (code != null && mounted) {
        _afficherCodeInvitation(code, confirmed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // Affiche le code d'invitation avec bouton copier
  Future<void> _afficherCodeInvitation(String code, String nom) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Groupe créé ! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Partagez ce code d\'invitation avec les membres de « $nom » :',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié !')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, color: AppColors.cyan),
                    tooltip: 'Copier',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Les membres rejoignent en tapant sur l\'icône ➕ puis « Rejoindre avec un code »',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Rejoindre un groupe avec un code d'invitation
  Future<void> _rejoindreParCode() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoindre avec un code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Ex: SC-ABC123',
            prefixIcon: Icon(Icons.key_rounded),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, codeController.text.trim()),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.postChat(
        '/chat/groups/join',
        data: {'codeInvitation': code},
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez rejoint le groupe !')),
      );
      _chargerGroupes();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }  @override
  Widget build(BuildContext context) {
    final body = _isLoading
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
                      style:
                          TextStyle(color: context.textMuted, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Créez un groupe ou attendez une invitation',
                      style:
                          TextStyle(color: context.textMuted, fontSize: 12),
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
                        backgroundColor:
                            AppColors.cyan.withValues(alpha: 0.15),
                        child: Text(
                          g.nom
                              .substring(0, g.nom.length.clamp(0, 2))
                              .toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(g.nom,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: g.nonLus > 0
                                  ? context.textPrimary
                                  : null)),
                      subtitle: Text(
                        g.dernierMessage ?? '${g.nbMembres} membre(s)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                g.nonLus > 0 ? context.textPrimary : context.textMuted,
                            fontWeight: g.nonLus > 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (g.dernierMessageLe != null)
                            Text(
                              DateFormat('HH:mm').format(g.dernierMessageLe!),
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 11),
                            ),
                          if (g.nonLus > 0) ...[const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${g.nonLus}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        final cb = widget.onOuvrirGroupe;
                        if (cb != null) {
                          cb(g);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                  groupeId: g.id, nom: g.nom),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );

    final actions = [
      IconButton(
        onPressed: _rejoindreParCode,
        icon: const Icon(Icons.key_rounded),
        tooltip: 'Rejoindre avec un code',
      ),
      IconButton(
        onPressed: _creerGroupe,
        icon: const Icon(Icons.add_circle_outline_rounded),
        tooltip: 'Créer un groupe',
      ),
    ];

    if (widget.embarque) {
      // Mode intégré (dans l'onglet Groupes du hub Messages) :
      // pas de Scaffold propre, actions en tête de liste
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: actions,
      ),
      body: body,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ÉCRAN DE CONVERSATION
// ══════════════════════════════════════════════════════════════════

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String groupeId;
  final String nom;
  // quand true : pas de Scaffold/AppBar propre (panneau droit desktop)
  final bool embarque;
  const ChatRoomScreen({
    super.key,
    required this.groupeId,
    required this.nom,
    this.embarque = false,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => ChatRoomScreenState();
}

class ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
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
      await ApiClient.postChat(
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

    final corps = Column(
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
                Text(widget.nom,
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.nom, style: const TextStyle(fontSize: 16)),
      ),
      body: corps,
    );
  }
}
