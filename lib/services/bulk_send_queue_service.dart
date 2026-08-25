import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../models/email_account.dart';
import '../models/queue_email_item.dart';
import '../models/signature.dart';
import 'email_dispatch_service.dart';
import 'gmail_auth_service.dart';

/// File d'attente d'envoi strictement séquentielle : un seul e-mail est
/// traité à la fois (lecture -> génération -> connexion -> envoi ->
/// vérification -> journalisation -> passage au suivant). Ne remplace
/// aucun service existant : EmailDispatchService reste le seul point
/// d'envoi réel, ce module l'orchestre simplement un destinataire à la fois.
class BulkSendQueueService extends ChangeNotifier {
  final EmailDispatchService _dispatchService;
  BulkSendQueueService({EmailDispatchService? dispatchService})
      : _dispatchService = dispatchService ?? EmailDispatchService();

  final List<QueueEmailItem> items = [];
  final List<QueueLogEntry> logs = [];

  bool isRunning = false;
  bool isPaused = false;
  bool isCancelled = false;
  String? abortReason;
  DateTime? _startedAt;

  int minDelayMs = 1500;
  int maxDelayMs = 1500;
  int maxRetries = 1;

  int get totalCount => items.length;
  int get sentCount => items.where((i) => i.status == QueueItemStatus.sent).length;
  int get failedCount => items.where((i) => i.status == QueueItemStatus.failed).length;
  int get remainingCount => items
      .where((i) => i.status == QueueItemStatus.waiting || i.status == QueueItemStatus.retrying)
      .length;

  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Duration get estimatedRemaining {
    final done = sentCount + failedCount;
    if (done == 0 || _startedAt == null) return Duration.zero;
    final avgMs = elapsed.inMilliseconds / done;
    return Duration(milliseconds: (avgMs * remainingCount).round());
  }

  void configure({required List<Contact> contacts, int minDelayMs = 1500, int maxDelayMs = 1500, int maxRetries = 1}) {
    items
      ..clear()
      ..addAll(contacts.map((c) => QueueEmailItem(contactId: c.id, name: c.name, email: c.email)));
    logs.clear();
    this.minDelayMs = minDelayMs;
    this.maxDelayMs = maxDelayMs.clamp(minDelayMs, 1 << 30);
    this.maxRetries = maxRetries;
    isCancelled = false;
    isPaused = false;
    isRunning = false;
    abortReason = null;
    notifyListeners();
  }

  Future<void> start({
    required EmailAccount account,
    required String subjectTemplate,
    required String bodyTemplate,
    required Signature? Function() signatureGetter,
    required String Function(String template, String contactName) personalize,
    required List<String> attachmentPaths,
  }) async {
    isRunning = true;
    isCancelled = false;
    isPaused = false;
    _startedAt = DateTime.now();
    notifyListeners();

    for (final item in items) {
      if (isCancelled) break;

      while (isPaused && !isCancelled) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (isCancelled) break;
      if (item.status == QueueItemStatus.sent) continue;

      var attempt = 0;
      var success = false;

      while (attempt <= maxRetries && !success && !isCancelled) {
        attempt++;
        item.attempts = attempt;
        item.status = attempt == 1 ? QueueItemStatus.preparing : QueueItemStatus.retrying;
        notifyListeners();

        final personalizedSubject = personalize(subjectTemplate, item.name);
        var personalizedBody = personalize(bodyTemplate, item.name);
        final signature = signatureGetter();
        if (signature != null) {
          personalizedBody = '$personalizedBody\n\n${signature.content}';
        }

        item.status = QueueItemStatus.connectingSmtp;
        notifyListeners();
        final stopwatch = Stopwatch()..start();

        try {
          item.status = QueueItemStatus.sending;
          notifyListeners();

          await _dispatchService.sendEmail(
            account: account,
            to: item.email,
            subject: personalizedSubject,
            body: personalizedBody,
            attachmentPaths: attachmentPaths,
          );

          item.status = QueueItemStatus.verifying;
          notifyListeners();
          stopwatch.stop();

          item.status = QueueItemStatus.sent;
          item.sentAt = DateTime.now();
          item.durationMs = stopwatch.elapsedMilliseconds;
          success = true;

          logs.insert(0, QueueLogEntry(
            time: DateTime.now(),
            email: item.email,
            smtpServer: account.provider == 'gmail' ? 'Gmail API' : (account.smtpHost ?? '-'),
            success: true,
            durationMs: stopwatch.elapsedMilliseconds,
          ));
        } catch (e) {
          stopwatch.stop();
          item.lastError = e.toString();
          logs.insert(0, QueueLogEntry(
            time: DateTime.now(),
            email: item.email,
            smtpServer: account.provider == 'gmail' ? 'Gmail API' : (account.smtpHost ?? '-'),
            success: false,
            durationMs: stopwatch.elapsedMilliseconds,
            errorMessage: e.toString(),
          ));

          // Une connexion expirée/révoquée touche TOUT le compte, pas ce seul
          // destinataire : inutile (et très long) de retenter sur chacun des
          // suivants — on arrête la campagne immédiatement.
          if (e is GmailReauthRequiredException) {
            item.status = QueueItemStatus.failed;
            abortReason = e.toString();
            for (final remaining in items) {
              if (remaining.status == QueueItemStatus.waiting) {
                remaining.status = QueueItemStatus.skipped;
              }
            }
            isCancelled = true;
            notifyListeners();
            isRunning = false;
            notifyListeners();
            return;
          }

          if (attempt > maxRetries) {
            item.status = QueueItemStatus.failed;
          }
        }
        notifyListeners();
      }

      if (isCancelled) {
        item.status = QueueItemStatus.cancelled;
        notifyListeners();
        break;
      }

      // Délai configurable (fixe ou aléatoire dans une plage) avant le suivant.
      final delay = minDelayMs == maxDelayMs
          ? minDelayMs
          : minDelayMs + Random().nextInt(maxDelayMs - minDelayMs + 1);
      await Future.delayed(Duration(milliseconds: delay));
    }

    isRunning = false;
    notifyListeners();
  }

  void pause() {
    isPaused = true;
    notifyListeners();
  }

  void resume() {
    isPaused = false;
    notifyListeners();
  }

  void cancel() {
    isCancelled = true;
    isPaused = false;
    notifyListeners();
  }
}
