import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/scheduled_email.dart';
import '../models/sent_email_log.dart';
import 'account_storage.dart';
import 'email_dispatch_service.dart';
import 'scheduled_email_storage.dart';
import 'history_storage.dart';
import 'log_service.dart';

/// Vérifie régulièrement (tant que l'application est ouverte) si des
/// e-mails programmés doivent être envoyés, et les envoie automatiquement.
///
/// Important : comme il n'y a pas de serveur derrière ce logiciel,
/// l'envoi programmé ne se déclenche que si l'application est ouverte
/// (au premier plan ou en arrière-plan) au moment prévu.
class SchedulerService {
  final _storage = ScheduledEmailStorage();
  final _accountStorage = AccountStorage();
  final _sendService = EmailDispatchService();
  final _historyStorage = HistoryStorage();
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _checkAndSend();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAndSend());
  }

  void stop() {
    _timer?.cancel();
  }

  DateTime _nextOccurrence(DateTime from, String recurrence) {
    switch (recurrence) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case 'weekly':
      default:
        return from.add(const Duration(days: 7));
    }
  }

  Future<void> _checkAndSend() async {
    final scheduledEmails = await _storage.loadAll();
    final accounts = await _accountStorage.loadAccounts();
    final now = DateTime.now();

    for (final email in scheduledEmails) {
      if (email.sent || email.sendAt.isAfter(now)) continue;

      final account = accounts.where((a) => a.email == email.accountEmail).firstOrNull;
      if (account == null) {
        await _storage.update(email.copyWith(errorMessage: 'Compte introuvable.'));
        continue;
      }

      try {
        await _sendService.sendEmail(
          account: account,
          to: email.to,
          cc: email.cc,
          subject: email.subject,
          body: email.body,
          attachmentPaths: email.attachmentPaths,
        );
        await _historyStorage.add(SentEmailLog(
          id: const Uuid().v4(),
          accountEmail: email.accountEmail,
          to: email.to,
          subject: email.subject,
          sentAt: now,
          success: true,
        ));
        if (email.recurrence != null) {
          // Récurrent : reprogrammé pour la prochaine occurrence au lieu
          // d'être marqué comme définitivement envoyé.
          await _storage.update(email.copyWith(sendAt: _nextOccurrence(email.sendAt, email.recurrence!)));
        } else {
          await _storage.update(email.copyWith(sent: true));
        }
        await LogService().log('Envoi programmé réussi vers ${email.to}, compte ${email.accountEmail}'
            '${email.recurrence != null ? ' (récurrent : ${email.recurrence})' : ''}');
      } catch (e) {
        await _historyStorage.add(SentEmailLog(
          id: const Uuid().v4(),
          accountEmail: email.accountEmail,
          to: email.to,
          subject: email.subject,
          sentAt: now,
          success: false,
          errorMessage: e.toString(),
        ));
        await _storage.update(email.copyWith(errorMessage: e.toString()));
        await LogService().log('Échec envoi programmé vers ${email.to}, compte ${email.accountEmail} : ${e.toString()}');
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
