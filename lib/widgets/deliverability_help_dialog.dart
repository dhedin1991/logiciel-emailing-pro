import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../services/dns_check_service.dart';

/// Conseils de délivrabilité + vérification SPF / DKIM / DMARC du domaine
/// du compte expéditeur sélectionné.
Future<void> showDeliverabilityHelp(BuildContext context, EmailAccount account) {
  return showDialog<void>(
    context: context,
    builder: (context) => _DeliverabilityDialog(account: account),
  );
}

class _DeliverabilityDialog extends StatefulWidget {
  final EmailAccount account;
  const _DeliverabilityDialog({required this.account});

  @override
  State<_DeliverabilityDialog> createState() => _DeliverabilityDialogState();
}

class _DeliverabilityDialogState extends State<_DeliverabilityDialog> {
  late final Future<DnsCheckResult> _future = DnsCheckService().check(widget.account.email);

  Widget _row(bool? ok, String label, String help) {
    final icon = ok == null
        ? const Icon(Icons.help_outline, color: Colors.grey, size: 20)
        : ok
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.cancel, color: Colors.red, size: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: help, style: const TextStyle(fontSize: 12)),
            ])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conseils de délivrabilité'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compte : ${widget.account.email}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              FutureBuilder<DnsCheckResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final r = snapshot.data!;
                  if (r.isFreeProvider) {
                    return Text(
                      '${r.domain} est un fournisseur grand public : SPF et DKIM sont gérés par le fournisseur '
                      'et vous ne pouvez pas les modifier. Pour de l\'envoi en masse régulier, une adresse sur '
                      'un domaine qui vous appartient (ex. contact@votre-entreprise.com) est nettement meilleure.',
                    );
                  }
                  if (r.error != null) {
                    return Text('Vérification impossible (connexion ?) : ${r.error}');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Domaine vérifié : ${r.domain}'),
                      const SizedBox(height: 6),
                      _row(r.spf, 'SPF', r.spf == true
                          ? 'présent : les serveurs autorisés à envoyer pour votre domaine sont déclarés.'
                          : 'absent : demandez à votre hébergeur d\'ajouter un enregistrement SPF.'),
                      _row(r.dkim, 'DKIM', r.dkim == true
                          ? 'présent (sélecteur « ${r.dkimSelector} ») : vos messages sont signés.'
                          : 'non trouvé avec les noms usuels : à activer chez votre fournisseur de messagerie '
                              '(il peut aussi utiliser un nom inhabituel).'),
                      _row(r.dmarc, 'DMARC', r.dmarc == true
                          ? 'présent : les messages usurpés sont traités selon votre politique.'
                          : 'absent : à ajouter (au minimum une politique « p=none » pour commencer).'),
                    ],
                  );
                },
              ),
              const Divider(height: 28),
              const Text('Bonnes pratiques', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                '• Compte récent : 50 à 100 e-mails par jour au début, puis augmenter progressivement.\n'
                '• Rythme : gardez le maximum par heure activé et un délai aléatoire entre envois.\n'
                '• Contenu : un objet clair et personnel, peu de liens, aucune pièce jointe lourde, '
                'pas de MAJUSCULES ni de points d\'exclamation en série.\n'
                '• Liste : n\'écrivez qu\'à des personnes qui vous connaissent ; retirez les adresses '
                'qui refusent (bouton « Vérifier la réception »).\n'
                '• Désinscription : respectez toujours les demandes et passez le contact en « Ne plus contacter ».\n'
                '• Testez d\'abord sur quelques adresses (la vôtre, des proches) avant l\'envoi complet.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
