import 'package:flutter/material.dart';

/// Un guide de connexion pour un fournisseur d'e-mail : une suite d'étapes
/// numérotées, un exemple concret chiffré, des solutions de dépannage, et/ou
/// un bloc d'avertissement (cas Outlook, connexion directe indisponible).
class ProviderGuide {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> steps;
  final String? exampleNote;
  final List<String> troubleshooting;
  final String? warningNote;
  final List<String> warningSteps;

  const ProviderGuide({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.steps = const [],
    this.exampleNote,
    this.troubleshooting = const [],
    this.warningNote,
    this.warningSteps = const [],
  });
}

final providerGuides = <ProviderGuide>[
  const ProviderGuide(
    title: 'GMX Mail',
    subtitle: 'Gratuit — mot de passe habituel du compte (pas de mot de passe d\'application nécessaire)',
    icon: Icons.mail_outline,
    steps: [
      'Sur un ordinateur (le menu est plus complet que sur mobile), aller sur mail.gmx.com et se connecter avec le compte GMX à ajouter.',
      'En haut à droite de l\'écran, cliquer sur l\'icône en forme de roue crantée (⚙, Paramètres).',
      'Dans le panneau qui s\'ouvre, chercher la ligne "POP3 & IMAP" (parfois affichée "Transfert et POP3/IMAP" ou "Mail Collector" selon la langue du compte). Cliquer dessus.',
      'Repérer l\'interrupteur/case "Accès POP3" ou "Accès IMAP" et l\'activer (IMAP est recommandé ; POP3 fonctionne aussi si IMAP n\'est pas visible).',
      'Cliquer sur "Enregistrer" ou "Sauvegarder" si un bouton apparaît. GMX ne génère aucun code ni mot de passe spécial : c\'est terminé côté GMX.',
      'Revenir dans Emailing Pro, aller dans Paramètres → Comptes → "Connecter un autre compte (Zoho, GMX, Yahoo...)".',
      'Dans la liste déroulante "Fournisseur", choisir "GMX" : le serveur (mail.gmx.com) et le port (587) se remplissent automatiquement.',
      'Champ "Adresse e-mail" : taper l\'adresse complète, par exemple marie.dupont@gmx.fr ou marie.dupont@gmx.com (bien respecter .fr ou .com selon le compte créé à l\'origine).',
      'Champ "Mot de passe" : taper le mot de passe habituel du compte GMX (celui utilisé pour se connecter sur mail.gmx.com) — GMX est le seul des trois fournisseurs qui n\'exige pas de mot de passe d\'application séparé.',
      'Cliquer sur "Connecter". Un message de succès doit apparaître en quelques secondes.',
    ],
    exampleNote: 'Exemple concret : adresse marie.dupont@gmx.fr → serveur mail.gmx.com, port 587, identifiant = l\'adresse complète, '
        'mot de passe = le mot de passe habituel du compte GMX (aucun code à générer).',
    troubleshooting: [
      'Erreur "Authentification refusée" alors que le mot de passe est correct : vérifier qu\'IMAP ou POP3 est bien activé dans les paramètres GMX (étape 4) — c\'est la cause la plus fréquente.',
      'Le menu "POP3 & IMAP" est introuvable : sur la version mobile du site, ouvrir le menu ☰ en haut à gauche puis "Paramètres" pour retrouver les mêmes options.',
      'Si le port 587 échoue, réessayer avec le port 465 (connexion SSL directe) dans les paramètres avancés du compte.',
    ],
  ),
  const ProviderGuide(
    title: 'Yahoo Mail',
    subtitle: 'Gratuit — nécessite un mot de passe d\'application (double authentification obligatoire)',
    icon: Icons.mail_outline,
    steps: [
      'Aller sur mail.yahoo.com et se connecter avec le compte Yahoo à ajouter.',
      'Cliquer sur l\'icône du compte (photo/avatar) en haut à droite, puis "Gérer votre compte" — ou aller directement sur login.yahoo.com/account/security.',
      'Sur la page "Sécurité du compte", repérer la ligne "Vérification en deux étapes" (en anglais "Two-step verification").',
      'Si elle est désactivée, cliquer sur l\'interrupteur pour l\'activer. Yahoo demande un numéro de téléphone : le saisir, recevoir un code par SMS et le valider.',
      'Une fois la vérification en deux étapes active, faire défiler la même page "Sécurité du compte" jusqu\'à la ligne "Mots de passe d\'application" ("App passwords" / "Generate app password").',
      'Cliquer sur "Générer un mot de passe d\'application" (ou l\'icône "+"), donner un nom facilement reconnaissable, par exemple "Emailing Pro", puis valider.',
      'Yahoo affiche un mot de passe de 16 caractères (des lettres minuscules, sans espaces ni tirets à conserver) : le copier immédiatement — il n\'est montré qu\'une seule fois. S\'il est perdu, il faut recommencer et en générer un nouveau.',
      'Revenir dans Emailing Pro → Paramètres → Comptes → "Connecter un autre compte".',
      'Choisir le fournisseur "Yahoo Mail" : serveur smtp.mail.yahoo.com et port 465 se remplissent automatiquement.',
      'Champ "Adresse e-mail" : l\'adresse complète, par exemple marie.dupont@yahoo.com ou marie.dupont@yahoo.fr.',
      'Champ "Mot de passe" : coller le mot de passe d\'application à 16 caractères généré à l\'étape précédente — jamais le mot de passe habituel du compte, qui sera systématiquement refusé.',
      'Cliquer sur "Connecter".',
    ],
    exampleNote: 'Exemple concret : adresse marie.dupont@yahoo.fr → serveur smtp.mail.yahoo.com, port 465, identifiant = l\'adresse complète, '
        'mot de passe = le code à 16 caractères du type "abcdwxyzefghijkl" généré dans "Mots de passe d\'application" (surtout pas le mot de passe du compte).',
    troubleshooting: [
      'L\'option "Mots de passe d\'application" reste invisible : elle n\'apparaît qu\'après activation complète de la vérification en deux étapes — patienter quelques minutes après l\'activation puis rafraîchir la page.',
      'Erreur "Invalid credentials" malgré un mot de passe d\'application correct : vérifier qu\'il a été copié sans espace avant/après (un espace collé par erreur invalide tout le mot de passe).',
      'Un mot de passe d\'application ne fonctionne plus après un changement du mot de passe principal du compte : Yahoo révoque parfois les mots de passe d\'application dans ce cas — en générer un nouveau.',
    ],
  ),
  const ProviderGuide(
    title: 'AOL Mail',
    subtitle: 'Gratuit — nécessite un mot de passe d\'application (double authentification obligatoire, même principe que Yahoo)',
    icon: Icons.mail_outline,
    steps: [
      'Aller sur mail.aol.com et se connecter avec le compte AOL à ajouter.',
      'Cliquer sur l\'icône du compte en haut à droite, puis "Gérer votre compte" — ou aller directement sur login.aol.com/account/security.',
      'Repérer la ligne "Vérification en deux étapes" ("Two-step verification") et l\'activer si ce n\'est pas déjà fait (un numéro de téléphone est demandé pour recevoir un code par SMS).',
      'Une fois activée, sur la même page, chercher "Générer un mot de passe d\'application" ("Generate app password").',
      'Donner un nom à l\'application, par exemple "Emailing Pro", puis valider.',
      'AOL affiche un mot de passe de 16 caractères, sans espaces : le copier immédiatement (affiché une seule fois, à regénérer si perdu).',
      'Revenir dans Emailing Pro → Paramètres → Comptes → "Connecter un autre compte".',
      'Choisir le fournisseur "AOL Mail" : serveur smtp.aol.com et port 587 se remplissent automatiquement.',
      'Champ "Adresse e-mail" : l\'adresse complète, par exemple marie.dupont@aol.com.',
      'Champ "Mot de passe" : coller le mot de passe d\'application à 16 caractères — jamais le mot de passe habituel du compte.',
      'Cliquer sur "Connecter".',
    ],
    exampleNote: 'Exemple concret : adresse marie.dupont@aol.com → serveur smtp.aol.com, port 587, identifiant = l\'adresse complète, '
        'mot de passe = le code à 16 caractères généré dans les paramètres de sécurité AOL.',
    troubleshooting: [
      'Le lien "Générer un mot de passe d\'application" n\'apparaît pas : la vérification en deux étapes doit être totalement activée (pas seulement en cours de configuration) — se déconnecter et se reconnecter au compte AOL pour rafraîchir, puis réessayer.',
      'Connexion refusée malgré un mot de passe correct : vérifier qu\'aucun espace n\'a été copié avec le mot de passe, et que le port 587 n\'est pas bloqué par un antivirus/pare-feu (essayer le port 465 en secours).',
    ],
  ),
  const ProviderGuide(
    title: 'Outlook / Hotmail / Live',
    subtitle: 'Connexion directe par mot de passe indisponible — solution OAuth détaillée ci-dessous',
    icon: Icons.warning_amber_outlined,
    warningNote:
        'Depuis septembre 2024, Microsoft a définitivement désactivé la connexion par mot de passe (y compris le "mot de passe '
        'd\'application") pour l\'envoi SMTP sur les comptes personnels Outlook.com / Hotmail / Live. Ce n\'est pas une limite de '
        'cette application : aucun logiciel tiers ne peut plus se connecter à Outlook de cette façon, même avec un mot de passe '
        'd\'application généré correctement — Microsoft rejette la connexion directement sur son serveur.\n\n'
        'La seule méthode encore autorisée est la connexion "moderne" OAuth — le même principe que le bouton "Connecter un compte '
        'Gmail" dans l\'application. Elle demande une étape technique préalable, à faire une seule fois : créer une '
        '"inscription d\'application" gratuite dans Azure / Microsoft Entra. Le guide ci-dessous détaille toutes les étapes pour '
        'que tu puisses la faire seule si tu le souhaites, sans revenir demander de précisions.',
    warningSteps: [
      'Aller sur portal.azure.com et se connecter avec un compte Microsoft (un compte personnel gratuit suffit, ou le compte Outlook lui-même).',
      'Si Azure demande d\'ajouter un moyen de paiement pour "vérifier l\'identité" avant de continuer : c\'est une vérification anti-fraude de Microsoft, pas un abonnement payant — l\'inscription d\'application utilisée ici reste gratuite et aucun montant n\'est prélevé pour cet usage. C\'est ce point précis qui a bloqué la démarche jusqu\'ici.',
      'Dans la barre de recherche tout en haut du portail, taper "Inscriptions d\'applications" ("App registrations") et cliquer sur le résultat.',
      'Cliquer sur "+ Nouvelle inscription" ("+ New registration").',
      'Champ "Nom" : taper un nom reconnaissable, par exemple "Emailing Pro".',
      'Champ "Types de comptes pris en charge" : choisir l\'option "Comptes dans un annuaire d\'organisation et comptes Microsoft personnels" (celle qui mentionne à la fois les comptes professionnels et personnels — Outlook.com/Hotmail en fait partie).',
      'Champ "URI de redirection" : choisir le type "Client public/natif (mobile et bureau)" dans la liste déroulante, et taper http://localhost comme valeur (on pourra l\'ajuster ensemble si besoin au moment de finaliser l\'intégration dans l\'app).',
      'Cliquer sur "S\'inscrire" ("Register").',
      'Sur la page qui s\'affiche ("Vue d\'ensemble"), repérer et copier la valeur "ID d\'application (client)" ("Application (client) ID") — c\'est un identifiant en forme de code, à copier intégralement.',
      'Copier aussi la valeur "ID d\'annuaire (locataire)" ("Directory (tenant) ID"), affichée juste en dessous.',
      'Dans le menu de gauche, cliquer sur "Autorisations API" ("API permissions").',
      'Cliquer sur "+ Ajouter une autorisation" ("+ Add a permission"), puis choisir "Microsoft Graph".',
      'Choisir "Autorisations déléguées" ("Delegated permissions").',
      'Dans la barre de recherche des autorisations, chercher et cocher une par une : "IMAP.AccessAsUser.All", "SMTP.Send", "Mail.Send", "offline_access", "User.Read".',
      'Cliquer sur "Ajouter les autorisations" ("Add permissions") en bas de page.',
      'Si un bouton "Accorder un consentement d\'administrateur" est visible et cliquable, cliquer dessus (sur un compte personnel, il peut être grisé — ce n\'est pas bloquant, le consentement se fera individuellement à la première connexion dans l\'app).',
      'Une fois ces étapes faites, envoyer à Claude : l\'"ID d\'application (client)" et l\'"ID d\'annuaire (locataire)" copiés plus haut — l\'intégration du bouton "Connecter un compte Outlook" dans l\'application (sur le modèle du bouton Gmail) pourra alors être terminée.',
    ],
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
          subtitle: const Text('GMX, Yahoo, AOL, Outlook — étapes détaillées, exemples et dépannage', style: TextStyle(fontSize: 12)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      leading: Icon(guide.icon, size: 20),
      title: Text(guide.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(guide.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        if (guide.warningNote != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(guide.warningNote!, style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
          if (guide.warningSteps.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Étapes pour créer l\'inscription Azure (si tu souhaites débloquer Outlook) :',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            _StepList(steps: guide.warningSteps, colorScheme: colorScheme),
          ],
        ] else ...[
          _StepList(steps: guide.steps, colorScheme: colorScheme),
          if (guide.exampleNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(guide.exampleNote!, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                ],
              ),
            ),
          ],
          if (guide.troubleshooting.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('En cas de problème :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            ...guide.troubleshooting.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.build_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  final List<String> steps;
  final ColorScheme colorScheme;
  const _StepList({required this.steps, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
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
                    color: colorScheme.primaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(steps[i], style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
