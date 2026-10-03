import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart' show PersistentConnection;
import '../models/contact.dart';
import '../models/email_account.dart';
import '../models/queue_email_item.dart';
import '../models/signature.dart';
import 'email_dispatch_service.dart';
import 'gmail_auth_service.dart';
import 'log_service.dart';
import 'mime_utils.dart';
import 'signature_renderer.dart';

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

  PersistentConnection? _smtpConnection;

  Future<void> _closeSmtp() async {
    final c = _smtpConnection;
    _smtpConnection = null;
    try {
      await c?.close();
    } catch (_) {}
  }

  EmailAccount? _lastAccount;
  String? _lastSubjectTemplate;
  String? _lastBodyTemplate;
  Signature? Function()? _lastSignatureGetter;
  String Function(String template, QueueEmailItem item)? _lastPersonalize;
  List<String>? _lastAttachmentPaths;

  // Rafraîchissement d'écran limité : au plus ~5 fois par seconde, au lieu
  // d'environ 6 fois PAR e-mail (cause de ralentissements en masse).
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _maxLogs = 300;

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 200) return;
    _lastNotify = now;
    notifyListeners();
  }

  EmailAccount? get lastAccount => _lastAccount;
  DateTime? get startedAt => _startedAt;

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
      ..addAll(contacts.map((c) => QueueEmailItem(contactId: c.id, name: c.name, email: c.email, company: c.company)));
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
    required String Function(String template, QueueEmailItem item) personalize,
    required List<String> attachmentPaths,
  }) async {
    _lastAccount = account;
    _lastSubjectTemplate = subjectTemplate;
    _lastBodyTemplate = bodyTemplate;
    _lastSignatureGetter = signatureGetter;
    _lastPersonalize = personalize;
    _lastAttachmentPaths = attachmentPaths;

    isRunning = true;
    isCancelled = false;
    isPaused = false;
    _startedAt = DateTime.now();
    notifyListeners();

    // Pièces jointes lues et encodées UNE seule fois pour toute la campagne.
    List<MimeAttachment>? preloaded;
    if (account.provider == 'gmail' && attachmentPaths.isNotEmpty) {
      try {
        preloaded = await MimeUtils.loadAttachments(attachmentPaths);
      } catch (e) {
        abortReason = 'Pièce jointe illisible : $e';
        isRunning = false;
        notifyListeners();
        return;
      }
    }

    try {
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
        _notifyThrottled();

        final personalizedSubject = personalize(subjectTemplate, item);
        final personalizedBody = personalize(bodyTemplate, item);
        final composed = composeBody(personalizedBody, signatureGetter());

        item.status = QueueItemStatus.connectingSmtp;
        _notifyThrottled();
        final stopwatch = Stopwatch()..start();

        try {
          item.status = QueueItemStatus.sending;
          _notifyThrottled();

          if (account.provider != 'gmail' && _smtpConnection == null) {
            _smtpConnection = await _dispatchService.openSmtpConnection(account);
          }
          await _dispatchService.sendEmail(
            account: account,
            to: item.email,
            subject: personalizedSubject,
            body: composed.text,
            htmlBody: composed.html,
            attachmentPaths: attachmentPaths,
            preloadedAttachments: preloaded,
            smtpConnection: _smtpConnection,
          );

          item.status = QueueItemStatus.verifying;
          _notifyThrottled();
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
          if (logs.length > _maxLogs) logs.removeRange(_maxLogs, logs.length);
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
          if (logs.length > _maxLogs) logs.removeRange(_maxLogs, logs.length);
          // La connexion SMTP a peut-être été coupée : on en rouvre une au prochain essai.
          await _closeSmtp();

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
        _notifyThrottled();
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

    } finally {
      await _closeSmtp();
    }

    isRunning = false;
    notifyListeners();
    await LogService().log(
        'Envoi en masse terminé : $sentCount envoyé(s), $failedCount échec(s) sur $totalCount, compte ${_lastAccount?.email ?? '?'}');
  }

  bool get canRetryFailed => !isRunning && failedCount > 0 && _lastAccount != null;

  /// Relance uniquement les envois échoués, avec les mêmes réglages que la
  /// dernière campagne (compte, message, pièces jointes, personnalisation).
  Future<void> retryFailed() async {
    if (!canRetryFailed) return;
    for (final item in items) {
      if (item.status == QueueItemStatus.failed) {
        item.status = QueueItemStatus.waiting;
        item.lastError = null;
      }
    }
    notifyListeners();
    await start(
      account: _lastAccount!,
      subjectTemplate: _lastSubjectTemplate!,
      bodyTemplate: _lastBodyTemplate!,
      signatureGetter: _lastSignatureGetter!,
      personalize: _lastPersonalize!,
      attachmentPaths: _lastAttachmentPaths!,
    );
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
