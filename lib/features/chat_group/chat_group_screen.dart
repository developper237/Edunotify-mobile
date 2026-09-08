import '../../core/locale.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

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

  bool get estAudio =>
      type.startsWith('audio/') ||
      ['.m4a', '.wav', '.mp3', '.ogg', '.webm', '.aac', '.opus']
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

// Statut d'un message (mode hors-ligne type WhatsApp)
enum MessageStatut { enAttente, envoye, lu }

class MessageChat {
  final String id;
  final String texte;
  final String userId;
  final String? userNom;
  final String? userPrenom;
  final PieceJointe? pieceJointe;
  final DateTime createdAt;
  final bool estMien;
  final List<String> luPar;
  final String? clientId;
  // Statut local (hors-ligne) — utilisé uniquement pour nos propres messages
  final MessageStatut statut;

  const MessageChat({
    required this.id,
    required this.texte,
    required this.userId,
    this.userNom,
    this.userPrenom,
    this.pieceJointe,
    required this.createdAt,
    this.estMien = false,
    this.luPar = const [],
    this.clientId,
    this.statut = MessageStatut.envoye,
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
      luPar: (j['luPar'] as List? ?? []).map((e) => e.toString()).toList(),
      clientId: j['clientId'] as String?,
    );
  }

  // true si au moins une AUTRE personne que moi a lu le message
  bool luParQuelquUn(String currentUserId) =>
      luPar.any((id) => id != currentUserId);

  MessageChat copyWith({
    MessageStatut? statut,
    List<String>? luPar,
  }) =>
      MessageChat(
        id: id,
        texte: texte,
        userId: userId,
        userNom: userNom,
        userPrenom: userPrenom,
        pieceJointe: pieceJointe,
        createdAt: createdAt,
        estMien: estMien,
        luPar: luPar ?? this.luPar,
        clientId: clientId,
        statut: statut ?? this.statut,
      );

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
  Strings get s => ref.watch(stringsProvider);
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
        title: Text(s.createGroup),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(hintText: 'Nom du groupe'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
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
          SnackBar(content: Text('${s.error}: $e')),
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
        title: Text(s.groupCreated),
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
                        SnackBar(content: Text(s.codeCopied)),
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
            child: Text(s.close),
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
        title: Text(s.joinWithCode),
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
              child: Text(s.cancel)),
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
        SnackBar(content: Text(s.joinedGroup)),
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
          SnackBar(content: Text('${s.error}: $e')),
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
        title: Text(s.deleteGroup),
        content: Text(
            'Voulez-vous vraiment supprimer « ${g.nom} » ? Tous les messages seront perdus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.delete),
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
          SnackBar(content: Text(s.groupDeleted)),
        );
      }
      await _chargerGroupes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.error}: $e')),
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
                                groupeId: g.id,
                                nom: g.nom,
                                photoUrl: g.photoUrl,
                                creeParId: g.creeParId,
                              ),
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
        title: Text(s.messages),
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
  Strings get s => ref.watch(stringsProvider);
  final _msgController = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageChat> _messages = [];
  List<MessageChat> _pending = []; // messages hors-ligne (en attente)
  DateTime? _dernierMsgLe; // curseur incrémental (dernier message serveur chargé)
  bool _isLoading = true;
  Timer? _pollTimer;
  String? _photoUrl;

  String get _cleFileAttente => 'chat_pending_groupe_${widget.groupeId}';

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.photoUrl;
    _chargerMessages();
    _chargerFileAttente();
    // Polling toutes les 5 secondes : messages + renvoi des messages en attente
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _chargerMessages(silent: true);
      _flusherFileAttente();
    });
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
        _pending = list.map((m) => MessageChat(
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
              clientId: m['clientId'] as String?,
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
                    'clientId': m.clientId,
                  })
              .toList()));
    } catch (_) {}
  }

  // Renvoie les messages en attente ; retire ceux qui partent enfin
  Future<void> _flusherFileAttente() async {
    if (_pending.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final restant = <MessageChat>[];
    final envoyes = <String>[]; // clientIds envoyés avec succès
    for (final m in _pending) {
      try {
        await ApiClient.postChat(
          '/chat/groups/${widget.groupeId}/messages',
          data: {
            'texte': m.texte,
            'pieceJointe': m.pieceJointe?.toJson(),
            if (m.clientId != null) 'clientId': m.clientId,
          },
          userId: user.id,
          role: user.role,
          etablissementId: user.etablissementId,
        );
        if (m.clientId != null) envoyes.add(m.clientId!);
      } catch (_) {
        restant.add(m); // toujours hors-ligne, on réessaiera
      }
    }
    if (restant.length != _pending.length || restant.isEmpty) {
      // Retirer les placeholders locaux de _messages pour éviter les doublons
      // quand _chargerMessages va récupérer la copie serveur.
      if (envoyes.isNotEmpty && mounted) {
        setState(() {
          _pending = restant;
          _messages.removeWhere(
              (m) => m.clientId != null && envoyes.contains(m.clientId));
        });
      } else if (mounted) {
        setState(() => _pending = restant);
      }
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
      // récents que le dernier déjà chargé (allége considérablement le polling
      // : au lieu de re-télécharger tout l'historique toutes les 5 s).
      if (_dernierMsgLe != null) {
        params['apres'] = _dernierMsgLe!.toIso8601String();
      }

      final resp = await ApiClient.getChat(
        '/chat/groups/${widget.groupeId}/messages',
        userId: user.id,
        role: user.role,
        etablissementId: user.etablissementId,
        params: params,
      );

      final nouveaux = (resp['messages'] as List? ?? [])
          .map((e) => MessageChat.fromJson(e as Map<String, dynamic>, user.id))
          .toList();

      setState(() {
        if (params['apres'] != null) {
          // Mode incrémental : fusionner en reconciliant les pending avec
          // les réponses serveur (même clientId = même message).
          if (nouveaux.isNotEmpty) {
            final serverCids = nouveaux
                .where((n) => n.clientId != null)
                .map((n) => n.clientId!)
                .toSet();
            final serverIds = nouveaux.map((n) => n.id).toSet();
            final merge = <MessageChat>[];
            for (final n in nouveaux) {
              merge.add(n.copyWith(statut: MessageStatut.envoye));
            }
            // Retirer les placeholders locaux (local-*) qui ont un clientId
            // correspondant à un message serveur, puis ajouter les serveurs.
            _messages.removeWhere((m) =>
                m.id.startsWith('local-') &&
                m.clientId != null &&
                serverCids.contains(m.clientId));
            // Aussi retirer les messages serveur déjà présents pour éviter
            // les doublons lors du rechargement incrémental.
            _messages.removeWhere((m) => serverIds.contains(m.id));
            _messages = [..._messages, ...merge];
          }
        } else {
          // Chargement initial : messages en attente puis historique serveur
          final serverCids = nouveaux
              .where((n) => n.clientId != null)
              .map((n) => n.clientId!)
              .toSet();
          final serverIds = nouveaux.map((m) => m.id).toSet();
          // Retirer les placeholders locaux qui ont un match serveur
          final pendingRestants = _pending.where((p) {
            if (p.clientId != null && serverCids.contains(p.clientId)) {
              return false; // serveur a reçu ce message
            }
            if (serverIds.contains(p.id)) return false;
            return true;
          }).toList();
          _messages = [
            ...nouveaux,
            ...pendingRestants,
          ];
          _pending = pendingRestants;
        }
        _isLoading = false;
      });

      // Le curseur ne suit que les messages réellement persistés côté serveur
      // (jamais les messages en attente, aux ids locaux).
      if (nouveaux.isNotEmpty) {
        _dernierMsgLe = nouveaux.last.createdAt;
      }
      // NE PAS définir _dernierMsgLe depuis _messages (qui contient des
      // messages locaux pending avec DateTime.now()) — sinon le filtre
      // incrémental apres= exclut les copies serveur.

      // Auto-scroll en bas
      if (_scrollCtrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  // Ajoute le message localement (même sans connexion) puis tente l'envoi
  Future<void> _envoyer({String? texteForce, PieceJointe? pj}) async {
    final text = (texteForce ?? _msgController.text).trim();
    if (text.isEmpty && pj == null) return;
    if (pj == null) _msgController.clear();

    final user = ref.read(currentUserProvider);
    // clientId stable pour l'idempotence : même message = même clientId
    final cid = '${user?.id ?? ''}-${DateTime.now().microsecondsSinceEpoch}';
    final localMsg = MessageChat(
      id: 'local-$cid',
      texte: text,
      userId: user?.id ?? '',
      userNom: user?.nom,
      userPrenom: user?.prenom,
      pieceJointe: pj,
      createdAt: DateTime.now(),
      estMien: true,
      clientId: cid,
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
        '/chat/groups/${widget.groupeId}/pieces-jointes',
        fileBytes: fileBytes,
        filename: file.name,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      await _envoyer(pj: PieceJointe.fromJson(resp));
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
        '/chat/groups/${widget.groupeId}/pieces-jointes',
        fileBytes: bytes,
        filename: nom,
        mimeType: mime,
        userId: user?.id ?? '',
        role: user?.role ?? '',
        etablissementId: user?.etablissementId ?? '',
      );
      await _envoyer(pj: PieceJointe.fromJson(resp));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi vocal : $e')),
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
          SnackBar(content: Text('${s.error}: $e')),
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
              child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.delete),
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
          SnackBar(content: Text('${s.error}: $e')),
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
        title: Text(s.deleteGroup),
        content: Text(
            'Voulez-vous vraiment supprimer « ${widget.nom} » ? Tous les messages seront perdus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.delete),
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
          SnackBar(content: Text(s.groupDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.error}: $e')),
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
                                          _StatutMessage(
                                            statut: msg.statut,
                                            lu: msg.luParQuelquUn(
                                                ref.read(currentUserProvider)
                                                        ?.id ??
                                                    ''),
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
                EnregistreurAudio(onEnvoye: _envoyerAudio, couleur: AppColors.cyan),
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

// Statut d'un message envoyé (type WhatsApp)
class _StatutMessage extends StatelessWidget {
  final MessageStatut statut;
  final bool lu;

  const _StatutMessage({required this.statut, required this.lu});

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
// FICHIER JOINT DANS UNE BULLE DE MESSAGE
// ══════════════════════════════════════════════════════════════════

String _urlPieceJointe(PieceJointe pj) => pj.url.startsWith('http')
    ? pj.url
    : 'https://billing-service-efm6.onrender.com${pj.url}';

class FichierJoint extends StatefulWidget {
  final PieceJointe pj;
  final bool dark; // true = bulle de l'expéditeur (fond cyan, texte blanc)

  const FichierJoint({super.key, required this.pj, this.dark = false});

  @override
  State<FichierJoint> createState() => _FichierJointState();
}

class _FichierJointState extends State<FichierJoint> {
  bool _enTelechargement = false;

  PieceJointe get pj => widget.pj;

  @override
  Widget build(BuildContext context) {
    final url = _urlPieceJointe(pj);
    final couleur = widget.dark ? Colors.white : AppColors.cyan;

    if (pj.estAudio) {
      return _MessageAudio(url: url, dark: widget.dark);
    }

    if (pj.estImage) {
      return GestureDetector(
        onTap: () => _ouvrirImage(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 200,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _tileFichier(couleur),
          ),
        ),
      );
    }
    return _tileFichier(couleur);
  }

  // Visionneuse plein écran pour les images
  void _ouvrirImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(pj.nom,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // Télécharge le fichier puis l'ouvre avec l'app par défaut
  Future<void> _telecharger() async {
    if (_enTelechargement) return;
    setState(() => _enTelechargement = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours...')),
    );
    try {
      final url = _urlPieceJointe(pj);
      final dir = Directory.systemTemp;
      final fichier =
          File('${dir.path}${Platform.pathSeparator}${pj.nom}');
      final dio = Dio();
      await dio.download(url, fichier.path);
      await OpenFilex.open(fichier.path);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Fichier enregistré : ${pj.nom}')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Téléchargement impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enTelechargement = false);
    }
  }

  Widget _tileFichier(Color couleur) {
    return InkWell(
      onTap: _telecharger,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _enTelechargement
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: couleur))
                : Icon(Icons.insert_drive_file_rounded,
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

// ══════════════════════════════════════════════════════════════════
// LECTEUR AUDIO DANS UNE BULLE (message vocal)
// ══════════════════════════════════════════════════════════════════

class _MessageAudio extends StatefulWidget {
  final String url;
  final bool dark; // bulle de l'expéditeur (fond cyan, texte blanc)
  const _MessageAudio({required this.url, this.dark = false});

  @override
  State<_MessageAudio> createState() => _MessageAudioState();
}

class _MessageAudioState extends State<_MessageAudio> {
  final AudioPlayer _player = AudioPlayer();
  bool _jouer = false;
  bool _chargement = false;
  Duration _duree = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duree = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _jouer = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String get _temps {
    final d = _duree > Duration.zero ? _duree : const Duration(seconds: 1);
    final pos = _position;
    final restant = d - pos;
    final s = restant.inSeconds.clamp(0, 599);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggle() async {
    if (_jouer) {
      await _player.pause();
      if (mounted) setState(() => _jouer = false);
      return;
    }
    setState(() => _chargement = true);
    try {
      await _player.play(UrlSource(widget.url));
      if (mounted) setState(() => _jouer = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lecture impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.dark ? Colors.white : AppColors.cyan;
    final fraction = _duree > Duration.zero
        ? (_position.inMilliseconds / _duree.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _chargement ? null : _toggle,
            icon: _chargement
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: couleur))
                : Icon(
                    _jouer ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: couleur,
                  ),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: couleur.withValues(alpha: 0.15),
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _temps,
                    style: TextStyle(
                        color: couleur.withValues(alpha: 0.8), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BOUTON ENREGISTREMENT VOCAL (trombone du champ de saisie)
// ══════════════════════════════════════════════════════════════════

class EnregistreurAudio extends StatefulWidget {
  // Reçoit les octets du fichier audio enregistré + nom + type MIME
  final Future<void> Function(List<int> bytes, String nom, String mime) onEnvoye;
  final Color couleur;

  const EnregistreurAudio({
    super.key,
    required this.onEnvoye,
    this.couleur = AppColors.cyan,
  });

  @override
  State<EnregistreurAudio> createState() => _EnregistreurAudioState();
}

class _EnregistreurAudioState extends State<EnregistreurAudio> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _enregistre = false;
  bool _busy = false;
  Timer? _timer;
  Duration _duree = Duration.zero;
  String? _fichierPath;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_enregistre) {
      await _stopper();
    } else {
      await _demarrer();
    }
  }

  Future<void> _demarrer() async {
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission micro refusée')),
          );
        }
        return;
      }
      // WAV sur desktop (record_windows), AAC (m4a) sur mobile
      final windows = Platform.isWindows;
      final ext = windows ? 'wav' : 'm4a';
      _fichierPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}msg_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav),
          path: _fichierPath!);
      if (mounted) {
        setState(() {
          _enregistre = true;
          _duree = Duration.zero;
        });
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _duree += const Duration(seconds: 1));
      });
    } catch (e) {
      // Repli : si l'encodeur échoue sur cette plateforme, on essaie AAC
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $e')),
        );
      }
    }
  }

  Future<void> _stopper() async {
    _timer?.cancel();
    final path = _fichierPath;
    if (mounted) setState(() => _enregistre = false);
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final chemin = await _recorder.stop();
      if (chemin == null) return;
      final bytes = await File(chemin).readAsBytes();
      final windows = Platform.isWindows;
      await widget.onEnvoye(
          bytes, 'message-vocal.${windows ? 'wav' : 'm4a'}',
          windows ? 'audio/wav' : 'audio/mp4');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur enregistrement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _temps {
    final s = _duree.inSeconds.clamp(0, 599);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_enregistre) {
      // Pendant l'enregistrement : pastille rouge + durée + stop
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop_rounded, color: AppColors.red, size: 18),
              const SizedBox(width: 6),
              Text(_temps,
                  style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // État normal : bouton micro
    return IconButton(
      onPressed: _busy ? null : _toggle,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.mic_rounded, color: widget.couleur),
      tooltip: 'Message vocal',
    );
  }
}