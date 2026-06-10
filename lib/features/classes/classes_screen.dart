// ── CLASSES SCREEN ────────────────────────────────────────────────
// lib/features/classes/classes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/locale.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.classes)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockClasses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ClasseTile(classe: _mockClasses[i]),
      ),
    );
  }
}

const _mockClasses = [
  {'nom': 'L1 Informatique', 'effectif': '42', 'delegue': 'Marie Ngono',  'tauxPresence': '78'},
  {'nom': 'L2 Informatique', 'effectif': '38', 'delegue': 'Jean Dupont',  'tauxPresence': '85'},
  {'nom': 'L3 Informatique', 'effectif': '31', 'delegue': 'Paul Biya',    'tauxPresence': '91'},
  {'nom': 'M1 Informatique', 'effectif': '24', 'delegue': 'Sophie Ateba', 'tauxPresence': '94'},
];

class _ClasseTile extends StatelessWidget {
  final Map<String, String> classe;
  const _ClasseTile({required this.classe});

  @override
  Widget build(BuildContext context) {
    final taux  = int.parse(classe['tauxPresence']!);
    final color = taux >= 85
        ? AppColors.green
        : taux >= 70 ? AppColors.orange : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(classe['nom']!,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$taux%',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Text('${classe['effectif']} étudiants',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.person_outline,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Text(classe['delegue']!,
                  style: TextStyle(
                      color: context.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: taux / 100,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}