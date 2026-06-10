import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/locale.dart';
import '../../core/router.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final s         = ref.watch(stringsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale    = ref.watch(localeProvider);
    final isDark    = themeMode == ThemeMode.dark;

    if (user == null) return const SizedBox();

    final color = AppColors.forRole(user.role);

    // Correction des couleurs de fond (Utilisation des couleurs du thème)
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── HEADER AVEC DÉGRADÉ ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20, offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.initiales,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.roleLabel(user.role).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── CORPS DE PAGE ──
            Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                children: [
                  _Section(
                    titre: s.information,
                    enfants: [
                      _InfoTile(icon: Icons.email_outlined, label: s.emailLabel, value: user.email),
                      _InfoTile(icon: Icons.badge_outlined, label: s.idLabel, value: user.id),
                      _InfoTile(
                        icon: Icons.circle,
                        label: s.statusLabel,
                        value: user.statut == 'actif' ? s.active : s.inactive,
                        valueColor: user.statut == 'actif' ? AppColors.green : AppColors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    titre: s.settings,
                    enfants: [
                      _ActionTile(icon: Icons.lock_outline, label: s.changePassword, onTap: () => _showChangePwd(context, ref, s)),
                      _ActionTile(icon: Icons.notifications_outlined, label: s.notifPrefs, onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    titre: s.appearance,
                    enfants: [
                      _ToggleTile(
                        icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        label: isDark ? s.darkTheme : s.lightTheme,
                        value: isDark,
                        onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light,
                      ),
                      _ToggleTile(
                        icon: Icons.language_outlined,
                        label: s.language,
                        value: locale == AppLocale.fr,
                        activeLabel: 'FR',
                        inactiveLabel: 'EN',
                        onChanged: (v) => ref.read(localeProvider.notifier).state = v ? AppLocale.fr : AppLocale.en,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    titre: s.session,
                    enfants: [
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        label: s.logout,
                        labelColor: AppColors.red,
                        iconColor: AppColors.red,
                        onTap: () => _confirmLogout(context, ref, s),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'EduNotify v2.0',
                    style: TextStyle(
                      color: (isDark ? AppColors.textMuted : AppColors.lightTextMuted).withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref, Strings s) {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.logoutConfirm, style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary)),
        content: Text(s.logoutMessage, style: TextStyle(color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel, style: const TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: Text(s.disconnect, style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _showChangePwd(BuildContext context, WidgetRef ref, Strings s) {
    final ancien = TextEditingController();
    final nouveau = TextEditingController();
    final confirm = TextEditingController();
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.changePassword, style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            _PwdField(controller: ancien, hint: s.currentPassword),
            const SizedBox(height: 12),
            _PwdField(controller: nouveau, hint: s.newPassword),
            const SizedBox(height: 12),
            _PwdField(controller: confirm, hint: s.confirmNewPwd),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (nouveau.text.isEmpty || ancien.text.isEmpty) return;

                  if (nouveau.text != confirm.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les mots de passe ne correspondent pas")));
                    return;
                  }

                  // Logique d'appel API via le notifier
                  try {
                    await ref.read(authProvider.notifier).updatePassword(
                      oldPassword: ancien.text,
                      newPassword: nouveau.text,
                    );
                    Navigator.pop(context); // Fermer le bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe mis à jour !")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forRole(ref.read(currentUserProvider)!.role),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(s.save, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final List<Widget> enfants;
  const _Section({required this.titre, required this.enfants});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(titre, style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(children: enfants),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoTile({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (isDark ? AppColors.textMuted : AppColors.lightTextMuted).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted, size: 18),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.lightTextMuted, fontSize: 11)),
              Text(value, style: TextStyle(color: valueColor ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary), fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor, iconColor;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.labelColor, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary), size: 20),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: labelColor ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary), fontSize: 15, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final String? activeLabel, inactiveLabel;
  final void Function(bool) onChanged;
  const _ToggleTile({required this.icon, required this.label, required this.value, required this.onChanged, this.activeLabel, this.inactiveLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary, fontSize: 15, fontWeight: FontWeight.w500))),
          if (activeLabel != null)
            Text(value ? activeLabel! : inactiveLabel!, style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.cyan),
        ],
      ),
    );
  }
}

class _PwdField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const _PwdField({required this.controller, required this.hint});
  @override
  State<_PwdField> createState() => _PwdFieldState();
}

class _PwdFieldState extends State<_PwdField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return TextField(
      controller: widget.controller,
      obscureText: !_show,
      style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: fieldBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 18),
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
    );
  }
}