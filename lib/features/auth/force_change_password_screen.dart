import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';

class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState
    extends ConsumerState<ForceChangePasswordScreen> {
  final _ancienCtrl   = TextEditingController();
  final _nouveauCtrl  = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _showAncien  = false;
  bool _showNouveau = false;
  bool _showConfirm = false;
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _ancienCtrl.dispose();
    _nouveauCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _valider() {
    if (_ancienCtrl.text.isEmpty ||
        _nouveauCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      return 'Tous les champs sont obligatoires.';
    }
    if (_nouveauCtrl.text.length < 8) {
      return 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
    }
    if (_nouveauCtrl.text == _ancienCtrl.text) {
      return 'Le nouveau mot de passe doit être différent de l\'ancien.';
    }
    if (_nouveauCtrl.text != _confirmCtrl.text) {
      return 'Les deux mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _confirmer() async {
    final err = _valider();
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(authProvider.notifier).activerCompte(
        ancienMotDePasse:  _ancienCtrl.text,
        nouveauMotDePasse: _nouveauCtrl.text,
      );
      // activerCompte met à jour le statut → doitChangerMotDePasse = false
      // → le router redirige automatiquement vers l'app principale
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Icône ──────────────────────────────────────
                  Center(
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color:        context.borderColor.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: context.textSecondary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Titre ──────────────────────────────────────
                  Text(
                    'Activez votre compte',
                    style: TextStyle(
                      color:       context.textPrimary,
                      fontSize:    24,
                      fontWeight:  FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bonjour ${user?.prenom ?? ''}, c\'est votre première connexion. '
                    'Choisissez un mot de passe personnel pour activer votre compte.',
                    style: TextStyle(
                      color:    context.textMuted,
                      fontSize: 14,
                      height:   1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Bannière info ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        context.borderColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: context.textMuted, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'L\'ancien mot de passe est celui fourni par votre administrateur.',
                            style: TextStyle(
                              color:    context.textMuted,
                              fontSize: 12,
                              height:   1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Ancien mot de passe ────────────────────────
                  _Label('Mot de passe actuel (fourni par l\'admin)', context),
                  const SizedBox(height: 8),
                  TextField(
                    controller:  _ancienCtrl,
                    obscureText: !_showAncien,
                    decoration: InputDecoration(
                      hintText:   '••••••••',
                      prefixIcon: Icon(Icons.lock_outline,
                          size: 18, color: context.textMuted),
                      suffixIcon: _ToggleVisibility(
                        visible:  _showAncien,
                        onToggle: () =>
                            setState(() => _showAncien = !_showAncien),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Nouveau mot de passe ───────────────────────
                  _Label('Nouveau mot de passe', context),
                  const SizedBox(height: 8),
                  TextField(
                    controller:  _nouveauCtrl,
                    obscureText: !_showNouveau,
                    decoration: InputDecoration(
                      hintText:   'Min. 8 caractères',
                      prefixIcon: Icon(Icons.lock_open_outlined,
                          size: 18, color: context.textMuted),
                      suffixIcon: _ToggleVisibility(
                        visible:  _showNouveau,
                        onToggle: () =>
                            setState(() => _showNouveau = !_showNouveau),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Indicateur de force
                  if (_nouveauCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PasswordStrength(password: _nouveauCtrl.text),
                  ],

                  const SizedBox(height: 20),

                  // ── Confirmer ──────────────────────────────────
                  _Label('Confirmer le nouveau mot de passe', context),
                  const SizedBox(height: 8),
                  TextField(
                    controller:  _confirmCtrl,
                    obscureText: !_showConfirm,
                    decoration: InputDecoration(
                      hintText:   '••••••••',
                      prefixIcon: Icon(Icons.check_circle_outline,
                          size: 18, color: context.textMuted),
                      suffixIcon: _ToggleVisibility(
                        visible:  _showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    onSubmitted: (_) => _confirmer(),
                  ),

                  // ── Erreur ─────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Bouton ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _confirmer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.textPrimary,
                        foregroundColor: context.bgColor,
                        elevation:       0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.bgColor),
                            )
                          : const Text(
                              'Activer mon compte',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize:   16,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Cette étape est obligatoire pour accéder à l\'application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:    context.textMuted,
                        fontSize: 11,
                        height:   1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Indicateur de force du mot de passe ──────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _score {
    int s = 0;
    if (password.length >= 8)                            s++;
    if (password.contains(RegExp(r'[A-Z]')))             s++;
    if (password.contains(RegExp(r'[0-9]')))             s++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final score  = _score;
    final labels = ['Très faible', 'Faible', 'Moyen', 'Fort'];
    final colors = [AppColors.red, AppColors.orange, AppColors.orange, AppColors.green];

    return Row(
      children: [
        ...List.generate(4, (i) => Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: i < score
                  ? colors[score - 1]
                  : context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
        const SizedBox(width: 10),
        Text(
          score > 0 ? labels[score - 1] : '',
          style: TextStyle(
            color:    score > 0 ? colors[score - 1] : context.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _Label(this.text, this.ctx);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color:      ctx.textSecondary,
          fontSize:   13,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _ToggleVisibility extends StatelessWidget {
  final bool visible;
  final VoidCallback onToggle;
  const _ToggleVisibility({required this.visible, required this.onToggle});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(
          visible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size:  18,
          color: context.textMuted,
        ),
        onPressed: onToggle,
      );
}
