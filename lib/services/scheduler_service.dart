import 'dart:async';
import '../models/scheduled_email.dart';
import 'account_storage.dart';
import 'email_dispatch_service.dart';
import 'scheduled_email_storage.dart';
import 'log_service.dart';

/// Vérifie régulièrement (tant que l'application est ouverte) si des
/// e-mails programmés doivent être envoyés, et les envoie automatiquement.
///
/// Important : comme il n'y a pas de serveur derrière ce logiciel,
/// l'envoi programmé ne se déclenche que si l'application est ouverte
/// (au premier plan ou en arrière-plan) au moment prévu.
class SchedulerService {
  static const maxFailures = 3;

  final _storage = ScheduledEmailStorage();
  final _accountStorage = AccountStorage();
  final _sendService = EmailDispatchService();
  Timer? _timer;
  bool _running = false;

  void start() {
    _timer?.cancel();
    _checkAndSend();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAndSend());
  }

  void stop() {
    _timer?.cancel();
  }

  /// Prochaine occurrence STRICTEMENT dans le futur (pas de rafale de
  /// rattrapage si l'application est restée fermée plusieurs jours).
  DateTime _nextOccurrence(DateTime from, String recurrence, DateTime now) {
    var next = from;
    for (var i = 0; i < 1000 && !next.isAfter(now); i++) {
      switch (recurrence) {
        case 'daily':
          next = DateTime(next.year, next.month, next.day + 1, next.hour, next.minute);
          break;
        case 'monthly':
          // Évite le débordement (31 janvier -> début mars) : on borne au dernier jour du mois.
          final targetMonth = next.month + 1;
          final lastDay = DateTime(next.year, targetMonth + 1, 0).day;
          final day = from.day > lastDay ? lastDay : from.day;
          next = DateTime(next.year, targetMonth, day, next.hour, next.minute);
          break;
        case 'weekly':
        default:
          next = DateTime(next.year, next.month, next.day + 7, next.hour, next.minute);
      }
    }
    return next;
  }

  Future<void> _checkAndSend() async {
    // Anti-chevauchement : un envoi lent ne doit jamais être relancé par
    // le tick suivant (cause d'envois en double).
    if (_running) return;
    _running = true;
    try {
      final scheduledEmails = await _storage.loadAll();
      final accounts = await _accountStorage.loadAccounts();
      final now = DateTime.now();

      for (final email in scheduledEmails) {
        if (email.sent || email.sendAt.isAfter(now)) continue;
        if (email.failCount >= maxFailures) continue; // abandonné
        final last = email.lastAttemptAt;
        if (last != null) {
          // Pause entre deux tentatives : 5 min après un 1er échec, 10 après un 2e.
          final wait = Duration(minutes: 5 * (email.failCount == 0 ? 1 : email.failCount));
          if (now.difference(last) < wait) continue;
        }

        final account = accounts.where((a) => a.email == email.accountEmail).firstOrNull;
        if (account == null) {
          await _storage.update(email.copyWith(
            errorMessage: 'Compte introuvable.',
            failCount: maxFailures,
            lastAttemptAt: now,
          ));
          continue;
        }

        // Verrou durable AVANT l'envoi : si l'application plante juste après,
        // l'e-mail n'est pas renvoyé en double au redémarrage.
        await _storage.update(email.copyWith(lastAttemptAt: now));

        try {
          await _sendService.sendEmail(
            account: account,
            to: email.to,
            cc: email.cc,
            subject: email.subject,
            body: email.body,
            attachmentPaths: email.attachmentPaths,
          );
          // L'historique est déjà écrit par le service d'envoi (plus de double entrée).
          if (email.recurrence != null) {
            await _storage.update(email.copyWith(
              sendAt: _nextOccurrence(email.sendAt, email.recurrence!, now),
              failCount: 0,
              clearError: true,
            ));
          } else {
            await _storage.update(email.copyWith(sent: true, failCount: 0, clearError: true));
          }
          await LogService().log('Envoi programmé réussi vers ${email.to}, compte ${email.accountEmail}'
              '${email.recurrence != null ? ' (récurrent : ${email.recurrence})' : ''}');
        } catch (e) {
          final failures = email.failCount + 1;
          final gaveUp = failures >= maxFailures;
          await _storage.update(email.copyWith(
            errorMessage: gaveUp
                ? 'Abandonné après $failures échecs : ${e.toString()}'
                : e.toString(),
            failCount: failures,
            lastAttemptAt: now,
          ));
          await LogService().log('Échec envoi programmé vers ${email.to}, compte ${email.accountEmail} '
              '(tentative $failures/$maxFailures) : ${e.toString()}');
        }
      }
    } finally {
      _running = false;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
