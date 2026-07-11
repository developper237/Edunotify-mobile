import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../rapports/rapport_chef_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class SondageChoix {
  final String id;
  final String texte;
  final int votes;
  final int pourcentage;
  final String? questionId;

  const SondageChoix({
    required this.id,
    required this.texte,
    required this.votes,
    required this.pourcentage,
    this.questionId,
  });

  factory SondageChoix.fromJson(Map<String, dynamic> j) => SondageChoix(
    id:          j['id']          as String? ?? '',
    texte:       j['texte']       as String? ?? '',
    votes:       (j['_count']?['votes'] as int?) ?? j['votes'] as int? ?? 0,
    pourcentage: j['pourcentage'] as int? ?? 0,
    questionId:  j['questionId']  as String?,
  );
}

class SondageQuestion {
  final String id;
  final String texte;
  final int ordre;
  final List<SondageChoix> choix;

  const SondageQuestion({
    required this.id,
    required this.texte,
    required this.ordre,
    required this.choix,
  });

  factory SondageQuestion.fromJson(Map<String, dynamic> j) => SondageQuestion(
    id:    j['id']    as String? ?? '',
    texte: j['texte'] as String? ?? '',
    ordre: j['ordre'] as int?    ?? 0,
    choix: (j['choixSondage'] as List<dynamic>? ?? [])
        .map((c) => SondageChoix.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class EduNotification {
  final String id;
  final String notifId;
  final String titre;
  final String contenu;
  final String categorie;
  final bool urgence;
  final bool lue;
  final DateTime envoyeLe;
  final String expediteur;
  final String? expediteurId;   // ← ID de l'auteur pour détecter si on est l'auteur
  final bool estSondage;
  final List<SondageQuestion> questions;
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
    this.expediteurId,
    this.estSondage = false,
    this.questions = const [],
    this.monVoteChoixId,
  });

  EduNotification copyWith({
    bool? lue,
    String? monVoteChoixId,
    List<SondageQuestion>? questions,
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
        expediteurId:   expediteurId,
        estSondage:     estSondage,
        questions:      questions ?? this.questions,
        monVoteChoixId: monVoteChoixId ?? this.monVoteChoixId,
      );

  factory EduNotification.fromJson(Map<String, dynamic> j) {
    final notif = j['notification'] as Map<String, dynamic>? ?? j;
    final expediteurStr = () {
      final exp = notif['expediteur'];
      if (exp is Map<String, dynamic>) {
        return '${exp['prenom'] ?? ''} ${exp['nom'] ?? ''}'.trim();
      }
      if (exp is String && exp.isNotEmpty) return exp;
      return 'Administration';
    }();
    final questionsRaw = notif['questionsSondage'] as List<dynamic>? ?? [];
    final questions = questionsRaw
        .map((q) => SondageQuestion.fromJson(q as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));

    return EduNotification(
      id:           j['id']             as String,
      notifId:      notif['id']         as String? ?? j['notificationId'] as String? ?? '',
      titre:        notif['titre']      as String? ?? '',
      contenu:      notif['contenu']    as String? ?? '',
      categorie:    notif['categorie']  as String? ?? 'administratif',
      urgence:      notif['urgence']    as bool?   ?? false,
      lue:          j['lue']            as bool?   ?? false,
      envoyeLe: DateTime.parse(
        notif['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      expediteur:   expediteurStr.isNotEmpty ? expediteurStr : 'Administration',
      expediteurId: notif['expediteurId'] as String?,   // ← nouveau champ
      estSondage:   notif['estSondage']  as bool? ?? false,
      questions:    questions,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final notifsProvider = StateNotifierProvider<NotifsNotifier,
    AsyncValue<List<EduNotification>>>(
      (ref) => NotifsNotifier(ref),
);

class NotifsNotifier extends StateNotifier<AsyncValue<List<EduNotification>>> {
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
          ?? resp['notifs']            as List<dynamic>?
          ?? [];
      state = AsyncValue.data(
        raw.map((e) => EduNotification.fromJson(e as Map<String, dynamic>)).toList(),
      );
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
    state = state.whenData((liste) =>
        liste.map((n) => n.id == destId ? n.copyWith(lue: true) : n).toList());
  }

  Future<bool> voter(String notifId, List<String> choixIds) async {
    final user = _ref.read(currentUserProvider)!;
    try {
      final resp = await ApiClient.postNotif(
        '/notifications/sondage/$notifId/voter',
        data:            {'choixIds': choixIds},
        userId:          user.id,
        role:            user.role,
        etablissementId: user.etablissementId,
        departementId:   user.departementId,
        classeId:        user.classeId,
      );
      final questionsRaw = resp['questions'] as List<dynamic>? ?? [];
      state = state.whenData((liste) => liste.map((n) {
        if (n.notifId != notifId) return n;
        if (questionsRaw.isEmpty) return n;
        final questionsUpdated = questionsRaw
            .map((q) => SondageQuestion.fromJson(q as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));
        return n.copyWith(
            monVoteChoixId: choixIds.first, questions: questionsUpdated);
      }).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> supprimer(String destId) async {
    state = state.whenData(
          (liste) => liste.where((n) => n.id != destId).toList(),
    );
    final user = _ref.read(currentUserProvider)!;
    try {
      await ApiClient.deleteNotif(
        '/notifications/$destId',
        userId:          user.id,
        role:            user.role,
        etablissementId: user.etablissementId,
        departementId:   user.departementId,
        classeId:        user.classeId,
      );
    } catch (_) {}
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

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _filtre;
  StreamSubscription? _fcmSubscription;

  static const _categories = [
    null, 'examen', 'resultat', 'cours', 'administratif', 'urgent',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notifsProvider.notifier).charger();
    });
    _fcmSubscription = FirebaseMessaging.onMessage.listen((_) {
      if (mounted) ref.read(notifsProvider.notifier).charger();
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notifsProvider);
    final s           = ref.watch(stringsProvider);
    final labels = [s.all, s.exams, s.results, s.course, s.admin, s.urgent];

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.notifications,
                          style: TextStyle(
                              color:         context.textPrimary,
                              fontSize:      24,
                              fontWeight:    FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      notifsAsync.when(
                        data: (n) {
                          final unread = n.where((x) => !x.lue).length;
                          return Text(
                            unread == 0
                                ? 'Tout est lu'
                                : '$unread non lue${unread > 1 ? 's' : ''}',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 13),
                          );
                        },
                        loading: () => const SizedBox(),
                        error:   (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: context.textMuted, size: 22),
                    onPressed: () =>
                        ref.read(notifsProvider.notifier).charger(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = _filtre == _categories[i];
                  return GestureDetector(
                    onTap: () => setState(() => _filtre = _categories[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? context.textPrimary : context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? context.textPrimary
                              : context.borderColor,
                        ),
                      ),
                      child: Text(labels[i],
                          style: TextStyle(
                              color: selected
                                  ? context.bgColor
                                  : context.textSecondary,
                              fontSize:   12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => _ErrorState(
                  onRetry: () => ref.read(notifsProvider.notifier).charger(),
                ),
                data: (notifs) {
                  final filtered = _filtre == null
                      ? notifs
                      : _filtre == 'urgent'
                      ? notifs.where((n) => n.urgence).toList()
                      : notifs.where((n) => n.categorie == _filtre).toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(label: s.noNotifications);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final notif = filtered[i];
                      return Dismissible(
                        key:       ValueKey(notif.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: AppColors.red.withValues(alpha: 0.7),
                              size: 22),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: context.cardColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Supprimer ?',
                                  style: TextStyle(
                                      color:      context.textPrimary,
                                      fontWeight: FontWeight.w700)),
                              content: Text(
                                'Cette notification sera retirée de votre fil.',
                                style: TextStyle(
                                    color: context.textMuted, fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Annuler',
                                      style: TextStyle(
                                          color: context.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Supprimer',
                                      style: TextStyle(color: AppColors.red)),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) {
                          ref.read(notifsProvider.notifier).supprimer(notif.id);
                        },
                        child: _NotifTile(
                          notif: notif,
                          onTap: () => _openModal(context, ref, notif),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openModal(BuildContext context, WidgetRef ref, EduNotification notif) {
    ref.read(notifsProvider.notifier).markRead(notif.id);
    if (!notif.estSondage) {
      _showNotifDialog(context, notif);
      return;
    }

    // Sondage : l'auteur voit les résultats en temps réel, les autres votent
    final currentUser = ref.read(currentUserProvider);
    final estAuteur   = currentUser?.id == notif.expediteurId;

    if (estAuteur) {
      _showResultatsDialog(context, ref, notif);
    } else {
      _showSondageDialog(context, ref, notif);
    }
  }

  void _showNotifDialog(BuildContext context, EduNotification notif) {
    showDialog(
      context:            context,
      barrierDismissible: true,
      builder: (_) => _NotifDialog(notif: notif),
    );
  }

  void _showSondageDialog(BuildContext context, WidgetRef ref, EduNotification notif) {
    showDialog(
      context:            context,
      barrierDismissible: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) => _SondageDialog(
          notif:   notif,
          onVoter: (choixIds) =>
              ref.read(notifsProvider.notifier).voter(notif.notifId, choixIds),
        ),
      ),
    );
  }

  void _showResultatsDialog(BuildContext context, WidgetRef ref, EduNotification notif) {
    showDialog(
      context:            context,
      barrierDismissible: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) => _SondageResultatsDialog(
          notif:   notif,
          userId:  ref.read(currentUserProvider)!.id,
          role:    ref.read(currentUserProvider)!.role,
          etablissementId: ref.read(currentUserProvider)!.etablissementId,
          departementId:   ref.read(currentUserProvider)!.departementId,
          classeId:        ref.read(currentUserProvider)!.classeId,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE NOTIFICATION
// ══════════════════════════════════════════════════════════════════

class _NotifTile extends StatelessWidget {
  final EduNotification notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon {
    switch (notif.categorie) {
      case 'examen':        return Icons.assignment_outlined;
      case 'resultat':      return Icons.grade_outlined;
      case 'cours':         return Icons.school_outlined;
      case 'administratif': return Icons.info_outline;
      default:              return Icons.notifications_none_rounded;
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: context.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        context.borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notif.estSondage ? Icons.poll_outlined : _icon,
                    color: notif.lue ? context.textMuted : context.textSecondary,
                    size: 19,
                  ),
                ),
                if (!notif.lue)
                  Positioned(
                    right: 1, top: 1,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color:  context.textPrimary,
                        shape:  BoxShape.circle,
                        border: Border.all(color: context.cardColor, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(notif.expediteur,
                            style: TextStyle(
                                color:      context.textMuted,
                                fontSize:   11,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(timeStr,
                          style: TextStyle(
                              color: context.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notif.titre,
                      style: TextStyle(
                          color:      context.textPrimary,
                          fontSize:   13,
                          fontWeight: notif.lue
                              ? FontWeight.w500
                              : FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    notif.estSondage
                        ? '${notif.questions.length} question(s) · Appuyez pour répondre'
                        : notif.contenu.startsWith('PDF:')
                        ? "Rapport d'appel reçu"
                        : notif.contenu,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notif.urgence || notif.estSondage) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (notif.urgence) _MiniBadge(label: 'URGENT'),
                        if (notif.estSondage) _MiniBadge(label: 'SONDAGE'),
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
// POPUP NOTIFICATION SIMPLE
// ══════════════════════════════════════════════════════════════════

class _NotifDialog extends StatelessWidget {
  final EduNotification notif;
  const _NotifDialog({required this.notif});

  IconData get _icon {
    switch (notif.categorie) {
      case 'examen':        return Icons.assignment_outlined;
      case 'resultat':      return Icons.grade_outlined;
      case 'cours':         return Icons.school_outlined;
      case 'administratif': return Icons.info_outline;
      default:              return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = notif.contenu.startsWith('PDF:');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color:        context.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        context.borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: context.textSecondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notif.titre,
                          style: TextStyle(
                              color:      context.textPrimary,
                              fontSize:   16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(notif.expediteur,
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        context.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: context.textMuted, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: context.borderColor),
            const SizedBox(height: 14),
            if (isPdf)
              const _PdfContent()
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Text(notif.contenu,
                      style: TextStyle(
                          color:   context.textPrimary,
                          fontSize: 14,
                          height:  1.7)),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.textPrimary,
                  foregroundColor: context.bgColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Fermer',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfContent extends StatelessWidget {
  const _PdfContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        context.borderColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              color: context.textSecondary, size: 40),
          const SizedBox(height: 10),
          Text('Cette notification contient un rapport PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RapportsChefScreen()));
            },
            icon:  Icon(Icons.open_in_new_rounded,
                size: 16, color: context.textPrimary),
            label: Text("Ouvrir l'onglet Rapports",
                style: TextStyle(color: context.textPrimary)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.borderColor)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// POPUP SONDAGE — VOTER (destinataire)
// ══════════════════════════════════════════════════════════════════

class _SondageDialog extends StatefulWidget {
  final EduNotification notif;
  final Future<bool> Function(List<String> choixIds) onVoter;
  const _SondageDialog({required this.notif, required this.onVoter});

  @override
  State<_SondageDialog> createState() => _SondageDialogState();
}

class _SondageDialogState extends State<_SondageDialog> {
  final Map<String, String> _selections = {};
  bool _loading = false;
  bool _voted   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _voted = widget.notif.monVoteChoixId != null;
  }

  bool get _toutesQuestionsRepondues {
    for (final q in widget.notif.questions) {
      if (!_selections.containsKey(q.id)) return false;
    }
    return widget.notif.questions.isNotEmpty;
  }

  Future<void> _voter() async {
    if (!_toutesQuestionsRepondues) {
      setState(() => _error = 'Veuillez répondre à toutes les questions.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final success = await widget.onVoter(_selections.values.toList());
    setState(() {
      _loading = false;
      if (success) _voted = true;
      else _error = 'Erreur lors du vote.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.notif.questions;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color:        context.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        context.borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.poll_outlined,
                      color: context.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sondage',
                          style: TextStyle(
                              color:      context.textMuted,
                              fontSize:   11,
                              fontWeight: FontWeight.w600)),
                      Text(widget.notif.titre,
                          style: TextStyle(
                              color:      context.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        context.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: context.textMuted, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: context.borderColor),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.50,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: questions.asMap().entries.map((entry) {
                    final qIndex = entry.key;
                    final q      = entry.value;
                    final totalQ = q.choix.fold(0, (s, c) => s + c.votes);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        context.bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border:       Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${qIndex + 1}. ${q.texte}',
                              style: TextStyle(
                                  color:      context.textPrimary,
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  height:     1.4)),
                          const SizedBox(height: 10),
                          ...q.choix.map((c) {
                            final isSelected = _selections[q.id] == c.id;
                            final ratio = totalQ == 0 ? 0.0 : c.votes / totalQ;
                            return GestureDetector(
                              onTap: _voted
                                  ? null
                                  : () => setState(
                                      () => _selections[q.id] = c.id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? context.textPrimary
                                      .withValues(alpha: 0.06)
                                      : context.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? context.textPrimary
                                        .withValues(alpha: 0.4)
                                        : context.borderColor,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_off_rounded,
                                          color: isSelected
                                              ? context.textPrimary
                                              : context.textMuted,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(c.texte,
                                              style: TextStyle(
                                                  color:      context.textPrimary,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                  fontSize: 13)),
                                        ),
                                        if (_voted)
                                          Text('${(ratio * 100).toInt()}%',
                                              style: TextStyle(
                                                  color:      context.textSecondary,
                                                  fontSize:   12,
                                                  fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    if (_voted) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value:           ratio,
                                          minHeight:       4,
                                          color:           context.textPrimary
                                              .withValues(
                                              alpha: isSelected ? 0.7 : 0.2),
                                          backgroundColor: context.borderColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        context.borderColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: context.textSecondary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: context.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : _voted
                    ? () => Navigator.pop(context)
                    : _voter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _voted
                      ? context.borderColor
                      : context.textPrimary,
                  foregroundColor: _voted
                      ? context.textPrimary
                      : context.bgColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.bgColor))
                    : Text(_voted ? 'Fermer' : 'Voter',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// POPUP RÉSULTATS EN TEMPS RÉEL — AUTEUR DU SONDAGE
// ══════════════════════════════════════════════════════════════════

class _SondageResultatsDialog extends StatefulWidget {
  final EduNotification notif;
  final String userId;
  final String role;
  final String? etablissementId;
  final String? departementId;
  final String? classeId;

  const _SondageResultatsDialog({
    required this.notif,
    required this.userId,
    required this.role,
    this.etablissementId,
    this.departementId,
    this.classeId,
  });

  @override
  State<_SondageResultatsDialog> createState() =>
      _SondageResultatsDialogState();
}

class _SondageResultatsDialogState extends State<_SondageResultatsDialog> {
  Timer? _timer;
  List<SondageQuestion> _questions = [];
  int _nbVotants       = 0;
  int _nbDestinataires = 0;
  int _tauxParticipation = 0;
  bool _loading = true;
  String? _error;
  DateTime? _derniereMaj;

  @override
  void initState() {
    super.initState();
    _questions = widget.notif.questions; // affichage immédiat avec données initiales
    _charger();
    // Rafraîchissement toutes les 5 secondes
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _charger());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final resp = await ApiClient.getNotif(
        '/notifications/sondage/${widget.notif.notifId}/resultats',
        userId:          widget.userId,
        role:            widget.role,
        etablissementId: widget.etablissementId,
        departementId:   widget.departementId,
        classeId:        widget.classeId,
      );

      final questionsRaw = resp['questions'] as List<dynamic>? ?? [];
      final questions = questionsRaw
          .map((q) => SondageQuestion.fromJson(q as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));

      if (mounted) {
        setState(() {
          _questions        = questions;
          _nbVotants        = resp['nbVotants']        as int? ?? 0;
          _nbDestinataires  = resp['nbDestinataires']  as int? ?? 0;
          _tauxParticipation = resp['tauxParticipation'] as int? ?? 0;
          _loading          = false;
          _error            = null;
          _derniereMaj      = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = 'Erreur de chargement';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color:        context.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── En-tête ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:        context.borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bar_chart_rounded,
                      color: context.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Résultats en direct',
                              style: TextStyle(
                                  color:      context.textMuted,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          // Indicateur de mise à jour en temps réel
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color:  AppColors.green,
                              shape:  BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:       AppColors.green.withValues(alpha: 0.4),
                                  blurRadius:  4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(widget.notif.titre,
                          style: TextStyle(
                              color:      context.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        context.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: context.textMuted, size: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Stats participation ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        context.bgColor,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: context.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(
                    label: 'Votants',
                    value: '$_nbVotants / $_nbDestinataires',
                  ),
                  Container(width: 1, height: 28, color: context.borderColor),
                  _StatChip(
                    label: 'Participation',
                    value: '$_tauxParticipation%',
                    highlight: true,
                  ),
                  if (_derniereMaj != null) ...[
                    Container(width: 1, height: 28, color: context.borderColor),
                    _StatChip(
                      label: 'Mis à jour',
                      value: 'il y a ${DateTime.now().difference(_derniereMaj!).inSeconds}s',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: context.borderColor),
            const SizedBox(height: 8),

            // ── Questions & résultats ─────────────────────────────
            if (_loading && _questions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_error != null && _questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    style: TextStyle(color: context.textMuted, fontSize: 13)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _questions.asMap().entries.map((entry) {
                      final qIndex = entry.key;
                      final q      = entry.value;
                      final totalQ = q.choix.fold(0, (s, c) => s + c.votes);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:        context.bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border:       Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${qIndex + 1}. ${q.texte}',
                                style: TextStyle(
                                    color:      context.textPrimary,
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    height:     1.4)),
                            const SizedBox(height: 10),
                            ...q.choix.map((c) {
                              final ratio = totalQ == 0
                                  ? 0.0
                                  : c.votes / totalQ;
                              final pct = c.pourcentage > 0
                                  ? c.pourcentage
                                  : (ratio * 100).toInt();
                              final isLeading = totalQ > 0 &&
                                  c.votes ==
                                      q.choix
                                          .map((x) => x.votes)
                                          .reduce((a, b) => a > b ? a : b);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLeading
                                      ? context.textPrimary
                                      .withValues(alpha: 0.04)
                                      : context.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isLeading
                                        ? context.textPrimary
                                        .withValues(alpha: 0.3)
                                        : context.borderColor,
                                    width: isLeading ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isLeading)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: Icon(
                                              Icons.emoji_events_rounded,
                                              color: context.textPrimary,
                                              size: 14,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(c.texte,
                                              style: TextStyle(
                                                  color: context.textPrimary,
                                                  fontWeight: isLeading
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                  fontSize: 13)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${c.votes} vote${c.votes > 1 ? 's' : ''}',
                                            style: TextStyle(
                                                color:    context.textMuted,
                                                fontSize: 11)),
                                        const SizedBox(width: 8),
                                        Text('$pct%',
                                            style: TextStyle(
                                                color:      context.textPrimary,
                                                fontSize:   13,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: ratio),
                                        duration: const Duration(
                                            milliseconds: 600),
                                        curve: Curves.easeOut,
                                        builder: (_, val, __) =>
                                            LinearProgressIndicator(
                                              value:           val,
                                              minHeight:       6,
                                              color:           context.textPrimary
                                                  .withValues(
                                                  alpha: isLeading ? 0.7 : 0.25),
                                              backgroundColor: context.borderColor,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.textPrimary,
                  foregroundColor: context.bgColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Fermer',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Chip de statistique
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color:      highlight
                    ? context.textPrimary
                    : context.textSecondary,
                fontSize:   15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: context.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ══════════════════════════════════════════════════════════════════

class _MiniBadge extends StatelessWidget {
  final String label;
  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        context.borderColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color:         context.textSecondary,
              fontSize:      9,
              fontWeight:    FontWeight.w800,
              letterSpacing: 0.5)),
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
          Icon(Icons.cloud_off_rounded, size: 52, color: context.textMuted),
          const SizedBox(height: 16),
          Text('Erreur de chargement',
              style: TextStyle(color: context.textMuted)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text('Réessayer',
                style: TextStyle(color: context.textPrimary)),
          ),
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
          Icon(Icons.notifications_none_rounded,
              size: 64, color: context.borderColor),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(color: context.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}