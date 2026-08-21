import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';

import '../notifications/notifications_screen.dart';
import '../notifications/nouvelle_notification_screen.dart';
import '../presence/presence_screen.dart';
import '../presence/presence_archive.dart';
import '../profile/profile_screen.dart';
import '../notes/notes_screen.dart';
import '../etablissements/etablissements_screen.dart';
import '../utilisateurs/utilisateurs_screen.dart' show UtilisateursScreen;
import '../statistiques/statistiques_screen.dart';
import '../rapports/rapports_admin_screen.dart';
import '../classes/classe_delegue_screen.dart';
import '../departements/departements_screen.dart';
import '../classes/classes_chef_screen.dart';
import '../rapports/rapport_chef_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../billing/subscription_screen.dart';
import '../leads/leads_admin_screen.dart';
import '../library/library_screen.dart';
import '../exam/exam_screen.dart';
import '../chat_group/chat_group_screen.dart';

// ══════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════

final navIndexProvider = StateProvider<int>((_) => 0);

final nonLuesCountProvider =
    StateNotifierProvider<NonLuesNotifier, int>((_) => NonLuesNotifier());

class NonLuesNotifier extends StateNotifier<int> {
  NonLuesNotifier() : super(0);

  Future<void> charger(String userId, String role,
      {String? etablissementId,
      String? departementId,
      String? classeId}) async {
    try {
      final resp = await ApiClient.getNotif('/notifications/non-lues',
          userId: userId,
          role: role,
          etablissementId: etablissementId,
          departementId: departementId,
          classeId: classeId);
      state = resp['count'] as int? ?? 0;
    } catch (_) {}
  }

  void reset() => state = 0;
}

final sessionActiveProvider =
    StateNotifierProvider<SessionActiveNotifier, bool>(
        (_) => SessionActiveNotifier());

class SessionActiveNotifier extends StateNotifier<bool> {
  SessionActiveNotifier() : super(false);

  Future<void> verifier(String userId, String role, String? classeId) async {
    if (classeId == null || classeId.isEmpty) return;
    try {
      final path = (role == 'etudiant')
          ? '/presence/session-active'
          : '/presence/sessions/active';
      final resp = await ApiClient.getPresence(path,
          userId: userId, role: role, classeId: classeId);
      state = resp['session'] != null;
    } catch (_) {
      state = false;
    }
  }
}

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 900;

// ══════════════════════════════════════════════════════════════════
// HOME SCREEN
// ══════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerBadges());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _chargerBadges();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _chargerBadges() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(nonLuesCountProvider.notifier).charger(user.id, user.role,
        etablissementId: user.etablissementId,
        departementId: user.departementId,
        classeId: user.classeId);
    if (user.role == 'etudiant' || user.role == 'delegue') {
      ref
          .read(sessionActiveProvider.notifier)
          .verifier(user.id, user.role, user.classeId);
    }
  }

  void _onNavTap(int i, List<_NavItem> config) {
    final label = config[i].label;
    final user = ref.read(currentUserProvider);

    ref.read(navIndexProvider.notifier).state = i;

    // 1. Refresh de la Présence / Appel
    if (label == 'Présence' || label == 'Appel') {
      ref.invalidate(sessionActiveProvider);
      if (user != null) {
        ref
            .read(historiqueEtudiantProvider.notifier)
            .charger(user.id, user.role, classeId: user.classeId);
      }
      _chargerBadges();
    }

    // 2. NOUVEAU : Refresh des Notes
    if (label == 'Notes') {
      if (user != null) {
        // Recharge les publications (résultats)
        ref.read(mesPublicationsProvider.notifier).charger(user.id, user.role);
        // Recharge les requêtes de notes
        ref.read(mesRequetesProvider.notifier).charger(user.id, user.role);
        // Réinitialise le badge de notification des notes s'il y en avait un
        ref.read(notesBadgeProvider.notifier).marquerConsulte();
      }
    }
  }

  // ── NAVBAR ALLÉGÉE : écrans stratégiques uniquement (max 4) ──
  // Les écrans secondaires vivent dans l'accès rapide de l'accueil.
  // Les notifications sont accessibles via la cloche en haut à droite.
  List<_NavItem> _navConfig(String role, int nonLues, bool hasSession) {
    switch (role) {
      case 'etudiant':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.how_to_reg_rounded, 'Présence', const PresenceScreen(),
              badge: hasSession ? 1 : 0, badgeColor: const Color(0xFF22C55E)),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'delegue':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.play_circle_filled, 'Appel', const PresenceScreen(),
              badge: hasSession ? 1 : 0, badgeColor: const Color(0xFF22C55E)),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'chef_departement':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.description_rounded, 'Rapports',
              const RapportsChefScreen()),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'professeur':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'admin':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(
              Icons.people_rounded, 'Utilisateurs', const UtilisateursScreen()),
          _NavItem(
              Icons.bar_chart_rounded, 'Rapports', const RapportsAdminScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'super_admin':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.school_rounded, 'Établissements',
              const EtablissementsScreen()),
          _NavItem(Icons.insights_rounded, 'Stats', const StatistiquesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      default:
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final role = user?.role ?? 'etudiant';
    final index = ref.watch(navIndexProvider);
    final nonLues = ref.watch(nonLuesCountProvider);
    final hasSession = ref.watch(sessionActiveProvider);
    final config = _navConfig(role, nonLues, hasSession);
    final safeIndex = index.clamp(0, config.length - 1).toInt();
    final desktopMode = isDesktop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: Row(
          children: [
            if (desktopMode)
              _SideNav(
                config: config,
                index: safeIndex,
                onTap: (i) => _onNavTap(i, config),
              ),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: config.map((c) => c.screen).toList(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: desktopMode
            ? null
            : _BottomNav(
                config: config,
                index: safeIndex,
                onTap: (i) => _onNavTap(i, config),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// DASHBOARD TAB
// ══════════════════════════════════════════════════════════════════

class _DashboardTab extends ConsumerWidget {
  final String role;
  const _DashboardTab({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    void goTo(int i) => ref.read(navIndexProvider.notifier).state = i;

    final desktop = isDesktop(context);
    final maxContentWidth = desktop ? 760.0 : double.infinity;
    final horizontalPad = desktop ? 32.0 : 20.0;

    final accent = _roleAccent(role);
    final nonLues = ref.watch(nonLuesCountProvider);

    // Hauteur réservée pour la barre de statut (heure, réseau, batterie)
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      // ── Le dégradé remonte derrière la barre de statut (plus de blanc) ──
      extendBodyBehindAppBar: true,
      // ── AppBar avec la cloche de notifications (top-right) ──
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              context.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              context.isDark ? Brightness.dark : Brightness.light,
        ),
        title: Text(
          'SmartCampus',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    ref.read(nonLuesCountProvider.notifier).reset();
                    ref.read(notifsProvider.notifier).charger();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  },
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: context.textSecondary,
                    size: 26,
                  ),
                  tooltip: 'Notifications',
                ),
                if (nonLues > 0)
                  Positioned(
                    right: 2,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: context.cardColor, width: 1.5),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 17, minHeight: 17),
                      child: Text(
                        nonLues > 99 ? '99+' : '$nonLues',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
        ),
        heroTag: 'chatbot_fab',
        icon: const Icon(Icons.smart_toy_outlined, size: 19),
        label: const Text('Assistant'),
        elevation: 0,
        backgroundColor:
            context.isDark ? const Color(0xFF1E2235) : Colors.white,
        foregroundColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16162A)]
                : [const Color(0xFFE7F3FF), const Color(0xFFF5F0FF)],
          ),
        ),
        child: Stack(
          children: [
            // ── Fond ambiant : cercles flous animés ────────────
            Positioned.fill(
              child: AmbientBackground(
                primary: accent,
                secondary: context.isDark ? AppColors.violet : AppColors.cyan,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Marge de sécurité : barre de statut (heure, réseau) +
                    // hauteur de l'AppBar transparente au-dessus
                    SliverToBoxAdapter(
                      child: SizedBox(height: topSafe + kToolbarHeight + 12),
                    ),

                    SliverToBoxAdapter(
                      child: _WelcomeBanner(role: role, user: user),
                    ),

                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPad, 24, horizontalPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _StatsStrip(role: role, accent: accent),
                      ),
                    ),

                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPad, 28, horizontalPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel('Accès rapide'),
                            const SizedBox(height: 14),
                            _QuickActions(role: role, goTo: goTo),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPad, 32, horizontalPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: _TipCard(role: role),
                      ),
                    ),

                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPad, 32, horizontalPad, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel('Activité'),
                            const SizedBox(height: 14),
                            _ActivityFeed(role: role),
                          ],
                        ),
                      ),
                    ),

                    if (role == 'delegue' ||
                        role == 'chef_departement' ||
                        role == 'admin' ||
                        role == 'super_admin')
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPad, 24, horizontalPad, 0),
                        sliver: const SliverToBoxAdapter(
                          child: _NotifyButton(),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STATS DU TABLEAU DE BORD (compteurs animés par rôle)
// ══════════════════════════════════════════════════════════════════

Color _roleAccent(String role) {
  switch (role) {
    case 'etudiant':
      return AppColors.blue;
    case 'delegue':
      return AppColors.orange;
    case 'chef_departement':
      return AppColors.green;
    case 'professeur':
      return AppColors.red;
    case 'admin':
      return AppColors.violet;
    case 'super_admin':
      return const Color(0xFFEC4899);
    default:
      return AppColors.cyan;
  }
}

class _StatsStrip extends ConsumerWidget {
  final String role;
  final Color accent;
  const _StatsStrip({required this.role, required this.accent});

  List<_StatData> _stats(BuildContext context, WidgetRef ref) {
    final nonLues = ref.watch(nonLuesCountProvider);
    final hasSession = ref.watch(sessionActiveProvider);
    final isDark = context.isDark;
    final cardBg = isDark ? const Color(0xFF131629) : Colors.white;
    final iconBg = accent.withValues(alpha: 0.12);
    final valueColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final labelColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    List<_StatData> make(
            List<({IconData icon, int value, String label})> src) =>
        src
            .map((s) => _StatData(
                  icon: s.icon,
                  value: s.value,
                  label: s.label,
                  cardBg: cardBg,
                  iconBg: iconBg,
                  accent: accent,
                  valueColor: valueColor,
                  labelColor: labelColor,
                ))
            .toList();

    switch (role) {
      case 'etudiant':
        return make([
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
          (
            icon: Icons.how_to_reg_rounded,
            value: hasSession ? 1 : 0,
            label: 'Session active'
          ),
          (icon: Icons.grade_outlined, value: 3, label: 'Nouveautés'),
        ]);
      case 'delegue':
        return make([
          (
            icon: Icons.how_to_reg_rounded,
            value: hasSession ? 1 : 0,
            label: 'Appel en cours'
          ),
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
          (icon: Icons.people_outline, value: 2, label: 'Validations'),
        ]);
      case 'chef_departement':
        return make([
          (icon: Icons.description_outlined, value: nonLues, label: 'Rapports'),
          (icon: Icons.grade_outlined, value: 2, label: 'Notes à traiter'),
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
        ]);
      case 'professeur':
        return make([
          (icon: Icons.quiz_outlined, value: 1, label: 'Examens'),
          (icon: Icons.grade_outlined, value: 2, label: 'Notes à traiter'),
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
        ]);
      case 'admin':
        return make([
          (icon: Icons.people_outline, value: nonLues, label: 'Utilisateurs'),
          (
            icon: Icons.workspace_premium_outlined,
            value: 1,
            label: 'Plan actif'
          ),
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
        ]);
      default:
        return make([
          (icon: Icons.school_outlined, value: 1, label: 'Établissements'),
          (
            icon: Icons.workspace_premium_outlined,
            value: 1,
            label: 'Plan actif'
          ),
          (
            icon: Icons.notifications_none_rounded,
            value: nonLues,
            label: 'Non lues'
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _stats(context, ref);
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = isDesktop(context);
        final columns = desktop ? 3 : 3;
        const spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Row(
          children: items
              .map((s) => Padding(
                    padding:
                        EdgeInsets.only(right: s == items.last ? 0 : spacing),
                    child: SizedBox(
                      width: tileWidth,
                      child: _StatTile(data: s),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _StatData {
  final IconData icon;
  final int value;
  final String label;
  final Color cardBg, iconBg, accent, valueColor, labelColor;
  const _StatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.cardBg,
    required this.iconBg,
    required this.accent,
    required this.valueColor,
    required this.labelColor,
  });
}

class _StatTile extends StatelessWidget {
  final _StatData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: data.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 18, color: data.accent),
          ),
          const SizedBox(height: 8),
          AnimatedCounter(
            value: data.value,
            style: TextStyle(
              color: data.valueColor,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(
              color: data.labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WELCOME BANNER
// ══════════════════════════════════════════════════════════════════

class _WelcomeBanner extends StatefulWidget {
  final String role;
  final User? user;
  const _WelcomeBanner({required this.role, required this.user});

  @override
  State<_WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<_WelcomeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 5) return 'Bonne nuit';
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String get _contextMessage {
    switch (widget.role) {
      case 'etudiant':
        return 'Consultez vos notes et confirmez votre présence en cours.';
      case 'delegue':
        return 'Lancez l\'appel de présence et gérez votre classe.';
      case 'chef_departement':
        return 'Suivez les rapports d\'appel et gérez les notes.';
      case 'professeur':
        return 'Gérez vos examens et partagez des ressources avec vos étudiants.';
      case 'admin':
        return 'Administrez les utilisateurs et les départements.';
      case 'super_admin':
        return 'Vue globale de la plateforme SmartCampus.';
      default:
        return 'Bienvenue sur SmartCampus.';
    }
  }

  String get _roleLabel {
    const map = {
      'super_admin': 'Super Admin',
      'admin': 'Administrateur',
      'chef_departement': 'Chef de département',
      'professeur': 'Professeur',
      'delegue': 'Délégué',
      'etudiant': 'Étudiant',
    };
    return map[widget.role] ?? widget.role;
  }

  Color get _accentColor {
    switch (widget.role) {
      case 'etudiant':
        return const Color(0xFF3B82F6);
      case 'delegue':
        return const Color(0xFFF97316);
      case 'chef_departement':
        return const Color(0xFF10B981);
      case 'professeur':
        return const Color(0xFFF43F5E);
      case 'admin':
        return const Color(0xFF8B5CF6);
      case 'super_admin':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  // ── Construire les chips d'info académique selon le rôle ────────
  List<_ChipData> _infoChips() {
    final user = widget.user;
    final chips = <_ChipData>[];

    if (user == null) return chips;

    // Établissement — tous les rôles
    if (user.etablissementNom != null)
      chips.add(_ChipData(Icons.school_outlined, user.etablissementNom!));

    switch (widget.role) {
      case 'etudiant':
      case 'delegue':
        // Filière + niveau ex: "Génie Logiciel · L3"
        if (user.filiere != null) {
          final label = user.niveau != null
              ? '${user.filiere!} · ${user.niveau!}'
              : user.filiere!;
          chips.add(_ChipData(Icons.category_outlined, label));
        }
        // Code classe ex: "GL_L3_FA"
        if (user.classeNom != null)
          chips.add(_ChipData(Icons.class_outlined, user.classeNom!));
        break;

      case 'chef_departement':
        // Nom du département
        if (user.departementNom != null)
          chips.add(_ChipData(Icons.domain_outlined, user.departementNom!));
        break;

      default:
        break;
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final desktop = isDesktop(context);
    final prenom = widget.user?.prenom ?? 'Bienvenue';
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';
    final chips = _infoChips();

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: Container(
          margin:
              EdgeInsets.fromLTRB(desktop ? 32 : 16, 16, desktop ? 32 : 16, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 16,
                top: 16,
                child: _GeomDecor(color: _accentColor),
              ),
              if (widget.user?.etablissementLogo != null &&
                  widget.user!.etablissementLogo!.isNotEmpty)
                Positioned(
                  right: 20,
                  top: 20,
                  child:
                      _EtablissementLogo(url: widget.user!.etablissementLogo!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne avatar + nom ──────────────────
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(initiale,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_salutation, $prenom',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Badge rôle
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _roleLabel,
                                  style: TextStyle(
                                    color: _accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Message contextuel ──────────────────
                    Text(
                      _contextMessage,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    // ── Chips académiques ───────────────────
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: chips.map((c) => _InfoChip(c)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Données d'un chip d'info ──────────────────────────────────────
class _ChipData {
  final IconData icon;
  final String label;
  const _ChipData(this.icon, this.label);
}

// ── Chip d'info académique ────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final _ChipData data;
  const _InfoChip(this.data);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(data.icon, size: 12, color: context.textMuted),
        const SizedBox(width: 4),
        Text(
          data.label,
          style: TextStyle(
            color: context.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Décoration géométrique ────────────────────────────────────────
class _GeomDecor extends StatelessWidget {
  final Color color;
  const _GeomDecor({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(painter: _CirclesPainter(color: color)));
}

class _CirclesPainter extends CustomPainter {
  final Color color;
  const _CirclesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.6, paint);
    paint.color = color.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.95, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Logo de l'établissement, affiché en haut à droite du header ──
class _EtablissementLogo extends StatelessWidget {
  final String url;
  const _EtablissementLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Icon(
          Icons.school_outlined,
          color: context.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ACCÈS RAPIDE
// ══════════════════════════════════════════════════════════════════

class _QuickActions extends StatelessWidget {
  final String role;
  final void Function(int) goTo;
  const _QuickActions({required this.role, required this.goTo});

  List<_QAction> _actions(BuildContext context) {
    // Écrans secondaires (plus dans la navbar) → ouverts en push
    void ouvrir(Widget screen) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );

    switch (role) {
      case 'etudiant':
        return [
          _QAction(Icons.how_to_reg_rounded, 'Présence', () => goTo(1)),
          _QAction(Icons.grade_rounded, 'Notes', () => goTo(2)),
          _QAction(Icons.menu_book_rounded, 'Bibliothèque',
              () => ouvrir(const LibraryScreen())),
          _QAction(Icons.quiz_rounded, 'Salle d\'examen',
              () => ouvrir(const ExamScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
          _QAction(Icons.notifications_rounded, 'Notifications',
              () => ouvrir(const NotificationsScreen())),
          _QAction(Icons.person_rounded, 'Profil', () => goTo(3)),
        ];
      case 'delegue':
        return [
          _QAction(Icons.play_circle_filled, 'Lancer appel', () => goTo(1)),
          _QAction(Icons.history_rounded, 'Historique',
              () => ouvrir(const HistoriqueScreen())),
          _QAction(Icons.people_rounded, 'Ma classe',
              () => ouvrir(const ClasseDelegueScreen())),
          _QAction(Icons.grade_rounded, 'Notes', () => goTo(2)),
          _QAction(Icons.menu_book_rounded, 'Bibliothèque',
              () => ouvrir(const LibraryScreen())),
          _QAction(Icons.quiz_rounded, 'Salle d\'examen',
              () => ouvrir(const ExamScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
        ];
      case 'chef_departement':
        return [
          _QAction(Icons.description_rounded, 'Rapports', () => goTo(1)),
          _QAction(Icons.grade_rounded, 'Notes', () => goTo(2)),
          _QAction(Icons.class_rounded, 'Classes',
              () => ouvrir(const ClassesChefScreen())),
          _QAction(Icons.menu_book_rounded, 'Bibliothèque',
              () => ouvrir(const LibraryScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
          _QAction(Icons.notifications_rounded, 'Notifications',
              () => ouvrir(const NotificationsScreen())),
        ];
      case 'professeur':
        return [
          _QAction(Icons.grade_rounded, 'Notes', () => goTo(1)),
          _QAction(Icons.quiz_rounded, 'Salle d\'examen',
              () => ouvrir(const ExamScreen())),
          _QAction(Icons.menu_book_rounded, 'Bibliothèque',
              () => ouvrir(const LibraryScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
          _QAction(Icons.notifications_rounded, 'Notifications',
              () => ouvrir(const NotificationsScreen())),
        ];
      case 'admin':
        return [
          _QAction(Icons.people_rounded, 'Utilisateurs', () => goTo(1)),
          _QAction(Icons.bar_chart_rounded, 'Rapports', () => goTo(2)),
          _QAction(Icons.category_rounded, 'Départements',
              () => ouvrir(const DepartementsScreen())),
          _QAction(Icons.menu_book_rounded, 'Bibliothèque',
              () => ouvrir(const LibraryScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
          _QAction(Icons.notifications_rounded, 'Notifications',
              () => ouvrir(const NotificationsScreen())),
          _QAction(Icons.workspace_premium_rounded, 'Abonnement',
              () => ouvrir(const SubscriptionScreen())),
        ];
      case 'super_admin':
        return [
          _QAction(Icons.school_rounded, 'Établissements', () => goTo(1)),
          _QAction(Icons.insights_rounded, 'Stats', () => goTo(2)),
          _QAction(Icons.mark_email_unread_rounded, 'Demandes',
              () => ouvrir(const LeadsAdminScreen())),
          _QAction(Icons.notifications_rounded, 'Notifications',
              () => ouvrir(const NotificationsScreen())),
          _QAction(Icons.chat_bubble_rounded, 'Messages',
              () => ouvrir(const ChatGroupScreen())),
          _QAction(Icons.person_rounded, 'Profil', () => goTo(3)),
          _QAction(Icons.workspace_premium_rounded, 'Abonnement',
              () => ouvrir(const SubscriptionScreen())),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = isDesktop(context);
        final columns = desktop ? actions.length.clamp(1, 4) : 2;
        const spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((a) => SizedBox(
                    width: tileWidth,
                    child: _QActionTile(action: a),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _QAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QAction(this.icon, this.label, this.onTap);
}

class _QActionTile extends StatefulWidget {
  final _QAction action;
  const _QActionTile({required this.action});

  @override
  State<_QActionTile> createState() => _QActionTileState();
}

class _QActionTileState extends State<_QActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.action.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131629) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(widget.action.icon, size: 22, color: context.textSecondary),
              const SizedBox(height: 8),
              Text(
                widget.action.label,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CONSEIL DU JOUR
// ══════════════════════════════════════════════════════════════════

class _TipCard extends StatefulWidget {
  final String role;
  const _TipCard({required this.role});

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _tipIndex = 0;
  Timer? _autoTimer;

  static const _tips = {
    'etudiant': [
      {
        'text':
            'Consultez toujours vos notes dès qu\'elles sont publiées pour détecter toute erreur à temps. Les requêtes sont généralement attendues sous 48 heures maximum.',
        'image': 'lib/assets/tips/notes_consult.webp',
      },
      {
        'text':
            'Confirmez votre présence dès l\'ouverture de la session par votre délégué car le code de validation peut expirer rapidement.',
        'image': 'lib/assets/tips/appel.jpg',
      },
      {
        'text':
            'Soumettez une requête si une note vous semble incorrecte. Décrivez clairement l\'objet de votre requête afin de faciliter son traitement.',
        'image': 'lib/assets/tips/requete.webp',
      },
      {
        'text':
            'Ne répondez jamais à l\'appel pour votre camarade absent ! Toute tentative de fraude est monitorée et bloquée. Si votre camarade n\'a pas de téléphone, orientez-le vers le délégué.',
        'image': 'lib/assets/tips/fraud.webp',
      },
    ],
    'delegue': [
      {
        'text':
            'Activez la géolocalisation en salle pour éviter les fraudes à distance. Un étudiant hors de la zone définie ne pourra pas répondre à l\'appel.',
        'image': 'lib/assets/tips/geo.webp',
      },
      {
        'text':
            'Envoyez toujours le rapport au chef juste après avoir fermé la session pour lui donner une vue d\'ensemble sur les présents et absents.',
        'image': 'lib/assets/tips/report.webp',
      },
      {
        'text':
            'La validation manuelle est réservée aux étudiants sans smartphone. Assurez-vous d\'avoir l\'approbation du professeur avant de valider.',
        'image': 'lib/assets/tips/delotp.webp',
      },
    ],
    'chef_departement': [
      {
        'text':
            'Publiez les notes par session (CC, examen) pour une meilleure lisibilité pour les étudiants.',
        'image': 'lib/assets/tips/1.webp',
      },
      {
        'text':
            'Répondez aux requêtes dans les 48h pour éviter les recours auprès de l\'administration.',
        'image': 'lib/assets/tips/req.jpeg',
      },
      {
        'text':
            'Consultez les rapports d\'appel quotidiennement pour détecter l\'absentéisme dans votre département.',
        'image': 'lib/assets/tips/monitoring.jpg',
      },
    ],
  };

  List<Map<String, String>> get _roleTips =>
      List<Map<String, String>>.from(_tips[widget.role] ?? []);

  @override
  void initState() {
    super.initState();
    if (_roleTips.isNotEmpty) {
      _tipIndex = math.Random().nextInt(_roleTips.length);
    }
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _ctrl.forward();
    _autoTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _next();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_roleTips.isEmpty) return;
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _roleTips.length);
      _ctrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_roleTips.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDark;
    final currentTip = _roleTips[_tipIndex];
    final desktop = isDesktop(context);
    final imageHeight = desktop ? 320.0 : 240.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131629) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _TipTextBlock(
                    currentTip: currentTip,
                    ctrl: _ctrl,
                    tipIndex: _tipIndex,
                    total: _roleTips.length,
                    onNext: _next,
                    showImage: false,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FadeTransition(
                      opacity: _ctrl,
                      child: Image.asset(
                        currentTip['image']!,
                        height: imageHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => Container(
                          height: imageHeight,
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _TipTextBlock(
              currentTip: currentTip,
              ctrl: _ctrl,
              tipIndex: _tipIndex,
              total: _roleTips.length,
              onNext: _next,
              showImage: true,
              imageHeight: imageHeight,
            ),
    );
  }
}

class _TipTextBlock extends StatelessWidget {
  final Map<String, String> currentTip;
  final AnimationController ctrl;
  final int tipIndex;
  final int total;
  final VoidCallback onNext;
  final bool showImage;
  final double imageHeight;

  const _TipTextBlock({
    required this.currentTip,
    required this.ctrl,
    required this.tipIndex,
    required this.total,
    required this.onNext,
    required this.showImage,
    this.imageHeight = 240,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final tipFontSize = desktop ? 15.0 : 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: Color(0xFFD97706)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le saviez-vous ?',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: desktop ? 12 : 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: ctrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTip['text']!,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: tipFontSize,
                        height: 1.5,
                      ),
                    ),
                    if (showImage) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          currentTip['image']!,
                          height: imageHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(
                            height: imageHeight,
                            color: Colors.grey.withValues(alpha: 0.1),
                            child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  // Indicateurs de page
                  Row(
                    children: List.generate(total, (i) {
                      final active = i == tipIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 4),
                        width: active ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFD97706)
                              : const Color(0xFFD97706).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onNext,
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: context.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ACTIVITÉ RÉCENTE
// ══════════════════════════════════════════════════════════════════

class _ActivityFeed extends ConsumerStatefulWidget {
  final String role;
  const _ActivityFeed({required this.role});

  @override
  ConsumerState<_ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends ConsumerState<_ActivityFeed>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    // Charge les vraies notifications (activité récente) depuis le backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      ref.read(notifsProvider.notifier).charger();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _ctrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Icône selon la catégorie de la notification ───────────────
  IconData _iconFor(String categorie, {required bool estSondage}) {
    if (estSondage) return Icons.poll_outlined;
    switch (categorie) {
      case 'examen':
        return Icons.assignment_outlined;
      case 'resultat':
        return Icons.grade_outlined;
      case 'cours':
        return Icons.school_outlined;
      case 'urgent':
        return Icons.flag_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  // ── Temps relatif lisible ("5 min", "2 h", "Hier") ───────────
  String _tempsRelatif(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notifsProvider);

    return notifsAsync.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
              width: double.infinity,
              height: 58,
              radius: 14,
              margin: EdgeInsets.only(bottom: 10)),
          SkeletonBox(
              width: double.infinity,
              height: 58,
              radius: 14,
              margin: EdgeInsets.only(bottom: 10)),
          SkeletonBox(width: double.infinity, height: 58, radius: 14),
        ],
      ),
      error: (_, __) =>
          _ActivityVide(message: 'Impossible de charger l\'activité'),
      data: (notifs) {
        // Les 5 dernières notifications = activité récente
        final recentes = notifs.take(5).toList();
        if (recentes.isEmpty) {
          return _ActivityVide(
              message: 'Aucune activité récente pour le moment');
        }

        return Column(
          children: List.generate(recentes.length, (i) {
            final n = recentes[i];
            final item = _ActivityItem(
              _iconFor(n.categorie, estSondage: n.estSondage),
              n.titre,
              n.contenu.startsWith('PDF:') ? "Rapport d'appel reçu" : n.contenu,
              _tempsRelatif(n.envoyeLe),
              n.lue,
            );

            final delay = i * 0.12;
            final begin = delay.clamp(0.0, 1.0);
            final end = (delay + 0.4).clamp(0.0, 1.0);
            final fade = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                  parent: _ctrl,
                  curve: Interval(begin, end, curve: Curves.easeOut)),
            );
            final slide =
                Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: _ctrl,
                        curve: Interval(begin, end, curve: Curves.easeOut)));

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child:
                    _ActivityTile(item: item, isLast: i == recentes.length - 1),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ActivityVide extends StatelessWidget {
  final String message;
  const _ActivityVide({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 20, color: context.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String titre, sousTitre, temps;
  final bool lue;
  const _ActivityItem(
      this.icon, this.titre, this.sousTitre, this.temps, this.lue);
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  final bool isLast;
  const _ActivityTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2E)
                      : const Color(0xFFF4F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 16, color: context.textSecondary),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 28,
                  color: isDark
                      ? const Color(0xFF2A2A2E)
                      : const Color(0xFFEAEAEA),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.titre,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: item.lue
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!item.lue) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.sousTitre,
                          style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.temps,
                      style: TextStyle(color: context.textMuted, fontSize: 11)),
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
// BOUTON NOTIFIER
// ══════════════════════════════════════════════════════════════════

class _NotifyButton extends StatelessWidget {
  const _NotifyButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen()),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text(
          'Envoyer une notification',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// COMPOSANTS COMMUNS
// ══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// NAVIGATION
// ══════════════════════════════════════════════════════════════════

class _NavItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final int badge;
  final Color badgeColor;
  const _NavItem(this.icon, this.label, this.screen,
      {this.badge = 0, this.badgeColor = const Color(0xFFEF4444)});
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final Color badgeColor;
  final bool selected;
  final Color color;

  const _BadgeIcon({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget =
        Icon(icon, size: 22, color: selected ? color : context.textMuted);
    if (badge == 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.cardColor, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<_NavItem> config;
  final int index;
  final void Function(int) onTap;

  const _BottomNav(
      {required this.config, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activeColor = context.isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(config.length, (i) {
              final item = config[i];
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BadgeIcon(
                        icon: item.icon,
                        badge: item.badge,
                        badgeColor: item.badgeColor,
                        selected: selected,
                        color: activeColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: selected ? activeColor : context.textMuted,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final List<_NavItem> config;
  final int index;
  final void Function(int) onTap;

  const _SideNav({
    required this.config,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isExtended = MediaQuery.of(context).size.width >= 1200;

    // Couleur principale (Indigo) adaptée au mode sombre
    final activeColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);

    return NavigationRail(
      backgroundColor: context.cardColor,
      elevation: 1,
      extended: isExtended,
      selectedIndex: index,
      onDestinationSelected: onTap,

      // 1. Indicateur de sélection (le fond derrière l'icône)
      indicatorColor: activeColor.withValues(alpha: 0.1),

      // 2. Thème des icônes
      selectedIconTheme: IconThemeData(color: activeColor),
      unselectedIconTheme: IconThemeData(color: context.textMuted),

      // 3. Thème du texte
      selectedLabelTextStyle: TextStyle(
          color: activeColor, fontWeight: FontWeight.bold, fontSize: 14),
      unselectedLabelTextStyle:
          TextStyle(color: context.textMuted, fontSize: 13),

      // 4. LE LOGO (LEADING)
      leading: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: isExtended ? 20 : 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'lib/assets/logos/adapter.png', // Retrait du 'lib/' si c'est un asset standard
                // On ajuste la taille selon si la barre est ouverte ou fermée
                width: isExtended ? 180 : 42,
                height: isExtended ? 100 : 42,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.school_rounded, color: activeColor, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),

      // 5. LES DESTINATIONS (ICONES)
      destinations: config.map((item) {
        return NavigationRailDestination(
          icon: _BadgeIcon(
            icon: item.icon,
            badge: item.badge,
            badgeColor: item.badgeColor,
            selected: false,
            color: activeColor, // Utilise la couleur dynamique
          ),
          selectedIcon: _BadgeIcon(
            icon: item.icon,
            badge: item.badge,
            badgeColor: item.badgeColor,
            selected: true,
            color: activeColor, // Utilise la couleur dynamique
          ),
          label: Text(item.label),
        );
      }).toList(),
    );
  }
}
