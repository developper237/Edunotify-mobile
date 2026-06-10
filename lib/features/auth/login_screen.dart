import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';
import 'auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Détection du mode Desktop
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Row(
        children: [
          // Sur Desktop, on peut ajouter une partie décorative à gauche (Optionnel)
          if (isDesktop)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.cyan, AppColors.cyan.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_rounded, size: 100, color: Colors.white),
                      const SizedBox(height: 24),
                      Text(
                        "EduNotify",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        "IUT de Douala",
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Formulaire de connexion
          Container(
            width: isDesktop ? 500 : screenWidth,
            height: double.infinity,
            color: context.bgColor,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo (plus petit sur Desktop car on a déjà le texte à gauche)
                      Center(
                        child: ClipOval(
                          child: Image.asset(
                            isDark ? 'lib/assets/logos/logo_dark.png' : 'lib/assets/logos/logo_light.png',
                            width: isDesktop ? 120 : screenWidth * 0.6,
                            height: isDesktop ? 120 : screenWidth * 0.6,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Text(
                        s.login, // Ou "Connexion"
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        s.appTagline,
                        style: TextStyle(fontSize: 14, color: context.textMuted),
                      ),

                      const SizedBox(height: 40),

                      // Affichage de l'erreur
                      if (state.error != null) ...[
                        _buildErrorBox(state.error!),
                        const SizedBox(height: 16),
                      ],

                      // Champ Email
                      _buildLabel(s.email),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'ton@email.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: context.textMuted),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Champ Mot de passe
                      _buildLabel(s.password),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        obscureText: !_showPass,
                        onSubmitted: (_) => _login(),
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

                      const SizedBox(height: 40),

                      // Bouton de connexion
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: state.isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyan,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: state.isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : Text(s.login, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Lien inscription
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.noAccount, style: TextStyle(color: context.textMuted, fontSize: 13)),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            ),
                            child: Text(
                              s.createAccount,
                              style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          'EduNotify — IUT Douala',
                          style: TextStyle(
                            color: context.textMuted.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
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
