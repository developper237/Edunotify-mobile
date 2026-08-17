import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// ── Scanner QR (côté étudiant) ─────────────────────────────────────
/// Lit le QR affiché par le délégué (JSON { sessionId, code, classeId,
/// expiresAt }), en extrait le code de présence et le renvoie à l'appelant.
class QrScannerScreen extends StatefulWidget {
  final void Function(String code) onScanned;

  const QrScannerScreen({super.key, required this.onScanned});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_processing) return;

    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _processing = true;
    setState(() => _error = null);

    String? code;

    // Le QR du délégué est un JSON : { "sessionId":..., "code":..., ... }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        code = decoded['code'] as String?;
      }
    } catch (_) {
      // Pas du JSON → c'est peut-être le code brut à 6 chiffres
      if (RegExp(r'^\d{6}$').hasMatch(raw.trim())) {
        code = raw.trim();
      }
    }

    // Si on n'a rien trouvé, on ne valide pas (QR inconnu)
    if (code == null || code.length < 6) {
      setState(() {
        _processing = false;
        _error = 'QR code invalide. Scannez le QR affiché par votre délégué.';
      });
      return;
    }

    // Feedback haptique léger + retour à l'écran précédent
    HapticFeedback.lightImpact();
    widget.onScanned(code);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scanner le QR du délégué',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          // ── Flux caméra ────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetect,
            ),
          ),

          // ── Zone de visée ──────────────────────────────────────
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 120,
              ),
            ),
          ),

          // ── Légende / erreur ───────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: Column(
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Placez le QR code du délégué dans le cadre pour '
                    'remplir automatiquement votre code de présence.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
