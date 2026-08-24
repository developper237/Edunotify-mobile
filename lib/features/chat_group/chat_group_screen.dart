import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class PieceJointe {
  final String nom;
  final String url;
  final int taille;
  final String type;

  const PieceJointe({
    required this.nom,
    required this.url,
    this.taille = 0,
    this.type = '',
  });

  factory PieceJointe.fromJson(Map<String, dynamic>? j) => PieceJointe(
        nom: j?['nom'] ?? 'Fichier',
        url: j?['url'] ?? '',
        taille: (j?['taille'] as int?) ?? 0,
        type: j?['type'] ?? '',
      );

  bool get estImage =>
      type.startsWith('image/') ||
      ['.jpg', '.jpeg', '.png', '.gif', '.webp']
          .any((e) => nom.toLowerCase().endsWith(e));

  String get tailleLisible {
    if (taille >= 1024 * 1024) return '${(taille / (1024 * 1024)).toStringAsFixed(1)} Mo';
    if (taille >= 1024) return '${(taille / 1024).toStringAsFixed(0)} Ko';
    return '$taille o';
  }

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'url': url,
        'taille': taille,
        'type': type,
      };
}

class GroupeChat {
  final String id;
  final String nom;
  final String? codeInvitation;
  final String? photoUrl;
  final String creeParId;
  final int nbMembres;
  final int nonLus;
  final String? dernierMessage;
  final DateTime? dernierMessageLe;

  const GroupeChat({
    required this.id,
    required this.nom,
    this.codeInvitation,
    this.photoUrl,
    this.creeParId = '',
    this.nbMembres = 0,
    this.nonLus = 0,
    this.dernierMessage,
    this.dernierMessageLe,
  });

  factory GroupeChat.fromJson(Map<String, dynamic> j) => GroupeChat(
        id: j['id'] ?? '',
        nom: j['nom'] ?? '',
        codeInvitation: j['codeInvitation'] as String?,
        photoUrl: j['photoUrl'] as String?,
        creeParId: j['creeParId'] ?? '',
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
  final PieceJointe? pieceJointe;
  final DateTime createdAt;
  final bool estMien;

  const MessageChat({
    required this.id,
    required this.texte,
    required this.userId,
    this.userNom,
    this.userPrenom,
    this.pieceJointe,
    required this.createdAt,
    this.estMien = false,
  });

  factory MessageChat.fromJson(Map<String, dynamic> j, String currentUserId) {
    final user = j['user'] as Map<String, dynamic>?;
    final pj = j['pieceJointe'];
    return MessageChat(
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
  }

  // Convertit une URL relative /uploads/... en URL complète
  static String _urlComplet(String url) {
    if (url.startsWith('http')) return url;
    return 'https://billing-service-efm6.onrender.com$url';
  }

  Future<void> _supprimerGroupe(GroupeChat g) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: Text(
            'Voulez-vous vraiment supprimer « ${g.nom} » ? Tous les messages seront perdus.'),
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
        '/chat/groups/${g.id}',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groupe supprimé')),
        );
      }
      await _chargerGroupes();
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
                    final userId = ref.read(currentUserProvider)?.id ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.cyan.withValues(alpha: 0.15),
                        backgroundImage: g.photoUrl != null &&
                                g.photoUrl!.isNotEmpty
                            ? NetworkImage(_urlComplet(g.photoUrl!))
                            : null,
                        child: g.photoUrl == null || g.photoUrl!.isEmpty
                            ? Text(
                                g.nom
                                    .substring(0, g.nom.length.clamp(0, 2))
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
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
                                  groupeId: g.id, nom: g.nom, photoUrl: g.photoUrl),
                            ),
                          );
                        }
                      },
                      onLongPress: g.creeParId == userId
                          ? () => _supprimerGroupe(g)
                          : null,
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
  final String? photoUrl;
  final String? creeParId;
  // quand true : pas de Scaffold/AppBar propre (panneau droit desktop)
  final bool embarque;
  // En mode desktop, on notifie le hub pour rafraîchir la liste
  final VoidCallback? onGroupChanged;
  const ChatRoomScreen({
    super.key,
    required this.groupeId,
    required this.nom,
    this.photoUrl,
    this.creeParId,
    this.embarque = false,
    this.onGroupChanged,
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
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.photoUrl;
    _chargerMessages();
    // Polling toutes les 5 secondes
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _chargerMessages(silent: true));
  }

  bool get _estCreateur {
    final userId = ref.read(currentUserProvider)?.id ?? '';
    return widget.creeParId != null &&
        widget.creeParId!.isNotEmpty &&
        widget.creeParId == userId;
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

  Future<void> _envoyerAvecPieceJointe(PieceJointe pj) async {
    try {
      final user = ref.read(currentUserProvider);
      await ApiClient.postChat(
        '/chat/groups/${widget.groupeId}/messages',
        data: {'texte': '', 'pieceJointe': pj.toJson()},
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
        '/chat/groups/${widget.groupeId}/pieces-jointes',
        fileBytes: fileBytes,
        filename: file.name,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      await _envoyerAvecPieceJointe(
          PieceJointe.fromJson(resp));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e')),
        );
      }
    }
  }

  Future<void> _changerPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo trop lourde (max 5 Mo)')),
        );
      }
      return;
    }
    try {
      final user = ref.read(currentUserProvider);
      final fileBytes = await File(file.path!).readAsBytes();
      final resp = await ApiClient.uploadChatPhoto(
        '/chat/groups/${widget.groupeId}/photo',
        fileBytes: fileBytes,
        filename: file.name,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      setState(() => _photoUrl = resp['photoUrl'] as String?);
      widget.onGroupChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo du groupe mise à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _supprimerMessage(MessageChat msg) async {
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
        '/chat/groups/${widget.groupeId}/messages/${msg.id}',
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

  Future<void> _supprimerGroupe() async {
    if (!_estCreateur) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: Text(
            'Voulez-vous vraiment supprimer « ${widget.nom} » ? Tous les messages seront perdus.'),
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
        '/chat/groups/${widget.groupeId}',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
      );
      widget.onGroupChanged?.call();
      if (mounted && !widget.embarque) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groupe supprimé')),
        );
      }
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
                                    Text(
                                      DateFormat('HH:mm')
                                          .format(msg.createdAt),
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

    final menu = PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'photo') _changerPhoto();
        if (v == 'supprimer') _supprimerGroupe();
      },
      itemBuilder: (ctx) => [
        if (_estCreateur) ...[
          const PopupMenuItem(
              value: 'photo',
              child: Row(children: [
                Icon(Icons.photo_camera_rounded, size: 18),
                SizedBox(width: 8),
                Text('Modifier la photo'),
              ])),
          const PopupMenuItem(
              value: 'supprimer',
              child: Row(children: [
                Icon(Icons.delete_rounded, size: 18, color: AppColors.red),
                SizedBox(width: 8),
                Text('Supprimer le groupe',
                    style: TextStyle(color: AppColors.red)),
              ])),
        ],
      ],
    );

    // En-tête : avatar du groupe + nom (+ menu pour le créateur)
    Widget enTete = Row(
      children: [
        GestureDetector(
          onTap: _estCreateur ? _changerPhoto : null,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
            backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                ? NetworkImage(_ChatGroupScreenState._urlComplet(_photoUrl!))
                : null,
            child: _photoUrl == null || _photoUrl!.isEmpty
                ? Text(
                    widget.nom
                        .substring(0, widget.nom.length.clamp(0, 2))
                        .toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(widget.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        if (_estCreateur) menu,
      ],
    );

    if (widget.embarque) {
      // Mode panneau droit (desktop) : en-tête compact + conversation
      return Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: enTete,
          ),
          Expanded(child: corps),
        ],
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: enTete,
      ),
      body: corps,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FICHIER JOINT DANS UNE BULLE DE MESSAGE
// ══════════════════════════════════════════════════════════════════

class FichierJoint extends StatelessWidget {
  final PieceJointe pj;
  final bool dark; // true = bulle de l'expéditeur (fond cyan, texte blanc)

  const FichierJoint({super.key, required this.pj, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final url = pj.url.startsWith('http')
        ? pj.url
        : 'https://billing-service-efm6.onrender.com${pj.url}';
    final couleur = dark ? Colors.white : AppColors.cyan;

    if (pj.estImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 200,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _tileFichier(couleur),
        ),
      );
    }
    return _tileFichier(couleur);
  }

  Widget _tileFichier(Color couleur) {
    return InkWell(
      onTap: () {
        // Ouvrir le fichier dans le navigateur / visionneuse externe
        launchUrl(
          Uri.parse(pj.url.startsWith('http')
              ? pj.url
              : 'https://billing-service-efm6.onrender.com${pj.url}'),
          mode: LaunchMode.externalApplication,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                color: couleur, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pj.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: couleur,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  Text(pj.tailleLisible,
                      style: TextStyle(
                          color: couleur.withValues(alpha: 0.7),
                          fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
