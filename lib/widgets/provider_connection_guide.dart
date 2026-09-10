import 'package:flutter/material.dart';

/// Un guide de connexion pour un fournisseur d'e-mail : soit une suite
/// d'étapes numérotées (cas normal), soit un simple bloc d'avertissement
/// (cas Outlook, actuellement indisponible).
class ProviderGuide {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> steps;
  final String? warningNote;

  const ProviderGuide({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.steps = const [],
    this.warningNote,
  });
}

final providerGuides = <ProviderGuide>[
  const ProviderGuide(
    title: 'GMX Mail',
    subtitle: 'Gratuit — mot de passe habituel du compte (pas de mot de passe d\'application nécessaire)',
    icon: Icons.mail_outline,
    steps: [
      'Aller sur mail.gmx.com et se connecter avec le compte GMX à ajouter.',
      'Cliquer sur l\'icône en forme de roue crantée (Paramètres), en haut à droite de l\'écran.',
      'Dans le menu, ouvrir "POP3 & IMAP" (parfois nommé "Transfert et POP3/IMAP" selon la langue).',
      'Activer l\'option "Accès POP3" ou "Accès IMAP" (l\'une des deux suffit ; IMAP est recommandé).',
      'Enregistrer/valider — GMX ne redemande rien de plus, aucun code n\'est généré.',
      'Revenir dans Emailing Pro, section Comptes → "Connecter un autre compte".',
      'Choisir le fournisseur "GMX" dans la liste déroulante (serveur mail.gmx.com, port 587 déjà pré-remplis).',
      'Renseigner l\'adresse e-mail complète (ex. : nom@gmx.com ou nom@gmx.fr).',
      'Dans le champ mot de passe, indiquer le mot de passe habituel utilisé pour se connecter à mail.gmx.com — GMX ne nécessite pas de mot de passe d\'application séparé.',
      'Cliquer sur "Connecter".',
    ],
  ),
  const ProviderGuide(
    title: 'Yahoo Mail',
    subtitle: 'Gratuit — nécessite un mot de passe d\'application (double authentification obligatoire)',
    icon: Icons.mail_outline,
    steps: [
      'Aller sur mail.yahoo.com et se connecter avec le compte Yahoo à ajouter.',
      'Cliquer sur l\'icône du compte (photo/avatar) en haut à droite, puis "Gérer votre compte" (ou aller directement sur login.yahoo.com/account/security).',
      'Ouvrir la section "Sécurité du compte".',
      'Activer "Vérification en deux étapes" si ce n\'est pas déjà fait (Yahoo demande un numéro de téléphone pour recevoir un code par SMS la première fois).',
      'Une fois la vérification en deux étapes activée, faire défiler jusqu\'à "Générer un mot de passe d\'application" (en anglais : "Generate app password" ou "App passwords").',
      'Donner un nom à l\'application, par exemple "Emailing Pro", puis valider.',
      'Yahoo affiche un mot de passe de 16 caractères, sans espaces : le copier tout de suite (il n\'est montré qu\'une seule fois — s\'il est perdu, il faut en régénérer un nouveau).',
      'Revenir dans Emailing Pro, section Comptes → "Connecter un autre compte".',
      'Choisir le fournisseur "Yahoo Mail" (serveur smtp.mail.yahoo.com, port 465 déjà pré-remplis).',
      'Renseigner l\'adresse e-mail complète (ex. : nom@yahoo.com ou nom@yahoo.fr).',
      'Dans le champ mot de passe, coller le mot de passe d\'application à 16 caractères généré à l\'étape précédente — surtout pas le mot de passe habituel du compte, qui ne fonctionnera pas.',
      'Cliquer sur "Connecter".',
    ],
  ),
  const ProviderGuide(
    title: 'AOL Mail',
    subtitle: 'Gratuit — nécessite un mot de passe d\'application (double authentification obligatoire, même principe que Yahoo)',
    icon: Icons.mail_outline,
    steps: [
      'Aller sur mail.aol.com et se connecter avec le compte AOL à ajouter.',
      'Cliquer sur l\'icône du compte en haut à droite, puis "Gérer votre compte" (ou aller directement sur login.aol.com/account/security).',
      'Ouvrir la section "Sécurité du compte".',
      'Activer "Vérification en deux étapes" si ce n\'est pas déjà fait (un numéro de téléphone est demandé pour recevoir un code par SMS).',
      'Une fois activée, chercher "Générer un mot de passe d\'application" ("Generate app password").',
      'Donner un nom à l\'application, par exemple "Emailing Pro", puis valider.',
      'AOL affiche un mot de passe de 16 caractères, sans espaces : le copier immédiatement (affiché une seule fois).',
      'Revenir dans Emailing Pro, section Comptes → "Connecter un autre compte".',
      'Choisir le fournisseur "AOL Mail" (serveur smtp.aol.com, port 587 déjà pré-remplis).',
      'Renseigner l\'adresse e-mail complète (ex. : nom@aol.com).',
      'Dans le champ mot de passe, coller le mot de passe d\'application à 16 caractères — pas le mot de passe habituel du compte.',
      'Cliquer sur "Connecter".',
    ],
  ),
  const ProviderGuide(
    title: 'Outlook / Hotmail / Live',
    subtitle: 'Indisponible pour le moment — explication et condition pour le débloquer',
    icon: Icons.warning_amber_outlined,
    warningNote:
        'Depuis septembre 2024, Microsoft a désactivé la connexion par mot de passe (y compris le "mot de passe '
        'd\'application") pour l\'envoi SMTP sur les comptes personnels Outlook.com / Hotmail / Live. Ce n\'est donc '
        'pas une limite de cette application : aucun logiciel tiers ne peut plus se connecter à Outlook de cette '
        'façon, même avec un mot de passe d\'application généré correctement — Microsoft rejette la connexion côté '
        'serveur.\n\n'
        'La seule méthode qui fonctionne encore est la connexion "moderne" OAuth (le même principe que le bouton '
        '"Connecter un compte Gmail"). Pour l\'activer, il faut créer une inscription d\'application dans Azure / '
        'Microsoft Entra — et Microsoft exige d\'enregistrer une carte bancaire pour créer cet annuaire, même si '
        'aucun paiement n\'est prélevé pour un usage normal.\n\n'
        'Dès que tu fournis cette carte bancaire (et que l\'inscription Azure est créée), je peux ajouter la '
        'connexion Outlook à l\'app de la même façon que Gmail.',
  ),
];

/// Section pliable "Guide de connexion" affichée en haut de l'écran Comptes.
class ProviderConnectionGuideSection extends StatelessWidget {
  const ProviderConnectionGuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          leading: Icon(Icons.menu_book_outlined, color: Theme.of(context).colorScheme.primary),
          title: const Text('Guide de connexion par fournisseur', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('GMX, Yahoo, AOL, Outlook — étapes détaillées', style: TextStyle(fontSize: 12)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: providerGuides.map((g) => _ProviderTile(guide: g)).toList(),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderGuide guide;
  const _ProviderTile({required this.guide});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(guide.icon, size: 20),
      title: Text(guide.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(guide.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        if (guide.warningNote != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(guide.warningNote!, style: const TextStyle(fontSize: 13, height: 1.5)),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < guide.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(guide.steps[i], style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
