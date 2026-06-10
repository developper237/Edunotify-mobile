import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODELE & PROVIDER
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

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      roleDistribution: json['roleDistribution'] ?? [],
    );
  }
}

// Provider spécifique à l'établissement de l'Admin
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  // On appelle la route backend filtrée par établissement
  final resp = await ApiClient.get('/auth/admin-stats');
  return AdminStats.fromJson(resp);
});

// ══════════════════════════════════════════════════════════════════
// SCREEN (Rapports Admin)
// ══════════════════════════════════════════════════════════════════

class RapportsAdminScreen extends ConsumerWidget {
  const RapportsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final user = ref.watch(currentUserProvider);
    final primaryColor = AppColors.forRole(user?.role ?? 'admin');

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          // Header avec Dégradé
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Rapports", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text("Tableau de bord",
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.red),
                      const SizedBox(height: 16),
                      Text("Impossible de charger les stats", style: TextStyle(color: context.textMuted)),
                      TextButton(
                        onPressed: () => ref.refresh(adminStatsProvider),
                        child: const Text("Réessayer"),
                      )
                    ],
                  ),
                ),
                data: (stats) => RefreshIndicator(
                  onRefresh: () => ref.refresh(adminStatsProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Cartes de Statistiques réelles
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: "Total Utilisateurs",
                              value: "${stats.totalUsers}",
                              icon: Icons.people_alt_rounded,
                              color: AppColors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              label: "Comptes Actifs",
                              value: "${stats.activeUsers}",
                              icon: Icons.verified_user_rounded,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      Text(
                        "Répartition des rôles",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Affichage dynamique des rôles présents en base
                      if (stats.roleDistribution.isEmpty)
                        Center(child: Text("Aucune donnée", style: TextStyle(color: context.textMuted)))
                      else
                        ...stats.roleDistribution.map((r) => _RoleRow(
                          role: r['role'].toString().toUpperCase(),
                          count: r['count'],
                          total: stats.totalUsers,
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              )),
          Text(label,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final String role;
  final int count;
  final int total;

  const _RoleRow({required this.role, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final double percent = total > 0 ? count / total : 0.0;
    final color = AppColors.forRole(role.toLowerCase());

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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  )),
              Text(
                "$count (${(percent * 100).toStringAsFixed(1)}%)",
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}