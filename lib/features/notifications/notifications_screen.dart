import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
// Importation de l'écran des rapports pour la redirection
import '../rapports/rapport_chef_screen.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class EduNotification {
  final String id;       // id du NotificationDestinataire
  final String notifId;  // id de la Notification
  final String titre;
  final String contenu;
  final String categorie;
  final bool urgence;
  final bool lue;
  final DateTime envoyeLe;
  final String expediteur;
  final bool estSondage;
  final List<SondageChoix> choixSondage;
  final String? monVoteChoixId;

  const EduNotification({
    required this.id,
    required this.notifId,
    required this.titre,
    required this.contenu,
    required this.categorie,
    required this.urgence,
    required this.lue,
    required this.envoyeLe,
    this.expediteur = 'Administration',
    this.estSondage = false,
    this.choixSondage = const [],
    this.monVoteChoixId,
  });

  EduNotification copyWith({
    bool? lue,
    String? monVoteChoixId,
    List<SondageChoix>? choixSondage,
  }) =>
      EduNotification(
        id:             id,
        notifId:        notifId,
        titre:          titre,
        contenu:        contenu,
        categorie:      categorie,
        urgence:        urgence,
        lue:            lue ?? this.lue,
        envoyeLe:       envoyeLe,
        expediteur:     expediteur,
        estSondage:     estSondage,
        choixSondage:   choixSondage ?? this.choixSondage,
        monVoteChoixId: monVoteChoixId ?? this.monVoteChoixId,
      );

  factory EduNotification.fromJson(Map<String, dynamic> j) {
    final notif = j['notification'] as Map<String, dynamic>? ?? j;

    final choix = (notif['choixSondage'] as List<dynamic>? ?? [])
        .map((c) => SondageChoix.fromJson(c as Map<String, dynamic>))
        .toList();

    return EduNotification(
      id:          j['id'] as String,
      notifId:     notif['id'] as String? ?? j['notificationId'] as String? ?? '',
      titre:       notif['titre']    as String? ?? '',
      contenu:     notif['contenu']  as String? ?? '',
      categorie:   notif['categorie'] as String? ?? 'administratif',
      urgence:     notif['urgence']  as bool? ?? false,
      lue:         j['lue']          as bool? ?? false,
      envoyeLe:    DateTime.parse(
        notif['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      expediteur:  notif['expediteur'] as String? ?? 'Administration',
      estSondage:  notif['estSondage'] as bool? ?? false,
      choixSondage: choix,
    );
  }
}

class SondageChoix {
  final String id;
  final String texte;
  final int votes;
  final int pourcentage;

  const SondageChoix({
    required this.id,
    required this.texte,
    required this.votes,
    this.pourcentage = 0,
  });

  factory SondageChoix.fromJson(Map<String, dynamic> j) => SondageChoix(
    id:          j['id']          as String,
    texte:       j['texte']       as String,
    votes:       j['votes']       as int? ?? 0,
    pourcentage: j['pourcentage'] as int? ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final notifsProvider = StateNotifierProvider<NotifsNotifier,
    AsyncValue<List<EduNotification>>>(
      (ref) => NotifsNotifier(ref),
);

class NotifsNotifier
    extends StateNotifier<AsyncValue<List<EduNotification>>> {
  final Ref _ref;
  NotifsNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> charger() async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider)!;
      final resp = await ApiClient.getNotif(
        '/notifications/mes-notifications',
        userId:          user.id,
        role:            user.role,
        etablissementId: user.etablissementId,
        departementId:   user.departementId,
        classeId:        user.classeId,
      );

      final raw = resp['notifications'] as List<dynamic>?
          ?? resp['notifs']        as List<dynamic>?
          ?? [];

      final liste = raw
          .map((e) => EduNotification.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(liste);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String destId) async {
    final user = _ref.read(currentUserProvider)!;
    try {
      await ApiClient.putNotif(
        '/notifications/$destId/lire',
        userId:          user.id,
        role:            user.role,
        etablissementId: user.etablissementId,
        departementId:   user.departementId,
        classeId:        user.classeId,
      );
    } catch (_) {}
    state = state.whenData((liste) => liste
        .map((n) => n.id == destId ? n.copyWith(lue: true) : n)
        .toList());
  }

  Future<List<SondageChoix>?> voter(String notifId, String choixId) async {
    final user = _ref.read(currentUserProvider)!;
    try {
      final resp = await ApiClient.postNotif(
        '/notifications/sondage/$notifId/voter',
        data:            {'choixId': choixId},
        userId:          user.id,
        role:            user.role,
        etablissementId: user.etablissementId,
        departementId:   user.departementId,
        classeId:        user.classeId,
      );
      final resultats = (resp['resultats'] as List<dynamic>? ?? [])
          .map((c) => SondageChoix.fromJson(c as Map<String, dynamic>))
          .toList();

      state = state.whenData((liste) => liste.map((n) {
        if (n.notifId != notifId) return n;
        return n.copyWith(
            monVoteChoixId: choixId, choixSondage: resultats);
      }).toList());
      return resultats;
    } catch (_) {
      return null;
    }
  }

  void ajouter(EduNotification notif) {
    state = state.whenData((l) => [notif, ...l]);
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  String? _filtre;
  static const _categories = [
    null,
    'examen',
    'resultat',
    'cours',
    'administratif',
    'urgent',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notifsProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync   = ref.watch(notifsProvider);
    final s             = ref.watch(stringsProvider);
    final user          = ref.watch(currentUserProvider);
    final primaryColor  = AppColors.forRole(user?.role ?? 'etudiant');
    final labels = [
      s.all, s.exams, s.results, s.course, s.admin, s.urgent,
    ];

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
                end:   Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.notifications,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        notifsAsync.when(
                          data: (notifs) => Text(
                            '${notifs.where((n) => !n.lue).length} non lues',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          loading: () => const SizedBox(),
                          error:   (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: () => ref.read(notifsProvider.notifier).charger(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color:        context.bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = _filtre == _categories[i];
                        return GestureDetector(
                          onTap: () => setState(() => _filtre = _categories[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? primaryColor : context.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? primaryColor : context.borderColor),
                              boxShadow: selected ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ] : [],
                            ),
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                color: selected ? Colors.white : context.textSecondary,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Expanded(
                    child: notifsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _ErrorState(
                        onRetry: () => ref.read(notifsProvider.notifier).charger(),
                      ),
                      data: (notifs) {
                        final filtered = _filtre == null
                            ? notifs
                            : _filtre == 'urgent'
                            ? notifs.where((n) => n.urgence).toList()
                            : notifs.where((n) => n.categorie == _filtre).toList();

                        if (filtered.isEmpty) return _EmptyState(label: s.noNotifications);

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _NotifTile(
                            notif: filtered[i],
                            onTap: () => _openModal(context, filtered[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openModal(BuildContext context, EduNotification notif) {
    ref.read(notifsProvider.notifier).markRead(notif.id);
    if (notif.estSondage) {
      _showSondageModal(context, notif);
    } else {
      _showNotifModal(context, notif);
    }
  }

  void _showNotifModal(BuildContext context, EduNotification notif) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => _NotifModal(
        notif: notif,
        color: _colorForCategorie(notif.categorie),
        icon:  _iconForCategorie(notif.categorie),
      ),
    );
  }

  void _showSondageModal(BuildContext context, EduNotification notif) {
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) => _SondageModal(
          notif:    notif,
          onVoter: (choixId) =>
              ref.read(notifsProvider.notifier).voter(notif.notifId, choixId),
        ),
      ),
    );
  }

  Color _colorForCategorie(String cat) {
    switch (cat) {
      case 'examen':        return AppColors.orange;
      case 'resultat':      return AppColors.green;
      case 'cours':         return AppColors.blue;
      case 'administratif': return AppColors.violet;
      default:              return AppColors.cyan;
    }
  }

  IconData _iconForCategorie(String cat) {
    switch (cat) {
      case 'examen':        return Icons.assignment_rounded;
      case 'resultat':      return Icons.grade_rounded;
      case 'cours':         return Icons.school_rounded;
      case 'administratif': return Icons.info_rounded;
      default:              return Icons.notifications_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE NOTIFICATION
// ══════════════════════════════════════════════════════════════════

class _NotifTile extends StatelessWidget {
  final EduNotification notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  Color get _color {
    switch (notif.categorie) {
      case 'examen':        return AppColors.orange;
      case 'resultat':      return AppColors.green;
      case 'cours':         return AppColors.blue;
      case 'administratif': return AppColors.violet;
      default:              return AppColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff    = DateTime.now().difference(notif.envoyeLe);
    final hours   = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h' : '${minutes}m';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notif.lue ? context.borderColor.withValues(alpha: 0.5) : _color.withValues(alpha: 0.4),
            width: notif.lue ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color:        _color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    notif.estSondage ? Icons.poll_rounded : Icons.notifications_active_rounded,
                    color: _color,
                    size:  22,
                  ),
                ),
                if (!notif.lue)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color:  _color,
                        shape:  BoxShape.circle,
                        border: Border.all(color: context.cardColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notif.expediteur,
                        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      Text(timeStr, style: TextStyle(color: context.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.titre,
                    style: TextStyle(
                      color:      context.textPrimary,
                      fontSize:   14,
                      fontWeight: notif.lue ? FontWeight.w600 : FontWeight.w800,
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.contenu.startsWith('PDF:') ? "📑 Rapport d'appel PDF" : notif.contenu,
                    style: TextStyle(color: context.textSecondary, fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notif.urgence || notif.estSondage) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (notif.urgence) _MiniBadge(label: 'URGENT', color: AppColors.red),
                        if (notif.estSondage) _MiniBadge(label: 'SONDAGE', color: AppColors.violet),
                      ],
                    ),
                  ],
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
// MODAL NOTIFICATION (CORRIGÉE POUR ÉVITER L'OVERFLOW)
// ══════════════════════════════════════════════════════════════════

class _NotifModal extends StatelessWidget {
  final EduNotification notif;
  final Color color;
  final IconData icon;
  const _NotifModal({required this.notif, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool isPdf = notif.contenu.startsWith('PDF:');

    return Container(
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif.titre, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(notif.expediteur, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CORRECTION : Gestion du PDF ou du texte long pour éviter l'overflow
          if (isPdf)
            _PdfContent(color: color)
          else
            _ScrollableTextContent(text: notif.contenu),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget interne pour le contenu texte avec scroll
class _ScrollableTextContent extends StatelessWidget {
  final String text;
  const _ScrollableTextContent({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4, // Limite à 40% de la hauteur écran
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

// Widget interne pour les notifications PDF
class _PdfContent extends StatelessWidget {
  final Color color;
  const _PdfContent({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: AppColors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            "Cette notification contient un rapport PDF.",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RapportsChefScreen()));
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text("Ouvrir l'onglet Rapports"),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL SONDAGE
// ══════════════════════════════════════════════════════════════════

class _SondageModal extends StatefulWidget {
  final EduNotification notif;
  final Future<List<SondageChoix>?> Function(String choixId) onVoter;
  const _SondageModal({required this.notif, required this.onVoter});

  @override
  State<_SondageModal> createState() => _SondageModalState();
}

class _SondageModalState extends State<_SondageModal> {
  String? _selectedChoixId;
  bool _loading = false;
  bool _voted   = false;
  List<SondageChoix> _resultats = [];

  @override
  void initState() {
    super.initState();
    _resultats        = widget.notif.choixSondage;
    _voted            = widget.notif.monVoteChoixId != null;
    _selectedChoixId  = widget.notif.monVoteChoixId;
  }

  int get _totalVotes => _resultats.fold(0, (s, c) => s + c.votes);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Sondage', style: TextStyle(color: AppColors.violet, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(widget.notif.contenu, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
          const SizedBox(height: 24),
          ..._resultats.map((c) {
            final isMyVote = _selectedChoixId == c.id;
            final ratio    = _totalVotes == 0 ? 0.0 : c.votes / _totalVotes;
            return GestureDetector(
              onTap: _voted ? null : () => setState(() => _selectedChoixId = c.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isMyVote ? AppColors.violet.withValues(alpha: 0.1) : context.bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isMyVote ? AppColors.violet : context.borderColor, width: isMyVote ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(isMyVote ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isMyVote ? AppColors.violet : context.textMuted, size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(c.texte, style: TextStyle(color: isMyVote ? AppColors.violet : context.textPrimary, fontWeight: isMyVote ? FontWeight.w700 : FontWeight.w500))),
                        if (_voted) Text('${(ratio * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_voted) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: ratio, minHeight: 6, color: AppColors.violet, backgroundColor: context.borderColor),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _voted || _selectedChoixId == null || _loading
                  ? (_voted ? () => Navigator.pop(context) : null)
                  : () async {
                setState(() => _loading = true);
                final res = await widget.onVoter(_selectedChoixId!);
                if (res != null) setState(() { _resultats = res; _voted = true; });
                setState(() => _loading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _voted ? context.borderColor : AppColors.violet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(_voted ? 'Fermer' : 'Voter', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
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
          const Text('Erreur de chargement'),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: context.borderColor),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(color: context.textMuted)),
        ],
      ),
    );
  }
}
