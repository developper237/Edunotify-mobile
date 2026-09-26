import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_teacher_screen.dart';

/// Écran de connexion — mise en page « maquette » :
/// fond clair dégradé, logo centré (sans cercle), sous-titre,
/// puis carte blanche contenant les champs et le bouton.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;

  /// Remplissage des champs (gris très clair, comme la maquette).
  static const _fieldLight = Color(0xFFF4F6F9);
  static const _fieldDark = Color(0xFF1A2033);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) return;
    await ref.read(authProvider.notifier).login(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final s = ref.watch(stringsProvider);
    final isDark = context.isDark;

    return Scaffold(
      body: Container(
        // Fond : blanc en haut, bleu très clair en bas (comme la maquette)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.28, 1.0],
            colors: isDark
                ? const [AppColors.dark, Color(0xFF14243E)]
                : const [Colors.white, Color(0xFFD9E9FA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── LOGO (sans cercle ni halo coloré) ──
                    Image.asset(
                      'lib/assets/logos/logosmart.png',
                      width: 190,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.school_rounded,
                        size: 72,
                        color: AppColors.cyan,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── SOUS-TITRE ──
                    Text(
                      s.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ── CARTE BLANCHE ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : Colors.white,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // AFFICHAGE DE L'ERREUR
                          if (state.error != null) ...[
                            _buildErrorBox(state.error!),
                            const SizedBox(height: 12),
                          ],

                          // CHAMP EMAIL
                          _buildField(
                            controller: _email,
                            hint: 'ton@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            isDark: isDark,
                          ),

                          const SizedBox(height: 12),

                          // CHAMP MOT DE PASSE
                          _buildField(
                            controller: _password,
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            isDark: isDark,
                            obscure: !_showPass,
                            onSubmitted: (_) => _login(),
                            suffix: IconButton(
                              icon: Icon(
                                _showPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: context.textMuted,
                              ),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // BOUTON DE CONNEXION (dégradé)
                          GradientButton(
                            label: s.login,
                            icon: Icons.login_rounded,
                            loading: state.isLoading,
                            onPressed: state.isLoading ? null : _login,
                          ),

                          const SizedBox(height: 6),

                          // LIEN MOT DE PASSE OUBLIÉ
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // LIEN INSCRIPTION PROFESSEUR
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterTeacherScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Vous êtes professeur et n\'avez pas encore de compte ? Créez-en un',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'SmartCampus',
                      style: TextStyle(
                        color: context.textMuted.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Champ arrondi, fond gris clair, sans bordure visible (style maquette).
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 15, color: context.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: isDark ? _fieldDark : _fieldLight,
        prefixIcon: Icon(icon, size: 20, color: context.textMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 24),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8EDF3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
