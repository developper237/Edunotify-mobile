import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════════

class StatsPlateforme {
  final int nbEtablissements;
  final int nbUtilisateurs;
  final int nbSessions;
  final int nbPremium;

  const StatsPlateforme({
    required this.nbEtablissements,
    required this.nbUtilisateurs,
    required this.nbSessions,
    required this.nbPremium,
  });

  factory StatsPlateforme.fromJson(Map<String, dynamic> j) => StatsPlateforme(
    nbEtablissements: j['nbEtablissements'] as int? ?? 0,
    nbUtilisateurs:   j['nbUtilisateurs']   as int? ?? 0,
    nbSessions:       j['nbSessions']        as int? ?? 0,
    nbPremium:        j['nbPremium']         as int? ?? 0,
  );
}

class StatsEtab {
  final String id;
  final String nom;
  final String ville;
  final String plan;
  final bool actif;
  final int nbUsers;
  final int etudiants;
  final int sessions;
  final int taux;

  const StatsEtab({
    required this.id,
    required this.nom,
    required this.ville,
    required this.plan,
    required this.actif,
    required this.nbUsers,
    required this.etudiants,
    required this.sessions,
    required this.taux,
  });

  factory StatsEtab.fromJson(Map<String, dynamic> j) => StatsEtab(
    id:        j['id']        as String? ?? '',
    nom:       j['nom']       as String? ?? '',
    ville:     j['ville']     as String? ?? '',
    plan:      j['plan']      as String? ?? 'free',
    actif:     j['actif']     as bool?   ?? true,
    nbUsers:   j['nbUsers']   as int?    ?? 0,
    etudiants: j['etudiants'] as int?    ?? 0,
    sessions:  j['sessions']  as int?    ?? 0,
    taux:      j['taux']      as int?    ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

class _StatsData {
  final StatsPlateforme plateforme;
  final List<StatsEtab> etablissements;
  const _StatsData({required this.plateforme, required this.etablissements});
}

final statsProvider = FutureProvider<_StatsData>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) throw Exception('Non connecté');

  final resp = await ApiClient.get('/auth/accounts/stats');

  return _StatsData(
    plateforme:     StatsPlateforme.fromJson(
        resp['plateforme'] as Map<String, dynamic>),
    etablissements: (resp['etablissements'] as List<dynamic>? ?? [])
        .map((e) => StatsEtab.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
});

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class StatistiquesScreen extends ConsumerWidget {
  const StatistiquesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s     = ref.watch(stringsProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.stats),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(statsProvider),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: context.textMuted),
              const SizedBox(height: 12),
              Text('Impossible de charger les statistiques',
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(statsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Plateforme ─────────────────────────────────────
              Text('Plateforme',
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _AnimatedMetrics(
                metrics: [
                  _MetricData(
                    label: 'Établissements',
                    value: data.plateforme.nbEtablissements,
                    color: AppColors.cyan,
                    icon: Icons.school_outlined,
                  ),
                  _MetricData(
                    label: 'Utilisateurs',
                    value: data.plateforme.nbUtilisateurs,
                    color: AppColors.violet,
                    icon: Icons.people_outline,
                  ),
                  _MetricData(
                    label: 'Sessions total',
                    value: data.plateforme.nbSessions,
                    color: AppColors.orange,
                    icon: Icons.how_to_reg_outlined,
                  ),
                  _MetricData(
                    label: 'Plans premium',
                    value: data.plateforme.nbPremium,
                    color: AppColors.yellow,
                    icon: Icons.star_outline,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Par établissement ───────────────────────────────
              Text('Présence par établissement',
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),

              if (data.etablissements.isEmpty)
                Center(
                  child: Text('Aucun établissement',
                      style: TextStyle(color: context.textMuted)),
                )
              else
                ...data.etablissements
                    .map((e) => _EtabStatTile(etab: e))
                    .toList(),
            ],
          ),
        ),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════
// TUILE ÉTABLISSEMENT
// ══════════════════════════════════════════════════════════════════

class _EtabStatTile extends StatelessWidget {
  final StatsEtab etab;
  const _EtabStatTile({required this.etab});

  @override
  Widget build(BuildContext context) {
    final color = etab.taux >= 80
        ? AppColors.green
        : etab.taux >= 60
        ? AppColors.orange
        : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: etab.actif ? context.borderColor : AppColors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(etab.nom,
                              style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        // Badge plan
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: etab.plan == 'premium'
                                ? AppColors.yellow.withValues(alpha: 0.12)
                                : context.borderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            etab.plan == 'premium' ? '★ Premium' : 'Free',
                            style: TextStyle(
                              color: etab.plan == 'premium'
                                  ? AppColors.yellow
                                  : context.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 11, color: context.textMuted),
                        const SizedBox(width: 3),
                        Text(etab.ville,
                            style: TextStyle(
                                color: context.textMuted, fontSize: 11)),
                        const SizedBox(width: 12),
                        Icon(Icons.people_outline,
                            size: 11, color: context.textMuted),
                        const SizedBox(width: 3),
                        Text('${etab.etudiants} étudiants',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 11)),
                        const SizedBox(width: 12),
                        Icon(Icons.how_to_reg_outlined,
                            size: 11, color: context.textMuted),
                        const SizedBox(width: 3),
                        Text('${etab.sessions} sessions',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barre de présence
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: etab.taux / 100,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${etab.taux}%',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),

          if (!etab.actif) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Inactif',
                    style: TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MÉTRIQUES ANIMÉES
// ══════════════════════════════════════════════════════════════════

class _MetricData {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _MetricData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _AnimatedMetrics extends StatefulWidget {
  final List<_MetricData> metrics;
  const _AnimatedMetrics({required this.metrics});

  @override
  State<_AnimatedMetrics> createState() => _AnimatedMetricsState();
}

class _AnimatedMetricsState extends State<_AnimatedMetrics>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _fadeIns;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.metrics.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _fadeIns = _controllers.map((c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut),
    ).toList();
    _slides = _controllers.map((c) =>
      Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
    ).toList();
    // Déclenchement séquentiel décalé
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: List.generate(widget.metrics.length, (i) {
        final m = widget.metrics[i];
        return FadeTransition(
          opacity: _fadeIns[i],
          child: SlideTransition(
            position: _slides[i],
            child: _MetricCard(data: m),
          ),
        );
      }),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  String _formatValue(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          // Anneau de progression miniature
          MiniProgressRing(
            value: data.value > 0 ? 1.0 : 0.0,
            color: data.color,
            size: 42,
            center: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 12),
          // Compteur + label
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCounter(
                  value: data.value,
                  formatter: _formatValue,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
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
            ),
          ),
        ],
      ),
    );
  }
}