import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/queue_email_item.dart';
import '../screens/bulk_send_progress_panel.dart';
import '../services/account_storage.dart';
import '../services/bulk_send_queue_service.dart';
import '../services/campaign_recovery_service.dart';
import '../services/contact_storage.dart';
import '../services/history_storage.dart';
import '../services/send_jobs_manager.dart';
import '../services/signature_renderer.dart';
import '../services/signature_storage.dart';

/// Au démarrage : si une campagne a été interrompue (application fermée,
/// coupure, plantage), propose de la reprendre là où elle s'était arrêtée.
Future<void> offerCampaignResume(BuildContext context) async {
  final state = await CampaignRecoveryService.loadInterrupted();
  if (state == null || !context.mounted) return;

  final sentSoFar = state.totalCount - state.remainingContactIds.length;
  final resume = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Campagne interrompue'),
      content: Text(
        'Un envoi en masse depuis ${state.accountEmail} s\'est arrêté avant la fin.\n\n'
        '$sentSoFar traité(s) sur ${state.totalCount}. '
        '${state.remainingContactIds.length} destinataire(s) restent à envoyer.\n\n'
        'Les destinataires déjà traités ne recevront rien une seconde fois.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abandonner'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reprendre l\'envoi'),
        ),
      ],
    ),
  );

  if (resume != true) {
    await CampaignRecoveryService.clear();
    return;
  }

  final accounts = await AccountStorage().loadAccounts();
  final account = accounts.where((a) => a.email == state.accountEmail).firstOrNull;
  if (account == null) {
    await CampaignRecoveryService.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reprise impossible : le compte ${state.accountEmail} n\'existe plus.')),
      );
    }
    return;
  }

  final allContacts = await ContactStorage().loadContacts();
  final byId = {for (final c in allContacts) c.id: c};
  bool unsubscribed(Contact c) => c.status == 'Ne plus contacter' || c.tags.contains('Ne plus contacter');
  final recipients = state.remainingContactIds
      .map((id) => byId[id])
      .whereType<Contact>()
      .where((c) => !unsubscribed(c))
      .toList();

  // Sécurité anti-doublon : on ne renvoie jamais à une adresse déjà marquée envoyée
  // dans l'historique depuis le début de cette campagne.
  final history = await HistoryStorage().loadAll();
  final alreadySent = history
      .where((e) => e.success && e.accountEmail == account.email && e.sentAt.isAfter(state.startedAt))
      .map((e) => e.to.toLowerCase())
      .toSet();
  recipients.removeWhere((c) => alreadySent.contains(c.email.toLowerCase()));

  if (recipients.isEmpty) {
    await CampaignRecoveryService.clear();
    return;
  }

  final signatures = await SignatureStorage().loadSignatures();
  final signature = signatures.where((s) => s.id == state.signatureId).firstOrNull;

  final queue = BulkSendQueueService();
  queue.configure(
    contacts: recipients,
    minDelayMs: state.minDelayMs,
    maxDelayMs: state.maxDelayMs,
    maxRetries: state.maxRetries,
  );

  await CampaignRecoveryService.save(state.withRemaining(recipients.map((c) => c.id).toList()));

  SendJobsManager.instance.addJob(SendJob(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    label: '${account.email} — reprise, ${recipients.length} destinataire(s)',
    queue: queue,
    startedAt: DateTime.now(),
  ));

  String personalize(String text, QueueEmailItem item) => text
      .replaceAll('{{nom}}', item.name)
      .replaceAll('{{email}}', item.email)
      .replaceAll('{{entreprise}}', item.company);
  String personalizeHtml(String text, QueueEmailItem item) => text
      .replaceAll('{{nom}}', escapeHtml(item.name))
      .replaceAll('{{email}}', escapeHtml(item.email))
      .replaceAll('{{entreprise}}', escapeHtml(item.company));

  unawaited(queue
      .start(
        account: account,
        subjectTemplate: state.subjectTemplate,
        bodyTemplate: state.bodyTemplate,
        signatureGetter: () => signature,
        personalize: personalize,
        attachmentPaths: state.attachmentPaths,
        htmlBodyTemplate: state.htmlBodyTemplate,
        personalizeHtml: personalizeHtml,
        onProgress: CampaignRecoveryService.updateProgress,
      )
      .whenComplete(CampaignRecoveryService.clear));

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => BulkSendProgressPanel(queue: queue),
  );
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
