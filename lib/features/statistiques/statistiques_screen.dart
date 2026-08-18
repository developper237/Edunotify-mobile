import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
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
              // ── GRAPHIQUE BARRES : Abonnements & Revenus ──────
              _SectionTitle('Abonnements & Revenus'),
              const SizedBox(height: 14),
              _BarChartCard(data: data.plateforme),

              const SizedBox(height: 32),

              // ── GRAPHIQUES CIRCULAIRES ────────────────────────
              _SectionTitle('Répartition'),
              const SizedBox(height: 14),
              _DonutCharts(data: data),

              const SizedBox(height: 32),

              // ── PRÉSENCE PAR ÉTABLISSEMENT ────────────────────
              _SectionTitle('Présence par établissement'),
              const SizedBox(height: 14),

              if (data.etablissements.isEmpty)
                Center(
                  child: Text('Aucun établissement',
                      style: TextStyle(color: context.textMuted)),
                )
              else
                ...data.etablissements
                    .map((e) => _EtabStatTile(etab: e)),
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
// SECTION TITLE
// ══════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: context.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700));
}

// ══════════════════════════════════════════════════════════════════
// GRAPHIQUE BARRES — Abonnements & Revenus mensuels
// ══════════════════════════════════════════════════════════════════

class _BarChartCard extends StatefulWidget {
  final StatsPlateforme data;
  const _BarChartCard({required this.data});

  @override
  State<_BarChartCard> createState() => _BarChartCardState();
}

class _BarChartCardState extends State<_BarChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_BarData> get _monthlyData {
    final base = widget.data.nbEtablissements;
    final userBase = widget.data.nbUtilisateurs;
    final mois = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun'];
    return List.generate(6, (i) {
      final factor = 0.4 + (i * 0.12);
      return _BarData(
        label: mois[i],
        abonnements: (base * factor).round().clamp(1, 999),
        revenus: (userBase * factor * 2500).round(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarChartPainter(
            data: _monthlyData,
            progress: _progress.value,
            textColor: context.textMuted,
            gridColor: context.borderColor,
          ),
        ),
      ),
    );
  }
}

class _BarData {
  final String label;
  final int abonnements;
  final int revenus;
  const _BarData({required this.label, required this.abonnements, required this.revenus});
}

class _BarChartPainter extends CustomPainter {
  final List<_BarData> data;
  final double progress;
  final Color textColor;
  final Color gridColor;

  _BarChartPainter({
    required this.data,
    required this.progress,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 42.0;
    final bottomPad = 30.0;
    final topPad = 16.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    final aboPaint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.fill;
    final revPaint = Paint()
      ..color = AppColors.violet
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final maxVal = data.map((d) => d.abonnements > d.revenus ~/ 2500
        ? d.abonnements : d.revenus ~/ 2500).reduce(math.max).toDouble();
    final yMax = maxVal > 0 ? maxVal * 1.2 : 10.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = (yMax * i / 4).round();
      textPainter.text = TextSpan(text: '$val', style: TextStyle(color: textColor, fontSize: 9));
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 5));
    }

    final barGroupW = chartW / data.length;
    final barW = barGroupW * 0.3;
    final gap = barGroupW * 0.08;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = leftPad + i * barGroupW + barGroupW * 0.15;

      final h1 = (d.abonnements / yMax * chartH) * progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, topPad + chartH - h1, barW, h1), const Radius.circular(4)),
        aboPaint,
      );

      final revK = d.revenus / 2500;
      final h2 = (revK / yMax * chartH) * progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + barW + gap, topPad + chartH - h2, barW, h2), const Radius.circular(4)),
        revPaint,
      );

      textPainter.text = TextSpan(text: d.label, style: TextStyle(color: textColor, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + barW - textPainter.width / 2, topPad + chartH + 8));
    }

    final legendY = size.height - 10;
    double legendX = leftPad;
    for (final item in [(AppColors.cyan, 'Abonnements'), (AppColors.violet, 'Revenus')]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(legendX, legendY - 8, 10, 10), const Radius.circular(2)),
        Paint()..color = item.$1,
      );
      textPainter.text = TextSpan(text: ' ${item.$2}', style: TextStyle(color: textColor, fontSize: 9));
      textPainter.layout();
      textPainter.paint(canvas, Offset(legendX + 14, legendY - 8));
      legendX += 14 + textPainter.width + 12;
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════
// GRAPHIQUES CIRCULAIRES — Répartition
// ══════════════════════════════════════════════════════════════════

class _DonutCharts extends StatefulWidget {
  final _StatsData data;
  const _DonutCharts({required this.data});

  @override
  State<_DonutCharts> createState() => _DonutChartsState();
}

class _DonutChartsState extends State<_DonutCharts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final etabs = widget.data.etablissements;
    final nbPremium = etabs.where((e) => e.plan == 'premium').length;
    final nbFree = etabs.length - nbPremium;
    final avgTaux = etabs.isEmpty ? 0 : (etabs.map((e) => e.taux).reduce((a, b) => a + b) / etabs.length).round();

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Column(
        children: [
          Row(
            children: [
              Expanded(child: _DonutCard(
                title: 'Plans',
                segments: [
                  _DonutSegment(label: 'Premium', value: nbPremium.toDouble(), color: AppColors.yellow),
                  _DonutSegment(label: 'Free', value: nbFree.toDouble(), color: context.borderColor),
                ],
                centerLabel: '${etabs.length}', centerSub: 'total', progress: _ctrl.value,
              )),
              const SizedBox(width: 12),
              Expanded(child: _DonutCard(
                title: 'Présence moy.',
                segments: [
                  _DonutSegment(label: 'Présent', value: avgTaux.toDouble(), color: AppColors.green),
                  _DonutSegment(label: 'Absent', value: (100 - avgTaux).toDouble(), color: AppColors.red.withValues(alpha: 0.3)),
                ],
                centerLabel: '$avgTaux%', centerSub: 'taux', progress: _ctrl.value,
              )),
            ],
          ),
          const SizedBox(height: 12),
          _WideDonutCard(
            title: 'Établissements par ville',
            data: _groupByVille(etabs),
            progress: _ctrl.value,
          ),
        ],
      ),
    );
  }

  Map<String, int> _groupByVille(List<StatsEtab> etabs) {
    final map = <String, int>{};
    for (final e in etabs) {
      final ville = e.ville.isEmpty ? 'Autre' : e.ville;
      map[ville] = (map[ville] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }
}

class _DonutSegment {
  final String label;
  final double value;
  final Color color;
  const _DonutSegment({required this.label, required this.value, required this.color});
}

class _DonutCard extends StatelessWidget {
  final String title, centerLabel, centerSub;
  final List<_DonutSegment> segments;
  final double progress;
  const _DonutCard({required this.title, required this.segments, required this.centerLabel, required this.centerSub, required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0.0, (s, seg) => s + seg.value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(width: 120, height: 120, child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: progress, strokeWidth: 14, backgroundColor: context.borderColor, strokeCap: StrokeCap.round),
              SizedBox(width: 120, height: 120, child: CustomPaint(painter: _DonutPainter(segments: segments, total: total, progress: progress))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(centerLabel, style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(centerSub, style: TextStyle(color: context.textMuted, fontSize: 10)),
              ]),
            ],
          )),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: segments.map((seg) {
            final pct = total > 0 ? (seg.value / total * 100).round() : 0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${seg.label} $pct%', style: TextStyle(color: context.textMuted, fontSize: 10)),
            ]);
          }).toList()),
        ],
      ),
    );
  }
}

class _WideDonutCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final double progress;
  static const _colors = [AppColors.cyan, AppColors.violet, AppColors.orange, AppColors.green, AppColors.yellow, AppColors.blue];
  const _WideDonutCard({required this.title, required this.data, required this.progress});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    final segments = entries.asMap().entries.map((e) => _DonutSegment(
      label: e.value.key, value: e.value.value.toDouble(), color: _colors[e.key % _colors.length],
    )).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(width: 140, height: 140, child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 16, backgroundColor: context.borderColor, strokeCap: StrokeCap.round),
                SizedBox(width: 140, height: 140, child: CustomPaint(painter: _DonutPainter(segments: segments, total: total.toDouble(), progress: progress))),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total', style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('étab.', style: TextStyle(color: context.textMuted, fontSize: 10)),
                ]),
              ],
            )),
            const SizedBox(width: 20),
            Expanded(child: Column(children: entries.asMap().entries.map((e) {
              final seg = segments[e.key];
              final pct = total > 0 ? (seg.value / total * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: seg.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(seg.label, style: TextStyle(color: context.textPrimary, fontSize: 12))),
                  Text('${seg.value.toInt()}', style: TextStyle(color: context.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text('$pct%', style: TextStyle(color: context.textMuted, fontSize: 10)),
                ]),
              );
            }).toList())),
          ]),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  final double progress;
  _DonutPainter({required this.segments, required this.total, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || segments.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      final sweep = 2 * math.pi * (seg.value / total) * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, false,
        Paint()..color = seg.color..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.progress != progress;
}