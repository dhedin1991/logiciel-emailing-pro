import 'package:flutter/material.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPage({required this.icon, required this.title, required this.description});
}

const _pages = [
  _OnboardingPage(
    icon: Icons.mark_email_read_outlined,
    title: 'Bienvenue dans Emailing Pro',
    description: 'Un logiciel complet pour gérer vos contacts et vos envois d\'e-mails, depuis Windows ou Android.',
  ),
  _OnboardingPage(
    icon: Icons.alternate_email,
    title: 'Comptes',
    description: 'Connectez Gmail ou un compte SMTP (GMX, Yahoo, AOL...) — chaque section a son propre guide détaillé.',
  ),
  _OnboardingPage(
    icon: Icons.people_outline,
    title: 'Contacts',
    description: 'Importez votre carnet d\'adresses, organisez-le avec des étiquettes, des listes et des filtres.',
  ),
  _OnboardingPage(
    icon: Icons.edit_outlined,
    title: 'Rédaction',
    description: 'Écrivez un message, personnalisez-le avec {{nom}}/{{entreprise}}, et envoyez-le à un ou plusieurs destinataires.',
  ),
  _OnboardingPage(
    icon: Icons.bar_chart,
    title: 'Suivi',
    description: 'Historique, statistiques et tableau de bord vous montrent tout ce qui se passe, en temps réel.',
  ),
];

/// Affiche le tutoriel de bienvenue (carrousel de quelques cartes). À
/// n'utiliser qu'une seule fois, au tout premier lancement de l'app.
Future<void> showOnboardingDialog(BuildContext context) async {
  final controller = PageController();
  var index = 0;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          content: SizedBox(
            width: 420,
            height: 320,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setDialogState(() => index = i),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(page.icon, size: 56, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 20),
                          Text(page.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Text(page.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (index < _pages.length - 1) ...[
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Passer')),
              FilledButton(
                onPressed: () => controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: const Text('Suivant'),
              ),
            ] else
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Commencer')),
          ],
        );
      },
    ),
  );
}
