import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../core/locale.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_provider.dart';
import 'forgot_password_screen.dart';

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

    // Détection du mode Desktop
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Row(
        children: [
          // --- PARTIE DÉCORATIVE (DESKTOP UNIQUEMENT) ---
          // --- PARTIE DÉCORATIVE (DESKTOP UNIQUEMENT) ---
          if (isDesktop)
            Expanded(
              child: Stack(
                children: [
                  // 1. L'image de fond qui remplit tout l'espace
                  Positioned.fill(
                    child: Image.asset(
                      'lib/assets/logos/univ.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 2. Le calque de couleur bleu/cyan légèrement opaque
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.cyan.withValues(alpha: 0.85), // Plus opaque en haut
                            AppColors.cyan.withValues(alpha: 0.7),  // Plus transparent en bas
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // 3. Le contenu (Texte et Icone) au-dessus
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Smart Campus",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                            ],
                          ),
                        ),
                        const Text(
                          "IUT de Douala",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // --- FORMULAIRE DE CONNEXION ---
          // --- FORMULAIRE DE CONNEXION (ASPECT LIQUID GLASS) ---
          Container(
            width: isDesktop ? 500 : screenWidth,
            height: double.infinity,
            // Sur Desktop, on laisse transparaître l'image de gauche ou le fond
            color: isDesktop ? Colors.transparent : context.bgColor,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    // L'effet de flou "Liquid Glass"
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        // Couleur semi-transparente
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(24),
                        // Bordure fine pour l'effet brillant du verre
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // LOGO CIRCULAIRE avec halo animé
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Halo dégradé tournant
                                SizedBox(
                                  width: 210, height: 210,
                                  child: SpinningGlow(
                                    duration: const Duration(seconds: 14),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: SweepGradient(
                                          colors: [
                                            AppColors.cyan.withValues(alpha: 0.0),
                                            AppColors.cyan.withValues(alpha: 0.35),
                                            AppColors.violet.withValues(alpha: 0.35),
                                            AppColors.cyan.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.cyan.withValues(alpha: 0.25),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'lib/assets/logos/logosmart.png',
                                      width:  168,
                                      height: 168,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 100,
                                        height: 100,
                                        color: AppColors.cyan.withValues(alpha: 0.2),
                                        child: const Icon(Icons.school, color: AppColors.cyan, size: 40),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            s.login,
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

                          const SizedBox(height: 32),

                          // AFFICHAGE DE L'ERREUR
                          if (state.error != null) ...[
                            _buildErrorBox(state.error!),
                            const SizedBox(height: 16),
                          ],

                          // CHAMP EMAIL
                          _buildLabel(s.email),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'ton@email.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20, color: context.textMuted),
                              // Fond légèrement plus sombre pour les champs sur le verre
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black12
                                  : Colors.white54,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // CHAMP MOT DE PASSE
                          _buildLabel(s.password),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _password,
                            obscureText: !_showPass,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline, size: 20, color: context.textMuted),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black12
                                  : Colors.white54,
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

                          const SizedBox(height: 8),

                          // LIEN MOT DE PASSE OUBLIÉ
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
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
                          ),

                          const SizedBox(height: 24),

                          // BOUTON DE CONNEXION (dégradé)
                          GradientButton(
                            label: s.login,
                            icon: Icons.login_rounded,
                            loading: state.isLoading,
                            onPressed: state.isLoading ? null : _login,
                          ),

                          const SizedBox(height: 24),


                          const SizedBox(height: 32),
                          Center(
                            child: Text(
                              'SmartCampus',
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