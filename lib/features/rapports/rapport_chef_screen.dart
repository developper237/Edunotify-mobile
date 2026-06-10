import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../presence/pdf_service.dart'; // Import corrigé vers l'autre dossier

class RapportAppel {
  final String id;
  final String notifId;
  final String titre;
  final String pdfBase64;
  final DateTime recuLe;
  final bool lue;

  const RapportAppel({
    required this.id,
    required this.notifId,
    required this.titre,
    required this.pdfBase64,
    required this.recuLe,
    required this.lue,
  });

  static RapportAppel? fromNotifJson(Map<String, dynamic> j) {
    final notif = j['notification'] as Map<String, dynamic>? ?? {};
    final contenu = notif['contenu'] as String? ?? '';

    if (!contenu.startsWith('PDF:')) return null;

    return RapportAppel(
      id: j['id'] as String? ?? '',
      notifId: notif['id'] as String? ?? '',
      titre: notif['titre'] as String? ?? 'Rapport',
      pdfBase64: contenu.substring(4),
      recuLe: notif['createdAt'] != null
          ? DateTime.parse(notif['createdAt'] as String)
          : DateTime.now(),
      lue: j['lue'] as bool? ?? false,
    );
  }

  Uint8List get pdfBytes => base64Decode(pdfBase64);
  String get nomFichier => titre.replaceFirst('📋 ', '').trim();
}

final rapportsChefProvider = StateNotifierProvider<RapportsChefNotifier, AsyncValue<List<RapportAppel>>>(
        (_) => RapportsChefNotifier());

class RapportsChefNotifier extends StateNotifier<AsyncValue<List<RapportAppel>>> {
  RapportsChefNotifier() : super(const AsyncValue.loading());

  Future<void> charger(String userId, String role, {String? etablissementId, String? departementId}) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.getNotif(
        '/notifications/mes-notifications',
        userId: userId,
        role: role,
        etablissementId: etablissementId,
        departementId: departementId,
        params: {'limit': '100'},
      );

      final notifs = resp['notifs'] as List<dynamic>? ?? [];
      final rapports = notifs
          .map((n) => RapportAppel.fromNotifJson(n as Map<String, dynamic>))
          .whereType<RapportAppel>()
          .toList();

      state = AsyncValue.data(rapports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> marquerLu(String id, String userId, String role) async {
    try {
      await ApiClient.putNotif('/notifications/$id/lire', userId: userId, role: role);
      final actuel = state.valueOrNull ?? [];
      state = AsyncValue.data(actuel.map((r) => r.id == id
          ? RapportAppel(id: r.id, notifId: r.notifId, titre: r.titre, pdfBase64: r.pdfBase64, recuLe: r.recuLe, lue: true)
          : r).toList());
    } catch (_) {}
  }
}

class RapportsChefScreen extends ConsumerStatefulWidget {
  const RapportsChefScreen({super.key});

  @override
  ConsumerState<RapportsChefScreen> createState() => _RapportsChefScreenState();
}

class _RapportsChefScreenState extends ConsumerState<RapportsChefScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  void _charger() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(rapportsChefProvider.notifier).charger(
      user.id, user.role,
      etablissementId: user.etablissementId,
      departementId: user.departementId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rapports = ref.watch(rapportsChefProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports d\'appel'),
        actions: [IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _charger)],
      ),
      body: rapports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur de chargement')),
        data: (liste) {
          if (liste.isEmpty) return const Center(child: Text('Aucun rapport reçu'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RapportTile(rapport: liste[i]),
          );
        },
      ),
    );
  }
}

class _RapportTile extends ConsumerWidget {
  final RapportAppel rapport;
  const _RapportTile({required this.rapport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      tileColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
      title: Text(rapport.nomFichier, style: const TextStyle(fontSize: 13)),
      subtitle: Text(rapport.recuLe.toString().substring(0, 16)),
      trailing: !rapport.lue ? const Icon(Icons.circle, color: Colors.orange, size: 12) : null,
      onTap: () {
        if (!rapport.lue) {
          final user = ref.read(currentUserProvider);
          if (user != null) ref.read(rapportsChefProvider.notifier).marquerLu(rapport.id, user.id, user.role);
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => _PdfViewerScreen(rapport: rapport)));
      },
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final RapportAppel rapport;
  const _PdfViewerScreen({required this.rapport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rapport.nomFichier)),
      body: PdfPreview(
        build: (_) async => rapport.pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
      ),
    );
  }
}