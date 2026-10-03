import 'package:flutter/material.dart';
import '../models/email_account.dart';
import '../services/history_storage.dart';

/// Compteur d'envois du jour pour le compte sélectionné
/// (« 87 sur 450 aujourd'hui »), avec alerte à l'approche de la limite Gmail.
class DailySendCounter extends StatelessWidget {
  final EmailAccount account;
  final int refreshTick;

  const DailySendCounter({super.key, required this.account, required this.refreshTick});

  static const gmailDailyLimit = 450;

  @override
  Widget build(BuildContext context) {
    final isGmail = account.provider == 'gmail';
    return FutureBuilder<int>(
      key: ValueKey('${account.email}-$refreshTick'),
      future: HistoryStorage().countSuccessToday(account.email),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 8);
        final n = snapshot.data!;
        final ratio = isGmail ? (n / gmailDailyLimit).clamp(0.0, 1.0) : 0.0;
        final color = ratio >= 1
            ? Colors.red
            : ratio >= 0.8
                ? Colors.orange
                : Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGmail
                    ? 'Aujourd\'hui : $n sur $gmailDailyLimit e-mails (limite prudente Gmail)'
                    : 'Aujourd\'hui : $n e-mail(s) envoyé(s) avec ce compte',
                style: TextStyle(fontSize: 12, color: ratio >= 0.8 ? color : Colors.grey.shade600),
              ),
              if (isGmail) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: ratio, color: color, minHeight: 4),
              ],
              if (ratio >= 0.8)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ratio >= 1
                        ? 'Limite atteinte : attendez demain ou utilisez un autre compte.'
                        : 'Vous approchez de la limite quotidienne.',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
