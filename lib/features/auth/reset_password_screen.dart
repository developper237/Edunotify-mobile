import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _nouveauMdp = TextEditingController();
  final _confirmMdp = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  bool _renvoiEnCours = false;
  String? _error;
  String? _successRenvoi;

  @override
  void dispose() {
    _code.dispose();
    _nouveauMdp.dispose();
    _confirmMdp.dispose();
    super.dispose();
  }

  Future<void> _reinitialiser() async {
    final code = _code.text.trim();
    final mdp = _nouveauMdp.text;
    final confirm = _confirmMdp.text;

    if (code.length != 6) {
      setState(() => _error = 'Le code doit contenir 6 chiffres');
      return;
    }
    if (mdp.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères');
      return;
    }
    if (mdp != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.post('/auth/reinitialiser-mot-de-passe', data: {
        'email': widget.email,
        'code': code,
        'nouveauMotDePasse': mdp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mot de passe réinitialisé avec succès'),
        backgroundColor: AppColors.green,
      ));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erreur de connexion au serveur';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renvoyerCode() async {
    setState(() {
      _renvoiEnCours = true;
      _successRenvoi = null;
      _error = null;
    });
    try {
      await ApiClient.post('/auth/mot-de-passe-oublie', data: {'email': widget.email});
      if (!mounted) return;
      setState(() => _successRenvoi = 'Un nouveau code a été envoyé à ${widget.email}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de renvoyer le code, réessayez');
    } finally {
      if (mounted) setState(() => _renvoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  color: AppColors.orange, size: 30),
            ),
            const SizedBox(height: 24),
            Text(
              'Vérifiez votre email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: context.textMuted, height: 1.4),
                children: [
                  const TextSpan(text: 'Un code à 6 chiffres a été envoyé à '),
                  TextSpan(
                    text: widget.email,
                    style: TextStyle(
                        color: context.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                      text: '. Le code expire dans 10 minutes.'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (_error != null) ...[
              _buildBox(_error!, AppColors.red, Icons.error_outline),
              const SizedBox(height: 16),
            ],
            if (_successRenvoi != null) ...[
              _buildBox(_successRenvoi!, AppColors.green, Icons.check_circle_outline),
              const SizedBox(height: 16),
            ],

            _buildLabel('Code de vérification'),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '000000',
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel('Nouveau mot de passe'),
            const SizedBox(height: 8),
            TextField(
              controller: _nouveauMdp,
              obscureText: !_showPass,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline, size: 20, color: context.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: context.textMuted,
                  ),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel('Confirmer le mot de passe'),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmMdp,
              obscureText: !_showPass,
              onSubmitted: (_) => _reinitialiser(),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline, size: 20, color: context.textMuted),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _reinitialiser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Réinitialiser le mot de passe',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: _renvoiEnCours ? null : _renvoyerCode,
                child: _renvoiEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Je n\'ai pas reçu de code — Renvoyer',
                        style: TextStyle(color: AppColors.cyan, fontSize: 13),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBox(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
