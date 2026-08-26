import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const appVersion = '1.0.0';
  static const buildNumber = '1';
  static const releaseDate = '2026-08-25';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emailing Pro', style: Theme.of(context).textTheme.titleLarge),
                  Text('Logiciel professionnel d\'envoi d\'e-mails', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Version', value: appVersion),
          _InfoRow(label: 'Build', value: buildNumber),
          _InfoRow(label: 'Date de sortie', value: releaseDate),
          _InfoRow(label: 'Plateformes', value: 'Windows, Android'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
