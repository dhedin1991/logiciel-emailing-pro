import 'package:flutter/material.dart';

/// Encart d'information (conseils, bonnes pratiques) — non bloquant,
/// simplement affiché pour informer, contrairement à une boîte de dialogue
/// qui interrompt l'action en cours.
class InfoNotice extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final IconData icon;

  const InfoNotice({
    super.key,
    required this.title,
    required this.bullets,
    this.icon = Icons.lightbulb_outline,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $b', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
