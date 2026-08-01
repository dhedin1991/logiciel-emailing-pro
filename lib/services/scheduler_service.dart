import 'dart:async';
import '../models/scheduled_email.dart';
import 'account_storage.dart';
import 'gmail_send_service.dart';
import 'scheduled_email_storage.dart';

/// Vérifie régulièrement (tant que l'application est ouverte) si des
/// e-mails programmés doivent être envoyés, et les envoie automatiquement.
///
/// Important : comme il n'y a pas de serveur derrière ce logiciel,
/// l'envoi programmé ne se déclenche que si l'application est ouverte
/// (au premier plan ou en arrière-plan) au moment prévu.
class SchedulerService {
  final _storage = ScheduledEmailStorage();
  final _accountStorage = AccountStorage();
  final _sendService = GmailSendService();
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _checkAndSend();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAndSend());
  }

  void stop() {
    _timer?.cancel();
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
        await _storage.update(email.copyWith(sent: true));
      } catch (e) {
        await _storage.update(email.copyWith(errorMessage: e.toString()));
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
