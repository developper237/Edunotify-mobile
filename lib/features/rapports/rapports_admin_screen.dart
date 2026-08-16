import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES & PROVIDERS
// ══════════════════════════════════════════════════════════════════

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final List<dynamic> roleDistribution;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.roleDistribution,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
    totalUsers:       json['totalUsers']       ?? 0,
    activeUsers:      json['activeUsers']       ?? 0,
    roleDistribution: json['roleDistribution']  ?? [],
  );
}

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final resp = await ApiClient.get('/auth/admin-stats');
  return AdminStats.fromJson(resp);
});

class PlanInfo {
  final String plan;
  final String nomEtab;
  final int    departements;
  final int    classes;
  final int    etudiants;
  final bool   sondages;
  final bool   chatbot;
  final bool   exportPdf;
  final int?   maxEtudiants;
  final int?   maxClasses;
  final int?   maxDepartements;
  final int?   maxNotifsMois;

  const PlanInfo({
    required this.plan,
    required this.nomEtab,
    required this.departements,
    required this.classes,
    required this.etudiants,
    required this.sondages,
    required this.chatbot,
    required this.exportPdf,
    this.maxEtudiants,
    this.maxClasses,
    this.maxDepartements,
    this.maxNotifsMois,
  });

  bool get isPremium => plan == 'premium';

  factory PlanInfo.fromJson(Map<String, dynamic> j) {
    final stats   = j['stats']   as Map<String, dynamic>? ?? {};
    final limites = j['limites'] as Map<String, dynamic>?;
    return PlanInfo(
      plan:            j['plan']    as String? ?? 'free',
      nomEtab:         j['nom']     as String? ?? '',
      departements:    stats['departements'] as int? ?? 0,
      classes:         stats['classes']      as int? ?? 0,
      etudiants:       stats['etudiants']    as int? ?? 0,
      sondages:        limites == null ? true : limites['sondages']  as bool? ?? false,
      chatbot:         limites == null ? true : limites['chatbot']   as bool? ?? false,
      exportPdf:       limites == null ? true : limites['exportPdf'] as bool? ?? false,
      maxEtudiants:    limites?['maxEtudiants']    as int?,
      maxClasses:      limites?['maxClasses']      as int?,
      maxDepartements: limites?['maxDepartements'] as int?,
      maxNotifsMois:   limites?['maxNotifsMois']   as int?,
    );
  }
}

final planInfoProvider =
StateNotifierProvider<PlanInfoNotifier, AsyncValue<PlanInfo>>(
      (ref) => PlanInfoNotifier(ref),
);

class PlanInfoNotifier extends StateNotifier<AsyncValue<PlanInfo>> {
  final Ref _ref;
  PlanInfoNotifier(this._ref) : super(const AsyncLoading());

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final resp = await ApiClient.get('/auth/cascade/plan');
      state = AsyncData(PlanInfo.fromJson(resp));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN PRINCIPAL AVEC ONGLETS
// ══════════════════════════════════════════════════════════════════

class RapportsAdminScreen extends ConsumerStatefulWidget {
  const RapportsAdminScreen({super.key});

  @override
  ConsumerState<RapportsAdminScreen> createState() =>
      _RapportsAdminScreenState();
}

class _RapportsAdminScreenState extends ConsumerState<RapportsAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(planInfoProvider.notifier).charger();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user         = ref.watch(currentUserProvider);
    final primaryColor = AppColors.forRole(user?.role ?? 'admin');

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          // ── HEADER ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const SizedBox(height: 4),
                        const Text('Tableau de bord',
                            style: TextStyle(
                                color:      Colors.white,
                                fontSize:   26,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),

                  // ── ONGLETS ──────────────────────────────────────
                  TabBar(
                    controller:       _tabController,
                    indicatorColor:   Colors.white,
                    indicatorWeight:  3,
                    labelColor:       Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.bar_chart_rounded, size: 18),
                        text: 'Statistiques',
                      ),
                      Tab(
                        icon: Icon(Icons.workspace_premium_rounded, size: 18),
                        text: 'Abonnement',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENU ──────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _OngletStats(),
                _OngletPlan(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ONGLET 1 — STATISTIQUES
// ══════════════════════════════════════════════════════════════════

class _OngletStats extends ConsumerWidget {
  const _OngletStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 16),
            Text('Impossible de charger les stats',
                style: TextStyle(color: context.textMuted)),
            TextButton(
              onPressed: () => ref.refresh(adminStatsProvider),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (stats) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminStatsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Cartes stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Utilisateurs',
                    value: '${stats.totalUsers}',
                    icon:  Icons.people_alt_rounded,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    label: 'Comptes Actifs',
                    value: '${stats.activeUsers}',
                    icon:  Icons.verified_user_rounded,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Répartition des rôles',
                style: TextStyle(
                    color:      context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize:   18)),
            const SizedBox(height: 16),
            if (stats.roleDistribution.isEmpty)
              Center(
                  child: Text('Aucune donnée',
                      style: TextStyle(color: context.textMuted)))
            else
              ...stats.roleDistribution.map((r) => _RoleRow(
                role:  r['role'].toString().toUpperCase(),
                count: r['count'],
                total: stats.totalUsers,
              )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ONGLET 2 — ABONNEMENT & PLAN
// ══════════════════════════════════════════════════════════════════

class _OngletPlan extends ConsumerWidget {
  const _OngletPlan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planInfoProvider);
    final isDark    = context.isDark;

    return planAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.cyan)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textMuted),
            const SizedBox(height: 12),
            Text('Impossible de charger',
                style: TextStyle(color: context.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(planInfoProvider.notifier).charger(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (info) => CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Bannière plan actuel ──────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: info.isPremium
                      ? [const Color(0xFF92400E), const Color(0xFFB45309)]
                      : [const Color(0xFF1E3A5F), const Color(0xFF1E4D8C)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        info.isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.layers_outlined,
                        color: info.isPremium
                            ? const Color(0xFFFCD34D)
                            : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        info.isPremium ? 'Plan Premium' : 'Plan Gratuit',
                        style: TextStyle(
                          color: info.isPremium
                              ? const Color(0xFFFCD34D)
                              : Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:        Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Plan actuel',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(info.nomEtab,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  // Stats utilisation
                  Row(
                    children: [
                      _UsageStat(
                        label:   'Étudiants',
                        current: info.etudiants,
                        max:     info.maxEtudiants,
                        icon:    Icons.people_outline,
                      ),
                      const SizedBox(width: 8),
                      _UsageStat(
                        label:   'Classes',
                        current: info.classes,
                        max:     info.maxClasses,
                        icon:    Icons.class_outlined,
                      ),
                      const SizedBox(width: 8),
                      _UsageStat(
                        label:   'Depts',
                        current: info.departements,
                        max:     info.maxDepartements,
                        icon:    Icons.account_tree_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Titre section ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choisissez votre plan',
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Passez à Premium pour débloquer toutes les fonctionnalités.',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 14)),
                ],
              ),
            ),
          ),

          // ── Carte Gratuit ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _PlanCard(
                nom:         'Gratuit',
                prix:        '0 FCFA',
                periode:     'Pour toujours',
                description: 'Pour découvrir SmartCampus et ses fonctionnalités essentielles.',
                couleur:     const Color(0xFF374151),
                isActuel:    !info.isPremium,
                isRecommande: false,
                isDark:      isDark,
                features: const [
                  _Feature('50 étudiants max',            true,  false),
                  _Feature('3 classes max',                true,  false),
                  _Feature('1 département',                true,  false),
                  _Feature('Appel de présence (OTP)',      true,  false),
                  _Feature('Publication des notes',        true,  false),
                  _Feature('10 notifications / mois',     true,  false),
                  _Feature('Historique 30 jours',         true,  false),
                  _Feature('Sondages',                    false, false),
                  _Feature('SmartCampus IA',              false, false),
                  _Feature('Export PDF des rapports',     false, false),
                  _Feature('Support prioritaire',         false, false),
                ],
              ),
            ),
          ),

          // ── Carte Premium ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _PlanCard(
                nom:         'Premium',
                prix:        'Sur devis',
                periode:     'par établissement / an',
                description: 'La solution complète pour digitaliser intégralement votre gestion académique.',
                couleur:     const Color(0xFFF59E0B),
                isActuel:    info.isPremium,
                isRecommande: true,
                isDark:      isDark,
                features: const [
                  _Feature('Étudiants illimités',         true, true),
                  _Feature('Classes illimitées',          true, true),
                  _Feature('Départements illimités',      true, true),
                  _Feature('Appel de présence (OTP)',     true, true),
                  _Feature('Publication des notes',       true, true),
                  _Feature('Notifications illimitées',    true, true),
                  _Feature('Historique complet',          true, true),
                  _Feature('Sondages multi-questions',    true, true),
                  _Feature('SmartCampus IA',              true, true),
                  _Feature('Export PDF des rapports',     true, true),
                  _Feature('Support prioritaire',         true, true),
                ],
              ),
            ),
          ),

          // ── Contact upgrade ───────────────────────────────────
          if (!info.isPremium)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1F2E)
                        : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline_rounded,
                            color: AppColors.cyan, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passer à Premium',
                                style: TextStyle(
                                    color:      context.textPrimary,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Contactez votre administrateur SmartCampus pour upgrader votre établissement.',
                              style: TextStyle(
                                  color:    context.textMuted,
                                  fontSize: 12,
                                  height:   1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── FAQ ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Questions fréquentes',
                  style: TextStyle(
                      color:      context.textPrimary,
                      fontSize:   18,
                      fontWeight: FontWeight.w800)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                children: const [
                  _FaqItem(
                    question: 'Puis-je tester Premium gratuitement ?',
                    reponse:  'Oui. Contactez votre administrateur SmartCampus pour une période d\'essai Premium de 30 jours sans engagement.',
                  ),
                  _FaqItem(
                    question: 'Que se passe-t-il si je dépasse les limites du plan gratuit ?',
                    reponse:  'L\'application vous bloquera la création de nouvelles ressources et vous proposera de contacter l\'administrateur pour upgrader. Vos données existantes restent intactes.',
                  ),
                  _FaqItem(
                    question: 'Le changement de plan est-il immédiat ?',
                    reponse:  'Oui. Dès que le super-administrateur change votre plan, les nouvelles fonctionnalités sont disponibles immédiatement sans redémarrage de l\'application.',
                  ),
                  _FaqItem(
                    question: 'Nos données sont-elles sécurisées ?',
                    reponse:  'Toutes les données sont stockées dans une base PostgreSQL hébergée sur un serveur sécurisé, avec chiffrement des mots de passe (bcrypt) et authentification par JWT.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                  color:      context.textPrimary,
                  fontSize:   26,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: TextStyle(
                  color:      context.textMuted,
                  fontSize:   12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final String role;
  final int    count;
  final int    total;

  const _RoleRow({
    required this.role,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = total > 0 ? count / total : 0.0;
    final color          = AppColors.forRole(role.toLowerCase());

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(role,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                '$count (${(percent * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                    color:      color,
                    fontWeight: FontWeight.bold,
                    fontSize:   13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value:           percent,
              backgroundColor: color.withValues(alpha: 0.1),
              color:           color,
              minHeight:       10,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageStat extends StatelessWidget {
  final String   label;
  final int      current;
  final int?     max;
  final IconData icon;

  const _UsageStat({
    required this.label,
    required this.current,
    required this.max,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ratio  = max != null ? (current / max!).clamp(0.0, 1.0) : null;
    final isNear = ratio != null && ratio >= 0.8;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNear
                ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white60, size: 13),
            const SizedBox(height: 4),
            Text(
              max != null ? '$current/$max' : '$current',
              style: TextStyle(
                color:      isNear
                    ? const Color(0xFFFCD34D)
                    : Colors.white,
                fontSize:   14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
            if (ratio != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value:           ratio,
                  minHeight:       3,
                  color:           isNear
                      ? const Color(0xFFFCD34D)
                      : AppColors.cyan,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final String label;
  final bool   inclus;
  final bool   isPremium;
  const _Feature(this.label, this.inclus, this.isPremium);
}

class _PlanCard extends StatelessWidget {
  final String nom, prix, periode, description;
  final Color  couleur;
  final bool   isActuel, isRecommande, isDark;
  final List<_Feature> features;

  const _PlanCard({
    required this.nom,
    required this.prix,
    required this.periode,
    required this.description,
    required this.couleur,
    required this.isActuel,
    required this.isRecommande,
    required this.isDark,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF1C1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActuel
              ? couleur
              : isRecommande
              ? couleur.withValues(alpha: 0.4)
              : context.borderColor,
          width: isActuel ? 2 : 1,
        ),
        boxShadow: isRecommande
            ? [
          BoxShadow(
            color:      couleur.withValues(
                alpha: isDark ? 0.15 : 0.12),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRecommande
                  ? couleur.withValues(alpha: isDark ? 0.15 : 0.06)
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(nom.toUpperCase(),
                          style: TextStyle(
                              color:         couleur,
                              fontSize:      11,
                              fontWeight:    FontWeight.w800,
                              letterSpacing: 1.5)),
                    ),
                    if (isActuel) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Plan actuel',
                            style: TextStyle(
                                color:      AppColors.green,
                                fontSize:   10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (isRecommande && !isActuel) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: couleur, size: 11),
                            const SizedBox(width: 3),
                            Text('Recommandé',
                                style: TextStyle(
                                    color:      couleur,
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(prix,
                        style: TextStyle(
                            color:         context.textPrimary,
                            fontSize:      26,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(periode,
                          style: TextStyle(
                              color:    context.textMuted,
                              fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                        color:    context.textMuted,
                        fontSize: 12,
                        height:   1.5)),
              ],
            ),
          ),

          Divider(color: context.borderColor, height: 1),

          // Features
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: f.inclus
                            ? (f.isPremium
                            ? couleur.withValues(alpha: 0.15)
                            : AppColors.green.withValues(alpha: 0.1))
                            : context.borderColor.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        f.inclus
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size:  11,
                        color: f.inclus
                            ? (f.isPremium ? couleur : AppColors.green)
                            : context.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f.label,
                          style: TextStyle(
                              color: f.inclus
                                  ? context.textPrimary
                                  : context.textMuted,
                              fontSize:   13,
                              fontWeight: f.inclus && f.isPremium
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                    if (f.isPremium && f.inclus)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Premium',
                            style: TextStyle(
                                color:      couleur,
                                fontSize:   9,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question, reponse;
  const _FaqItem({required this.question, required this.reponse});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: context.borderColor),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _ouvert = !_ouvert),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.question,
                          style: TextStyle(
                              color:      context.textPrimary,
                              fontSize:   14,
                              fontWeight: FontWeight.w600)),
                    ),
                    AnimatedRotation(
                      turns:    _ouvert ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: context.textMuted, size: 20),
                    ),
                  ],
                ),
                if (_ouvert) ...[
                  const SizedBox(height: 10),
                  Text(widget.reponse,
                      style: TextStyle(
                          color:    context.textMuted,
                          fontSize: 13,
                          height:   1.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}