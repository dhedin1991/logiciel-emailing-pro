import 'package:flutter/material.dart';
import '../models/queue_email_item.dart';
import '../services/bulk_send_queue_service.dart';

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
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        );
      },
    );
  }
}
