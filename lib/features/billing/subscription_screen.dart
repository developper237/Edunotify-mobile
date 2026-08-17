// lib/features/billing/subscription_screen.dart
// Écran Abonnement — paywall EduNotify (plans, cycle, MTN MoMo / Orange Money).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'billing_models.dart';
import 'billing_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: const SubscriptionBody(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CONTENU RÉUTILISABLE (écran Profil + onglet Rapports admin)
// ══════════════════════════════════════════════════════════════════

class SubscriptionBody extends ConsumerStatefulWidget {
  const SubscriptionBody({super.key});

  @override
  ConsumerState<SubscriptionBody> createState() => _SubscriptionBodyState();
}

class _SubscriptionBodyState extends ConsumerState<SubscriptionBody> {
  String _planSelectionne = 'pro';
  String _cycle = 'mensuel';
  String? _methode = 'mtn_momo';
  final _telController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(billingProvider.notifier).charger());
  }

  @override
  void dispose() {
    _telController.dispose();
    super.dispose();
  }

  bool get _peutSouscrire {
    final role = ref.read(currentUserProvider)?.role;
    return role == 'admin' || role == 'super_admin';
  }

  String _formatDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  Color _statutColor(String statut) {
    switch (statut) {
      case 'actif':   return AppColors.green;
      case 'essai':   return AppColors.blue;
      case 'impaye':  return AppColors.orange;
      case 'annule':  return AppColors.yellow;
      default:        return AppColors.red;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'actif':   return 'Actif';
      case 'essai':   return 'Essai gratuit';
      case 'impaye':  return 'Paiement en attente';
      case 'annule':  return 'Annulé';
      case 'expire':  return 'Expiré';
      default:        return statut;
    }
  }

  Future<void> _souscrire() async {
    final notifier = ref.read(billingProvider.notifier);
    final abo = ref.read(billingProvider).abonnement;

    try {
      final url = await notifier.souscrire(
        planCode: _planSelectionne,
        cycle:    _cycle,
        methodePaiement: _planSelectionne == 'free' ? null : _methode,
        telephone: _telController.text.trim(),
        email:    ref.read(currentUserProvider)?.email,
      );

      if (!mounted) return;

      // Plan gratuit → confirmation directe
      if (_planSelectionne == 'free') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan gratuit activé ✅')),
        );
        await notifier.charger();
        return;
      }

      // Paiement Mobile Money → ouvrir l'URL CinetPay
      if (url != null && url.isNotEmpty) {
        final ouvert = await ouvrirUrlPaiement(url);
        if (ouvert && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement lancé — confirmez le paiement sur votre téléphone 📲'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              abo?.enEssai == true
                  ? 'Abonnement activé avec 14 jours d\'essai gratuit 🎉'
                  : 'Abonnement enregistré. Une facture a été créée.',
            ),
          ),
        );
      }
      await notifier.charger();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur est survenue')),
      );
    }
  }

  Future<void> _payerFacture() async {
    final abo = ref.read(billingProvider).abonnement;
    if (abo?.id == null) return;

    try {
      final url = await ref.read(billingProvider.notifier).payerFacture(
        subscriptionId: abo!.id!,
        methodePaiement: _methode ?? 'mtn_momo',
        telephone: _telController.text.trim(),
      );
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        await ouvrirUrlPaiement(url);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement lancé 📲')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune facture en attente')),
        );
      }
      await ref.read(billingProvider.notifier).charger();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer le paiement')),
      );
    }
  }

  Future<void> _annuler() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'abonnement ?'),
        content: const Text(
            'Vous garderez vos fonctionnalités jusqu\'à la fin de la période payée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await ref.read(billingProvider.notifier).annuler();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abonnement annulé')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingProvider);
    final isDark = context.isDark;
    final abo = state.abonnement;
    final planActuel = state.plans
        .where((p) => p.code == (abo?.planCode ?? 'free'))
        .firstOrNull;

    if (state.isLoading && state.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
        onRefresh: () => ref.read(billingProvider.notifier).charger(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(
              abo: abo,
              plan: planActuel,
              nbEtudiants: state.nbEtudiants,
              formatDate: _formatDate,
              statutColor: _statutColor,
              statutLabel: _statutLabel,
            ),
            const SizedBox(height: 24),

            // ── Choix du plan ──
            const _SectionTitle('Choisissez votre plan'),
            const SizedBox(height: 12),
            ...state.plans.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanCard(
                plan: p,
                cycle: _cycle,
                selectionne: _planSelectionne == p.code,
                surbrillance: p.code == 'pro',
                onTap: () {
                  if (!_peutSouscrire) return;
                  setState(() => _planSelectionne = p.code);
                },
                bloque: !_peutSouscrire,
              ),
            )),

            if (_peutSouscrire) ...[
              const SizedBox(height: 16),
              const _SectionTitle('Cycle de facturation'),
              const SizedBox(height: 10),
              _CycleToggle(cycle: _cycle, onChanged: (c) => setState(() => _cycle = c)),

              // ── Paiement (uniquement plan payant) ──
              if (_planSelectionne != 'free') ...[
                const SizedBox(height: 20),
                const _SectionTitle('Paiement Mobile Money'),
                const SizedBox(height: 10),
                _MethodeSelector(
                  methode: _methode,
                  onChanged: (m) => setState(() => _methode = m),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro Mobile Money (6XXXXXXXX)',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Le paiement est sécurisé via CinetPay (MTN MoMo / Orange Money).',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
              const SizedBox(height: 20),

              // ── Bouton principal ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isSubscribing ? null : _souscrire,
                  child: state.isSubscribing
                      ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    _planSelectionne == 'free'
                        ? 'Passer au plan gratuit'
                        : 'Souscrire — ${_prixSelectionne()}',
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined,
                          color: AppColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La gestion de l\'abonnement est réservée à l\'administrateur de l\'établissement.',
                          style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Actions sur l'abonnement actuel ──
            if (abo != null && !abo.estGratuit && _peutSouscrire) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (abo.statut == 'impaye' || (state.facture?.statut ?? '') == 'en_attente') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.isSubscribing ? null : _payerFacture,
                        icon: const Icon(Icons.payment_rounded),
                        label: const Text('Payer la facture'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (abo.statut == 'actif' || abo.statut == 'essai')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.isSubscribing ? null : _annuler,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler'),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: context.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Essai gratuit de 14 jours sur les plans payants. Paiement 100% sécurisé par CinetPay. '
                          'Annulable à tout moment.',
                      style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
    );
  }

  String _prixSelectionne() {
    final plan = ref.read(billingProvider).plans
        .where((p) => p.code == _planSelectionne)
        .firstOrNull;
    if (plan == null) return '';
    final xaf = _cycle == 'annuel' ? plan.prixAnnuelXAF : plan.prixMensuelXAF;
    if (xaf == 0) return 'Gratuit';
    return '${_formatFCFA(xaf)} / ${_cycle == 'annuel' ? 'an' : 'mois'}';
  }

  String _formatFCFA(int xaf) {
    final nf = NumberFormat.decimalPattern('fr_FR');
    return '${nf.format(xaf)} FCFA';
  }
}

// ══════════════════════════════════════════════════════════════════
// CARTE DE STATUT
// ══════════════════════════════════════════════════════════════════

class _StatusCard extends StatelessWidget {
  final SubscriptionInfo? abo;
  final BillingPlan? plan;
  final int? nbEtudiants;
  final String Function(DateTime?) formatDate;
  final Color Function(String) statutColor;
  final String Function(String) statutLabel;

  const _StatusCard({
    required this.abo,
    required this.plan,
    required this.nbEtudiants,
    required this.formatDate,
    required this.statutColor,
    required this.statutLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final statut = abo?.statut ?? 'actif';
    final couleur = statutColor(statut);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF1C1C3A)]
              : [const Color(0xFFE7F3FF), const Color(0xFFF5F0FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: couleur),
                    const SizedBox(width: 6),
                    Text(
                      statutLabel(statut).toUpperCase(),
                      style: TextStyle(
                        color: couleur,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (nbEtudiants != null)
                Text(
                  '$nbEtudiants étudiant(s)',
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Plan ${plan?.nom ?? 'Gratuit'}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan?.description ?? '',
            style: TextStyle(fontSize: 12.5, color: context.textSecondary),
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Fin d\'essai', value: formatDate(abo?.essaiJusqua), icone: Icons.timer_outlined),
          _InfoRow(label: 'Fin de période', value: formatDate(abo?.finPeriode), icone: Icons.event_outlined),
          if (abo != null && !abo!.estGratuit)
            _InfoRow(
              label: 'Cycle',
              value: abo!.cycle == 'annuel' ? 'Annuel' : 'Mensuel',
              icone: Icons.repeat_rounded,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final IconData icone;
  const _InfoRow({required this.label, required this.value, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icone, size: 14, color: context.textMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: context.textMuted)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12.5, color: context.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TITRE DE SECTION
// ══════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// CARTE DE PLAN
// ══════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  final BillingPlan plan;
  final String cycle;
  final bool selectionne;
  final bool surbrillance;
  final bool bloque;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.selectionne,
    required this.surbrillance,
    required this.bloque,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final prix = cycle == 'annuel' ? plan.prixAnnuelXAF : plan.prixMensuelXAF;
    final gratuit = prix == 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: bloque ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectionne
                  ? AppColors.cyan
                  : surbrillance
                  ? AppColors.cyan.withValues(alpha: 0.4)
                  : context.borderColor,
              width: selectionne ? 2 : 1,
            ),
            boxShadow: selectionne
                ? [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.nom,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (surbrillance) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'POPULAIRE',
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.maxEtudiants == null
                          ? 'Effectif illimité'
                          : 'Jusqu\'à ${plan.maxEtudiants} étudiants',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    if (plan.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        plan.description!,
                        style: TextStyle(fontSize: 11.5, color: context.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    gratuit ? 'Gratuit' : _formatXAF(prix),
                    style: TextStyle(
                      color: selectionne ? AppColors.cyan : context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!gratuit)
                    Text(
                      cycle == 'annuel' ? '/ an' : '/ mois',
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                selectionne
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selectionne ? AppColors.cyan : context.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatXAF(int xaf) {
    final milliers = xaf / 1000;
    final txt = milliers >= 1000
        ? '${(milliers / 1000).toStringAsFixed(1)}M'
        : milliers == milliers.roundToDouble()
        ? '${milliers.round()}k'
        : '${milliers.toStringAsFixed(1)}k';
    return '$txt FCFA';
  }
}

// ══════════════════════════════════════════════════════════════════
// TOGGLE CYCLE
// ══════════════════════════════════════════════════════════════════

class _CycleToggle extends StatelessWidget {
  final String cycle;
  final ValueChanged<String> onChanged;
  const _CycleToggle({required this.cycle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CycleButton(
              label: 'Mensuel',
              selected: cycle == 'mensuel',
              onTap: () => onChanged('mensuel'),
            ),
          ),
          Expanded(
            child: _CycleButton(
              label: 'Annuel (−10%)',
              selected: cycle == 'annuel',
              onTap: () => onChanged('annuel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CycleButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : context.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SÉLECTEUR DE MÉTHODE DE PAIEMENT
// ══════════════════════════════════════════════════════════════════

class _MethodeSelector extends StatelessWidget {
  final String? methode;
  final ValueChanged<String> onChanged;
  const _MethodeSelector({required this.methode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodeCard(
            icone: Icons.phone_android_rounded,
            label: 'MTN MoMo',
            couleur: const Color(0xFFFFCC00),
            selected: methode == 'mtn_momo',
            onTap: () => onChanged('mtn_momo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MethodeCard(
            icone: Icons.smartphone_rounded,
            label: 'Orange Money',
            couleur: const Color(0xFFFF7900),
            selected: methode == 'orange_money',
            onTap: () => onChanged('orange_money'),
          ),
        ),
      ],
    );
  }
}

class _MethodeCard extends StatelessWidget {
  final IconData icone;
  final String label;
  final Color couleur;
  final bool selected;
  final VoidCallback onTap;
  const _MethodeCard({
    required this.icone,
    required this.label,
    required this.couleur,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? couleur : context.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icone, color: couleur, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? couleur : context.textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
