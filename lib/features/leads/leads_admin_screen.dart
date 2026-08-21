import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/api_client.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════
// MODELE
// ══════════════════════════════════════════════════════════════════

class Lead {
  final String id;
  final String etablissementNom;
  final String ville;
  final String prenomAdmin;
  final String nomAdmin;
  final String emailAdmin;
  final String plan;
  final String statut;
  final DateTime createdAt;

  const Lead({
    required this.id,
    required this.etablissementNom,
    required this.ville,
    required this.prenomAdmin,
    required this.nomAdmin,
    required this.emailAdmin,
    required this.plan,
    required this.statut,
    required this.createdAt,
  });

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: j['id'] ?? '',
        etablissementNom: j['etablissementNom'] ?? '',
        ville: j['ville'] ?? '',
        prenomAdmin: j['prenomAdmin'] ?? '',
        nomAdmin: j['nomAdmin'] ?? '',
        emailAdmin: j['emailAdmin'] ?? '',
        plan: j['plan'] ?? 'pro',
        statut: j['statut'] ?? 'nouveau',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '')?.toLocal() ??
            DateTime.now(),
      );

  String get adminComplet => '${prenomAdmin.trim()} ${nomAdmin.trim()}'.trim();

  String get planLabel {
    switch (plan) {
      case 'free':
        return 'Gratuit';
      case 'institution':
        return 'Institution';
      default:
        return 'Pro';
    }
  }

  Lead copyWith({String? statut}) => Lead(
        id: id,
        etablissementNom: etablissementNom,
        ville: ville,
        prenomAdmin: prenomAdmin,
        nomAdmin: nomAdmin,
        emailAdmin: emailAdmin,
        plan: plan,
        statut: statut ?? this.statut,
        createdAt: createdAt,
      );
}

// ══════════════════════════════════════════════════════════════════
// CONSTANTES DE STATUT
// ══════════════════════════════════════════════════════════════════

const List<(String, String)> leadStatuts = [
  ('nouveau', 'Nouveau'),
  ('contacte', 'Contacté'),
  ('converti', 'Converti'),
  ('ignore', 'Ignoré'),
];

const Map<String, Color> leadStatutColors = {
  'nouveau': Color(0xFFF97316),
  'contacte': Color(0xFF2563EB),
  'converti': Color(0xFF16A34A),
  'ignore': Color(0xFF94A3B8),
};

String leadStatutLabel(String statut) => leadStatuts
    .firstWhere((s) => s.$1 == statut, orElse: () => ('nouveau', 'Nouveau'))
    .$2;

// ══════════════════════════════════════════════════════════════════
// PROVIDER — connecté au backend
// ══════════════════════════════════════════════════════════════════

final leadsProvider =
    StateNotifierProvider<LeadsNotifier, AsyncValue<List<Lead>>>(
  (ref) => LeadsNotifier(ref),
);

class LeadsNotifier extends StateNotifier<AsyncValue<List<Lead>>> {
  final Ref _ref;

  LeadsNotifier(this._ref) : super(const AsyncLoading()) {
    charger();
  }

  Future<void> charger() async {
    state = const AsyncLoading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('Non connecté');

      final resp = await ApiClient.get('/auth/leads');

      final liste = (resp['leads'] as List<dynamic>? ?? [])
          .map((e) => Lead.fromJson(e as Map<String, dynamic>))
          .toList();

      state = AsyncData(liste);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> majStatut(String id, String statut) async {
    final avant = state.value ?? [];
    state = AsyncData(
      avant.map((l) => l.id == id ? l.copyWith(statut: statut) : l).toList(),
    );
    try {
      await ApiClient.patch('/auth/leads/$id', data: {'statut': statut});
    } catch (_) {
      state = AsyncData(avant); // rollback en cas d'échec
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class LeadsAdminScreen extends ConsumerStatefulWidget {
  const LeadsAdminScreen({super.key});

  @override
  ConsumerState<LeadsAdminScreen> createState() => _LeadsAdminScreenState();
}

class _LeadsAdminScreenState extends ConsumerState<LeadsAdminScreen> {
  String _filtre = 'tous';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final async = ref.watch(leadsProvider);
    final leads = async.value ?? [];

    final filtree = _filtre == 'tous'
        ? leads
        : leads.where((l) => l.statut == _filtre).toList();

    final nonTraitees = leads.where((l) => l.statut == 'nouveau').length;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          // Header dégradé fidèle aux autres écrans
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.dark, Color(0xFF454545)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white70, size: 20),
                        ),
                        const Text('Plateforme SaaS',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              ref.read(leadsProvider.notifier).charger(),
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white70, size: 20),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(s.schools,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        if (nonTraitees > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: .25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$nonTraitees à traiter',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Demandes de création d\'établissement',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

          // Filtres par statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipStatut(
                    label: 'Tous (${leads.length})',
                    selected: _filtre == 'tous',
                    color: context.textSecondary,
                    onTap: () => setState(() => _filtre = 'tous'),
                  ),
                  ...leadStatuts.map((s) => _ChipStatut(
                        label:
                            '${s.$2} (${leads.where((l) => l.statut == s.$1).length})',
                        selected: _filtre == s.$1,
                        color: leadStatutColors[s.$1]!,
                        onTap: () => setState(() => _filtre = s.$1),
                      )),
                ],
              ),
            ),
          ),

          // Liste avec l'arrondi caractéristique
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -8, 0),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: async.when(
                loading: () => const ListSkeleton(rows: 4),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: context.textMuted),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement',
                          style: TextStyle(color: context.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(leadsProvider.notifier).charger(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
                data: (_) => filtree.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_email_read_outlined,
                                size: 48, color: context.textMuted),
                            const SizedBox(height: 12),
                            Text('Aucune demande',
                                style: TextStyle(color: context.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: filtree.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _LeadTile(lead: filtree[i]),
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
// CHIP DE FILTRE
// ══════════════════════════════════════════════════════════════════

class _ChipStatut extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChipStatut({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : context.borderColor,
                width: selected ? 1.5 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : context.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TUILE DEMANDE
// ══════════════════════════════════════════════════════════════════

class _LeadTile extends ConsumerWidget {
  final Lead lead;
  const _LeadTile({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = leadStatutColors[lead.statut]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: lead.statut == 'nouveau'
                ? couleur.withValues(alpha: .45)
                : context.borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  lead.statut == 'nouveau'
                      ? Icons.mark_email_unread_rounded
                      : Icons.mark_email_read_rounded,
                  color: couleur,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.etablissementNom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(lead.adminComplet,
                        style:
                            TextStyle(color: context.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              _BadgeStatut(statut: lead.statut),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoMini(Icons.location_on_rounded, lead.ville, context),
              const SizedBox(width: 16),
              _infoMini(
                  Icons.workspace_premium_rounded, lead.planLabel, context),
              const Spacer(),
              _infoMini(
                  Icons.schedule_rounded, _formatDate(lead.createdAt), context),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'Détails',
                  icon: Icons.visibility_rounded,
                  color: AppColors.dark,
                  onTap: () => _showDetails(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              if (lead.statut == 'nouveau') ...[
                Expanded(
                  child: _ActionBtn(
                    label: 'Contacté',
                    icon: Icons.phone_in_talk_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => ref
                        .read(leadsProvider.notifier)
                        .majStatut(lead.id, 'contacte'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (lead.statut == 'contacte') ...[
                Expanded(
                  child: _ActionBtn(
                    label: 'Converti',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.green,
                    onTap: () => ref
                        .read(leadsProvider.notifier)
                        .majStatut(lead.id, 'converti'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    label: 'Ignorer',
                    icon: Icons.block_rounded,
                    color: AppColors.red,
                    onTap: () => ref
                        .read(leadsProvider.notifier)
                        .majStatut(lead.id, 'ignore'),
                  ),
                ),
              ],
              if (lead.statut == 'converti' || lead.statut == 'ignore')
                Expanded(
                  child: _ActionBtn(
                    label: 'Rouvrir',
                    icon: Icons.replay_rounded,
                    color: context.textSecondary,
                    onTap: () => ref
                        .read(leadsProvider.notifier)
                        .majStatut(lead.id, 'nouveau'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoMini(IconData icon, String text, BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsModal(lead: lead),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BADGE STATUT
// ══════════════════════════════════════════════════════════════════

class _BadgeStatut extends StatelessWidget {
  final String statut;
  const _BadgeStatut({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = leadStatutColors[statut]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        leadStatutLabel(statut).toUpperCase(),
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODAL DÉTAILS
// ══════════════════════════════════════════════════════════════════

class _DetailsModal extends ConsumerWidget {
  final Lead lead;
  const _DetailsModal({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = leadStatutColors[lead.statut]!;
    final notifier = ref.read(leadsProvider.notifier);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.mark_email_unread_rounded,
                      color: couleur, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.etablissementNom,
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      Text('Demande reçue le ${_formatDate(lead.createdAt)}',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.dark : AppColors.light,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  _statDashboard('Plan', lead.planLabel, couleur),
                  _statDashboard('Ville', lead.ville, AppColors.cyan),
                  _statDashboard(
                      'Statut', leadStatutLabel(lead.statut), couleur),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoRow(context, Icons.person_rounded, 'Administrateur',
                lead.adminComplet),
            _infoRow(context, Icons.alternate_email_rounded,
                'Email de l\'établissement', lead.emailAdmin),
            _infoRow(context, Icons.location_on_rounded, 'Ville', lead.ville),
            _infoRow(context, Icons.workspace_premium_rounded, 'Plan choisi',
                lead.planLabel),
            _infoRow(context, Icons.fingerprint_rounded, 'Référence', lead.id),
            const SizedBox(height: 18),
            Row(
              children: [
                if (lead.statut != 'converti')
                  Expanded(
                    child: _ActionBtn(
                      label: 'Convertir en établissement',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.green,
                      onTap: () {
                        Navigator.pop(context);
                        notifier.majStatut(lead.id, 'converti');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Demande marquée comme convertie')),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDashboard(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: context.textMuted, fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// UTILITAIRES
// ══════════════════════════════════════════════════════════════════

String _formatDate(DateTime dt) {
  const mois = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.'
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${mois[dt.month - 1]} · $h:$m';
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
