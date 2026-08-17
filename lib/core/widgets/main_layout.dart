import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showAppBar;

  const MainLayout({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // ── LE DÉGRADÉ UNIFORME (adapté au thème clair/sombre) ──
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF1A1A2E), Color(0xFF16162A)]
              : const [Color(0xFFE7F3FF), Color(0xFFFFF5F7)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Important !
        appBar: showAppBar
            ? AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          actions: actions,
          foregroundColor: const Color(0xFF1A1A2E),
        )
            : null,
        body: child,
      ),
    );
  }
}