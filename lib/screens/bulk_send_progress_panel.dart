import 'package:flutter/material.dart';
import '../models/queue_email_item.dart';
import '../services/bulk_send_queue_service.dart';
import '../services/deliverability_service.dart';

String _statusIcon(QueueItemStatus status) {
  switch (status) {
    case QueueItemStatus.waiting:
      return '☐';
    case QueueItemStatus.preparing:
      return '⟳';
    case QueueItemStatus.connectingSmtp:
      return '🔌';
    case QueueItemStatus.sending:
      return '📤';
    case QueueItemStatus.verifying:
      return '🔎';
    case QueueItemStatus.sent:
      return '✔';
    case QueueItemStatus.failed:
      return '⚠';
    case QueueItemStatus.retrying:
      return '↻';
    case QueueItemStatus.skipped:
      return '⏭';
    case QueueItemStatus.cancelled:
      return '✖';
  }
}

String _statusLabel(QueueItemStatus status) {
  switch (status) {
    case QueueItemStatus.waiting:
      return 'En attente';
    case QueueItemStatus.preparing:
      return 'Préparation';
    case QueueItemStatus.connectingSmtp:
      return 'Connexion SMTP';
    case QueueItemStatus.sending:
      return 'Envoi';
    case QueueItemStatus.verifying:
      return 'Vérification';
    case QueueItemStatus.sent:
      return 'Envoyé';
    case QueueItemStatus.failed:
      return 'Échec';
    case QueueItemStatus.retrying:
      return 'Nouvelle tentative';
    case QueueItemStatus.skipped:
      return 'Ignoré';
    case QueueItemStatus.cancelled:
      return 'Annulé';
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

class BulkSendProgressPanel extends StatefulWidget {
  final BulkSendQueueService queue;
  const BulkSendProgressPanel({super.key, required this.queue});

  @override
  State<BulkSendProgressPanel> createState() => _BulkSendProgressPanelState();
}

class _BulkSendProgressPanelState extends State<BulkSendProgressPanel> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.queue,
      builder: (context, _) {
        final q = widget.queue;
        final progress = q.totalCount == 0 ? 0.0 : (q.sentCount + q.failedCount) / q.totalCount;
        final current = q.items.firstWhere(
          (i) => i.status != QueueItemStatus.waiting &&
              i.status != QueueItemStatus.sent &&
              i.status != QueueItemStatus.failed &&
              i.status != QueueItemStatus.cancelled,
          orElse: () => QueueEmailItem(contactId: '', name: '-', email: '-'),
        );

        return AlertDialog(
          title: const Text('Envoi en cours'),
          content: SizedBox(
            width: 600,
            height: 550,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('Envoyés : ${q.sentCount}/${q.totalCount}'),
                    Text('Restants : ${q.remainingCount}'),
                    Text('Échecs : ${q.failedCount}'),
                    Text('Écoulé : ${_formatDuration(q.elapsed)}'),
                    Text('Restant estimé : ${_formatDuration(q.estimatedRemaining)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  q.isRunning ? 'En cours : ${current.email} (${_statusLabel(current.status)})' : 'Arrêté',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (!q.isRunning && q.abortReason != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Campagne arrêtée : ${q.abortReason}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(tabs: [Tab(text: 'Destinataires'), Tab(text: 'Journal')]),
                        Expanded(
                          child: TabBarView(
                            children: [
                              ListView.builder(
                                itemCount: q.items.length,
                                itemBuilder: (context, index) {
                                  final item = q.items[index];
                                  return ListTile(
                                    dense: true,
                                    leading: Text(_statusIcon(item.status), style: const TextStyle(fontSize: 16)),
                                    title: Text(item.name),
                                    subtitle: Text('${item.email}${item.lastError != null ? ' — ${item.lastError}' : ''}'),
                                    trailing: Text(_statusLabel(item.status), style: const TextStyle(fontSize: 11)),
                                  );
                                },
                              ),
                              ListView.builder(
                                itemCount: q.logs.length,
                                itemBuilder: (context, index) {
                                  final log = q.logs[index];
                                  final h = log.time.hour.toString().padLeft(2, '0');
                                  final m = log.time.minute.toString().padLeft(2, '0');
                                  final s = log.time.second.toString().padLeft(2, '0');
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(log.success ? Icons.check_circle : Icons.error,
                                        color: log.success ? Colors.green : Colors.red, size: 18),
                                    title: Text('$h:$m:$s — ${log.email}'),
                                    subtitle: Text(
                                      'Serveur : ${log.smtpServer}'
                                      '${log.durationMs != null ? ' • ${log.durationMs} ms' : ''}'
                                      '${log.errorMessage != null ? '\n${log.errorMessage}' : ''}',
                                    ),
                                    isThreeLine: log.errorMessage != null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (q.isRunning && !q.isPaused)
              TextButton.icon(onPressed: q.pause, icon: const Icon(Icons.pause), label: const Text('Pause')),
            if (q.isRunning && q.isPaused)
              TextButton.icon(onPressed: q.resume, icon: const Icon(Icons.play_arrow), label: const Text('Reprendre')),
            if (q.isRunning)
              TextButton.icon(
                onPressed: q.cancel,
                icon: const Icon(Icons.stop),
                label: const Text('Annuler'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            if (q.canRetryFailed)
              TextButton.icon(
                onPressed: q.retryFailed,
                icon: const Icon(Icons.replay),
                label: Text('Réessayer les échecs (${q.failedCount})'),
              ),
            if (!q.isRunning && q.sentCount > 0 && q.lastAccount?.provider == 'gmail')
              TextButton.icon(
                onPressed: () => _checkDeliverability(context, q),
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: const Text('Vérifier la réception'),
              ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        );
      },
    );
  }

  Future<void> _checkDeliverability(BuildContext context, BulkSendQueueService q) async {
    final account = q.lastAccount;
    final since = q.startedAt;
    if (account == null || since == null) return;
    String message;
    try {
      final bounces = await DeliverabilityService()
          .findBounces(account, since: since.subtract(const Duration(minutes: 1)));
      final sentEmails = q.items
          .where((i) => i.status == QueueItemStatus.sent)
          .map((i) => i.email.toLowerCase())
          .toSet();
      final mine = bounces.where((b) => sentEmails.contains(b.address.toLowerCase())).toList();
      if (mine.isEmpty) {
        message = 'Aucun retour d\'erreur trouvé : Gmail n\'a signalé aucun refus pour cette campagne.\n\n'
            'Si certains destinataires ne reçoivent rien, le message est probablement classé en courrier '
            'indésirable chez eux (rien ne revient à l\'expéditeur dans ce cas).';
      } else {
        message = '${mine.length} adresse(s) ont refusé le message après envoi :\n\n' +
            mine.map((b) => '• ${b.address}\n  ${b.reason}').join('\n\n');
      }
    } catch (e) {
      message = 'Vérification impossible : $e\n\nSi le message parle d\'autorisation, reconnectez le compte Gmail.';
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réception des e-mails'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}
