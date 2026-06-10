import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';

// Imports des fonctionnalités
import '../notifications/notifications_screen.dart';
import '../notifications/nouvelle_notification_screen.dart';
import '../presence/presence_screen.dart';
import '../presence/presence_archive.dart';
import '../profile/profile_screen.dart';
import '../classes/classes_screen.dart';
import '../notes/notes_screen.dart';
import '../etablissements/etablissements_screen.dart';
import '../utilisateurs/utilisateurs_screen.dart' show UtilisateursScreen;
import '../statistiques/statistiques_screen.dart';
import '../rapports/rapports_admin_screen.dart';
import '../classes/classe_delegue_screen.dart';
import '../departements/departements_screen.dart';
import '../classes/classes_chef_screen.dart';
import '../rapports/rapport_chef_screen.dart';
import '../rapports/rapports_admin_screen.dart';

// ── Providers ────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((_) => 0);

final nonLuesCountProvider = StateNotifierProvider<NonLuesNotifier, int>(
      (_) => NonLuesNotifier(),
);

class NonLuesNotifier extends StateNotifier<int> {
  NonLuesNotifier() : super(0);

  Future<void> charger(String userId, String role, {
    String? etablissementId, String? departementId, String? classeId,
  }) async {
    try {
      final resp = await ApiClient.getNotif(
        '/notifications/non-lues',
        userId: userId, role: role,
        etablissementId: etablissementId,
        departementId:   departementId,
        classeId:        classeId,
      );
      state = resp['count'] as int? ?? 0;
    } catch (_) {}
  }

  void reset() => state = 0;
}

final sessionActiveProvider = StateNotifierProvider<SessionActiveNotifier, bool>(
        (_) => SessionActiveNotifier());

class SessionActiveNotifier extends StateNotifier<bool> {
  SessionActiveNotifier() : super(false);

  Future<void> verifier(String userId, String role, String? classeId) async {
    if (classeId == null || classeId.isEmpty) return;
    try {
      final path = (role == 'etudiant') ? '/presence/session-active' : '/presence/sessions/active';
      final resp = await ApiClient.getPresence(path,
          userId: userId, role: role, classeId: classeId);
      state = resp['session'] != null;
    } catch (_) {
      state = false;
    }
  }
}

// ── Utils Responsive ──────────────────────────────────────────
bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 900;

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
    // On rafraîchit les badges toutes les 20 secondes (plus réactif)
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
    ref.read(nonLuesCountProvider.notifier).charger(
      user.id, user.role,
      etablissementId: user.etablissementId,
      departementId:   user.departementId,
      classeId:        user.classeId,
    );
    if (user.role == 'etudiant' || user.role == 'delegue') {
      ref.read(sessionActiveProvider.notifier).verifier(user.id, user.role, user.classeId);
    }
  }

  void _onNavTap(int i, List<_NavItem> config) {
    final label = config[i].label;

    // Mettre à jour l'index
    ref.read(navIndexProvider.notifier).state = i;

    // 1. Si clic sur Notifications, reset le badge
    if (label == 'Notifs') {
      ref.read(nonLuesCountProvider.notifier).reset();
    }

    // 2. CORRECTION : Si clic sur Présence ou Appel, on force le refresh
    if (label == 'Présence' || label == 'Appel') {
      // On invalide les providers pour forcer la reconstruction de PresenceScreen avec de nouvelles données
      // Remplace ces noms par tes vrais providers de présence s'ils diffèrent
      ref.invalidate(sessionActiveProvider);
      // Si tu as des providers spécifiques dans presence_screen :
      // ref.invalidate(sessionStatusProvider);
      // ref.invalidate(sessionDataProvider);

      // On relance aussi la vérification de session immédiatement
      _chargerBadges();
    }
  }

  List<_NavItem> _navConfig(String role, int nonLues, bool hasSession) {
    switch (role) {
      case 'etudiant':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.notifications_rounded, 'Notifs', const NotificationsScreen(), badge: nonLues),
          _NavItem(Icons.how_to_reg_rounded, 'Présence', const PresenceScreen(),
              badge: hasSession ? 1 : 0, badgeColor: AppColors.green),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'delegue':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.notifications_rounded, 'Notifs', const NotificationsScreen(), badge: nonLues),
          _NavItem(Icons.play_circle_filled, 'Appel', const PresenceScreen(),
              badge: hasSession ? 1 : 0, badgeColor: AppColors.green),
          _NavItem(Icons.history_rounded, 'Historique', const HistoriqueScreen()),
          _NavItem(Icons.grade_rounded, 'Notes', const NotesScreen()),
          _NavItem(Icons.people_rounded, 'Classe', const ClasseDelegueScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'chef_departement':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.notifications_rounded, 'Notifs', const NotificationsScreen(), badge: nonLues),
          _NavItem(Icons.description_rounded, 'Rapports', const RapportsChefScreen()),
          _NavItem(Icons.class_rounded, 'Classes', const ClassesChefScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'admin':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.notifications_rounded, 'Notifs', const NotificationsScreen(), badge: nonLues),
          _NavItem(Icons.people_rounded, 'Utilisateurs', const UtilisateursScreen()),
          _NavItem(Icons.category_rounded, 'Départements', const DepartementsScreen()),
          _NavItem(Icons.bar_chart_rounded, 'Rapports', const RapportsAdminScreen()),
          _NavItem(Icons.person_rounded, 'Profil', const ProfileScreen()),
        ];
      case 'super_admin':
        return [
          _NavItem(Icons.home_rounded, 'Accueil', _DashboardTab(role: role)),
          _NavItem(Icons.notifications_rounded, 'Notifs', const NotificationsScreen(), badge: nonLues),
          _NavItem(Icons.school_rounded, 'Établissements', const EtablissementsScreen()),
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
    final roleColor = AppColors.forRole(role);
    final desktopMode = isDesktop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: Row(
          children: [
            if (desktopMode)
              _SideNav(
                config: config,
                index: safeIndex,
                roleColor: roleColor,
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
        bottomNavigationBar: desktopMode ? null : _BottomNav(
          config: config,
          index: safeIndex,
          roleColor: roleColor,
          onTap: (i) => _onNavTap(i, config),
        ),
      ),
    );
  }
}

// ── Side Navigation (Desktop/Laptop) ──────────────────────────────
class _SideNav extends StatelessWidget {
  final List<_NavItem> config;
  final int index;
  final Color roleColor;
  final void Function(int) onTap;

  const _SideNav({required this.config, required this.index, required this.roleColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: context.cardColor,
      elevation: 1,
      extended: MediaQuery.of(context).size.width >= 1200,
      selectedIndex: index,
      onDestinationSelected: onTap,
      indicatorColor: roleColor.withValues(alpha: 0.1),
      selectedIconTheme: IconThemeData(color: roleColor),
      unselectedIconTheme: IconThemeData(color: context.textMuted),
      selectedLabelTextStyle: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
      leading: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(backgroundColor: roleColor, child: const Icon(Icons.school, color: Colors.white)),
          const SizedBox(height: 20),
        ],
      ),
      destinations: config.map((item) => NavigationRailDestination(
        icon: _BadgeIcon(icon: item.icon, badge: item.badge, badgeColor: item.badgeColor, selected: false, color: roleColor),
        selectedIcon: _BadgeIcon(icon: item.icon, badge: item.badge, badgeColor: item.badgeColor, selected: true, color: roleColor),
        label: Text(item.label),
      )).toList(),
    );
  }
}

// ── Bottom Navigation (Mobile) ───────────────────────────────────
class _BottomNav extends StatelessWidget {
  final List<_NavItem> config;
  final int index;
  final Color roleColor;
  final void Function(int) onTap;

  const _BottomNav({required this.config, required this.index, required this.roleColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        // CORRECTION : Utilisation de Theme.of(context).dividerColor
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
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
                      _BadgeIcon(icon: item.icon, badge: item.badge, badgeColor: item.badgeColor, selected: selected, color: roleColor),
                      const SizedBox(height: 3),
                      Text(item.label, style: TextStyle(fontSize: 9.5, color: selected ? roleColor : context.textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
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

// ── Widgets internes inchangés (Badge, NavItem, Dashboard, etc.) ──
class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final Color badgeColor;
  final bool selected;
  final Color color;

  const _BadgeIcon({required this.icon, required this.badge, required this.badgeColor, required this.selected, required this.color});

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: selected ? color : context.textMuted);
    if (badge == 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -4, top: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle, border: Border.all(color: context.cardColor, width: 1.5)),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final int badge;
  final Color badgeColor;
  const _NavItem(this.icon, this.label, this.screen, {this.badge = 0, this.badgeColor = AppColors.red});
}

// ... Garder les classes _DashboardTab, _GradientHeader, etc. telles qu'elles sont ...

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

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── Header dégradé ─────────────────────────────────
          SliverToBoxAdapter(
            child: _GradientHeader(role: role, user: user),
          ),
          // ── Contenu ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverToBoxAdapter(
              child: _buildDash(role, goTo, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDash(String role, void Function(int) goTo, BuildContext ctx) {
    switch (role) {
      case 'etudiant':         return _DashEtudiant(goTo: goTo);
      case 'delegue':          return _DashDelegue(goTo: goTo);
      case 'chef_departement': return _DashChef(goTo: goTo);
      case 'admin':            return _DashAdmin(goTo: goTo);
      case 'super_admin':      return _DashSuperAdmin(goTo: goTo);
      default:                 return _DashEtudiant(goTo: goTo);
    }
  }
}

// ── Header avec dégradé ───────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  final String role;
  final User? user;
  const _GradientHeader({required this.role, required this.user});

  List<Color> get _gradientColors {
    switch (role) {
      case 'etudiant':         return [const Color(0xFF0EA5E9), const Color(0xFF6366F1)];
      case 'delegue':          return [const Color(0xFFF97316), const Color(0xFFEC4899)];
      case 'chef_departement': return [const Color(0xFF10B981), const Color(0xFF0EA5E9)];
      case 'admin':            return [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)];
      case 'super_admin':      return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
      default:                 return [const Color(0xFF0EA5E9), const Color(0xFF6366F1)];
    }
  }

  String get _roleLabel {
    const map = {
      'super_admin':      'Super Admin',
      'admin':            'Administrateur',
      'chef_departement': 'Chef de Département',
      'delegue':          'Délégué',
      'etudiant':         'Étudiant',
    };
    return map[role] ?? role;
  }

  String _salutation() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour 👋';
    if (h < 18) return 'Bon après-midi 👋';
    return 'Bonsoir 👋';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_salutation(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(user?.prenom ?? 'Bienvenue',
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color:  Colors.white.withValues(alpha: 0.2),
                          shape:  BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                        ),
                        child: Center(
                          child: Text(user?.initiales ?? '?',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeaderBadge(icon: Icons.verified_rounded, label: _roleLabel),
                      if (user?.etablissementNom != null) ...[
                        const SizedBox(width: 8),
                        Flexible(child: _HeaderBadge(icon: Icons.school_rounded, label: user!.etablissementNom!)),
                      ],
                    ],
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

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── DASHBOARDS PAR RÔLE (Inchangés mais contenus dans le Row adaptatif du Scaffold) ──
// Les classes _DashEtudiant, _DashDelegue, _DashChef, _DashAdmin, _DashSuperAdmin,
// _SectionTitle, _ActionCard, StatCard doivent être présentes en dessous...

class _DashEtudiant extends StatelessWidget {
  final void Function(int) goTo;
  const _DashEtudiant({required this.goTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Accès rapide'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop(context) ? 4 : 2, crossAxisSpacing: 14,
          mainAxisSpacing: 14, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ActionCard(
              icon: Icons.how_to_reg_rounded, label: 'Ma présence',
              subtitle: 'Confirmer mon code',
              gradient: [const Color(0xFFF97316), const Color(0xFFFB923C)],
              onTap: () => goTo(2),
            ),
            _ActionCard(
              icon: Icons.grade_rounded, label: 'Mes notes',
              subtitle: 'Voir mon bulletin',
              gradient: [const Color(0xFF10B981), const Color(0xFF34D399)],
              onTap: () => goTo(3),
            ),
            _ActionCard(
              icon: Icons.notifications_rounded, label: 'Notifications',
              subtitle: 'Mes alertes',
              gradient: [const Color(0xFF06B6D4), const Color(0xFF38BDF8)],
              onTap: () => goTo(1),
            ),
            _ActionCard(
              icon: Icons.person_rounded, label: 'Mon profil',
              subtitle: 'Mon compte',
              gradient: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
              onTap: () => goTo(4),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashDelegue extends StatelessWidget {
  final void Function(int) goTo;
  const _DashDelegue({required this.goTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Actions'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop(context) ? 4 : 2, crossAxisSpacing: 14,
          mainAxisSpacing: 14, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ActionCard(
              icon: Icons.play_circle_filled, label: 'Lancer un appel',
              subtitle: 'Générer un code',
              gradient: [const Color(0xFFF97316), const Color(0xFFEC4899)],
              onTap: () => goTo(2),
            ),
            _ActionCard(
              icon: Icons.history_rounded, label: 'Historique',
              subtitle: 'Sessions passées',
              gradient: [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
              onTap: () => goTo(3),
            ),
            _ActionCard(
              icon: Icons.people_rounded, label: 'Ma classe',
              subtitle: 'Liste étudiants',
              gradient: [const Color(0xFF10B981), const Color(0xFF06B6D4)],
              onTap: () => goTo(5),
            ),
            _ActionCard(
              icon: Icons.send_rounded, label: 'Notifier',
              subtitle: 'Envoyer un message',
              gradient: [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen())),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashChef extends StatelessWidget {
  final void Function(int) goTo;
  const _DashChef({required this.goTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Actions'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop(context) ? 4 : 2, crossAxisSpacing: 14,
          mainAxisSpacing: 14, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ActionCard(
              icon: Icons.description_rounded, label: 'Rapports',
              subtitle: 'Gérer absences',
              gradient: [const Color(0xFFF97316), const Color(0xFFFB923C)],
              onTap: () => goTo(2),
            ),
            _ActionCard(
              icon: Icons.grade_rounded, label: 'Notes',
              subtitle: 'Gérer les notes',
              gradient: [const Color(0xFF10B981), const Color(0xFF34D399)],
              onTap: () => goTo(3),
            ),
            _ActionCard(
              icon: Icons.class_rounded, label: 'Classes',
              subtitle: 'Voir mes classes',
              gradient: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
              onTap: () => goTo(4),
            ),
            _ActionCard(
              icon: Icons.send_rounded, label: 'Notifier',
              subtitle: 'Envoyer un message',
              gradient: [const Color(0xFF06B6D4), const Color(0xFF38BDF8)],
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen())),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashAdmin extends StatelessWidget {
  final void Function(int) goTo;
  const _DashAdmin({required this.goTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Actions rapides'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop(context) ? 4 : 2, crossAxisSpacing: 14,
          mainAxisSpacing: 14, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ActionCard(
              icon: Icons.people_rounded, label: 'Utilisateurs',
              subtitle: 'Gérer les comptes',
              gradient: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
              onTap: () => goTo(2),
            ),
            _ActionCard(
              icon: Icons.category_rounded, label: 'Départements',
              subtitle: 'Gérer les depts',
              gradient: [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
              onTap: () => goTo(3),
            ),
            _ActionCard(
              icon: Icons.bar_chart_rounded, label: 'Rapports',
              subtitle: 'Voir les stats',
              gradient: [const Color(0xFFF97316), const Color(0xFFF59E0B)],
              onTap: () => goTo(4),
            ),
            _ActionCard(
              icon: Icons.send_rounded, label: 'Notifier',
              subtitle: 'Envoyer un message',
              gradient: [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen())),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashSuperAdmin extends StatelessWidget {
  final void Function(int) goTo;
  const _DashSuperAdmin({required this.goTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Actions'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isDesktop(context) ? 4 : 2, crossAxisSpacing: 14,
          mainAxisSpacing: 14, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ActionCard(
              icon: Icons.school_rounded, label: 'Établissements',
              subtitle: 'Gérer',
              gradient: [const Color(0xFF06B6D4), const Color(0xFF6366F1)],
              onTap: () => goTo(2),
            ),
            _ActionCard(
              icon: Icons.insights_rounded, label: 'Statistiques',
              subtitle: 'Vue globale',
              gradient: [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
              onTap: () => goTo(3),
            ),
            _ActionCard(
              icon: Icons.send_rounded, label: 'Notifier',
              subtitle: 'Toute la plateforme',
              gradient: [const Color(0xFFF97316), const Color(0xFFF59E0B)],
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen())),
            ),
            _ActionCard(
              icon: Icons.person_rounded, label: 'Profil',
              subtitle: 'Mon compte',
              gradient: [const Color(0xFF10B981), const Color(0xFF06B6D4)],
              onTap: () => goTo(4),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3));
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.subtitle, required this.gradient, required this.onTap});
  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(), onTapUp: (_) { _ctrl.reverse(); widget.onTap(); }, onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: widget.gradient.first.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 6))]),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Icon(widget.icon, color: Colors.white, size: 22)),
          const Spacer(),
          Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(widget.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        ]),
      )),
    );
  }
}