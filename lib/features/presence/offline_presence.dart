import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'qr_scanner_screen.dart';

/// ── Confirmations de présence hors ligne ─────────────────────────
/// Un étudiant hors connexion scanne le QR du délégué : la confirmation
/// est stockée localement avec le timestamp EXACT du scan (`confirmeA`),
/// puis synchronisée vers le backend à la reconnexion. Le backend valide
/// la fenêtre de validité grâce à `confirmeA` (tolérance 5 min après la
/// fermeture de la session), donc la présence est horodatée au moment du
/// scan, pas au moment de la synchronisation.
///
/// Côté délégué : dès que la sync aboutit, le tableau de bord de la
/// session (qui interroge le backend) affiche l'étudiant comme présent.

const _cleStockage = 'presence_confirmations_en_attente';

/// Nombre de confirmations en attente (rafraîchi par les actions).
final pendingOfflineProvider = StateProvider<int>((_) => 0);

Future<List<Map<String, dynamic>>> _chargerEnAttente() async {
  final prefs = await SharedPreferences.getInstance();
  final brut = prefs.getString(_cleStockage);
  if (brut == null || brut.isEmpty) return [];
  try {
    return (jsonDecode(brut) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _sauvegarder(List<Map<String, dynamic>> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cleStockage, jsonEncode(list));
}

/// Stocke une confirmation de présence hors ligne (scan QR).
Future<void> enregistrerConfirmationOffline(
    String code, DateTime confirmeA) async {
  final list = await _chargerEnAttente();
  list.add({'code': code, 'confirmeA': confirmeA.toIso8601String()});
  await _sauvegarder(list);
}

/// Rafraîchit le compteur affiché (bannière « en attente »).
Future<void> rafraichirPendingOffline(WidgetRef ref) async {
  final n = (await _chargerEnAttente()).length;
  ref.read(pendingOfflineProvider.notifier).state = n;
}

/// Synchronise les confirmations stockées vers le backend.
/// Retourne le nombre de confirmations appliquées (y compris celles déjà
/// confirmées côté serveur, code 409).
Future<int> synchroniserConfirmationsOffline(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return 0;

  final enAttente = await _chargerEnAttente();
  if (enAttente.isEmpty) return 0;

  var appliquees = 0;
  final restants = <Map<String, dynamic>>[];

  for (final p in enAttente) {
    try {
      await ApiClient.postPresence(
        '/presence/confirmer',
        data: {
          'code': p['code'],
          'methode': 'qr',
          'confirmeA': p['confirmeA'],
        },
        userId: user.id,
        role: user.role,
        classeId: user.classeId,
      );
      appliquees++;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Déjà confirmé → l'étudiant est présent, on retire.
        appliquees++;
      } else if (e.statusCode != null && e.statusCode! < 500) {
        // Erreur terminale (session fermée, code invalide…) : on retire.
      } else {
        restants.add(p); // réseau / serveur indisponible → on retentera.
      }
    } catch (_) {
      restants.add(p); // erreur inconnue → on retentera.
    }
  }

  await _sauvegarder(restants);
  ref.read(pendingOfflineProvider.notifier).state = restants.length;
  return appliquees;
}

/// Ouvre le scanner, stocke la confirmation puis tente la sync immédiate.
/// Fonctionne même sans session active ni connexion : si la sync échoue,
/// la confirmation reste en attente et partira à la reconnexion.
Future<void> scannerQrOffline(BuildContext context, WidgetRef ref) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QrScannerScreen(
        onScanned: (code) async {
          if (!context.mounted) return;
          await enregistrerConfirmationOffline(code, DateTime.now());
          final appliquees = await synchroniserConfirmationsOffline(ref);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                appliquees > 0
                    ? 'Présence confirmée ✅'
                    : 'Présence enregistrée hors ligne — '
                          'synchronisation automatique à la reconnexion.',
              ),
            ),
          );
        },
      ),
    ),
  );
}
