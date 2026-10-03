import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/queue_email_item.dart';

/// Progression sauvegardée d'une campagne d'envoi en masse, pour pouvoir la
/// reprendre si l'application est fermée ou plante en cours de route.
class CampaignState {
  final String accountEmail;
  final String subjectTemplate;
  final String bodyTemplate;
  final String? htmlBodyTemplate;
  final String? signatureId;
  final List<String> attachmentPaths;
  final int minDelayMs;
  final int maxDelayMs;
  final int maxRetries;
  final int maxPerHour;
  final int totalCount;
  final List<String> remainingContactIds;
  final DateTime startedAt;

  CampaignState({
    required this.accountEmail,
    required this.subjectTemplate,
    required this.bodyTemplate,
    required this.htmlBodyTemplate,
    required this.signatureId,
    required this.attachmentPaths,
    required this.minDelayMs,
    required this.maxDelayMs,
    required this.maxRetries,
    this.maxPerHour = 0,
    required this.totalCount,
    required this.remainingContactIds,
    required this.startedAt,
  });

  CampaignState withRemaining(List<String> ids) => CampaignState(
        accountEmail: accountEmail,
        subjectTemplate: subjectTemplate,
        bodyTemplate: bodyTemplate,
        htmlBodyTemplate: htmlBodyTemplate,
        signatureId: signatureId,
        attachmentPaths: attachmentPaths,
        minDelayMs: minDelayMs,
        maxDelayMs: maxDelayMs,
        maxRetries: maxRetries,
        maxPerHour: maxPerHour,
        totalCount: totalCount,
        remainingContactIds: ids,
        startedAt: startedAt,
      );

  Map<String, dynamic> toJson() => {
        'accountEmail': accountEmail,
        'subjectTemplate': subjectTemplate,
        'bodyTemplate': bodyTemplate,
        'htmlBodyTemplate': htmlBodyTemplate,
        'signatureId': signatureId,
        'attachmentPaths': attachmentPaths,
        'minDelayMs': minDelayMs,
        'maxDelayMs': maxDelayMs,
        'maxRetries': maxRetries,
        'maxPerHour': maxPerHour,
        'totalCount': totalCount,
        'remainingContactIds': remainingContactIds,
        'startedAt': startedAt.toIso8601String(),
      };

  factory CampaignState.fromJson(Map<String, dynamic> j) => CampaignState(
        accountEmail: j['accountEmail'] as String,
        subjectTemplate: j['subjectTemplate'] as String,
        bodyTemplate: j['bodyTemplate'] as String,
        htmlBodyTemplate: j['htmlBodyTemplate'] as String?,
        signatureId: j['signatureId'] as String?,
        attachmentPaths: (j['attachmentPaths'] as List<dynamic>? ?? []).cast<String>(),
        minDelayMs: j['minDelayMs'] as int? ?? 1500,
        maxDelayMs: j['maxDelayMs'] as int? ?? 1500,
        maxRetries: j['maxRetries'] as int? ?? 1,
        maxPerHour: j['maxPerHour'] as int? ?? 0,
        totalCount: j['totalCount'] as int? ?? 0,
        remainingContactIds: (j['remainingContactIds'] as List<dynamic>? ?? []).cast<String>(),
        startedAt: DateTime.parse(j['startedAt'] as String),
      );
}

class CampaignRecoveryService {
  static CampaignState? _current;
  static Future<void> _queue = Future.value();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}campaign_recovery.json');
  }

  static Future<void> _serial(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      try {
        await action();
      } catch (_) {}
    });
    return _queue;
  }

  /// Début d'une campagne : on mémorise tout ce qu'il faut pour la reprendre.
  static Future<void> save(CampaignState state) => _serial(() async {
        _current = state;
        final file = await _file();
        await file.writeAsString(jsonEncode(state.toJson()), flush: true);
      });

  /// Après chaque e-mail traité : ne reste que ce qui n'est pas encore parti.
  static Future<void> updateProgress(List<QueueEmailItem> items) => _serial(() async {
        final state = _current;
        if (state == null) return;
        const pending = {
          QueueItemStatus.waiting,
          QueueItemStatus.preparing,
          QueueItemStatus.connectingSmtp,
          QueueItemStatus.sending,
          QueueItemStatus.verifying,
          QueueItemStatus.retrying,
        };
        final remaining = items.where((i) => pending.contains(i.status)).map((i) => i.contactId).toList();
        final updated = state.withRemaining(remaining);
        _current = updated;
        final file = await _file();
        await file.writeAsString(jsonEncode(updated.toJson()), flush: true);
      });

  /// Campagne terminée ou annulée volontairement : plus rien à reprendre.
  static Future<void> clear() => _serial(() async {
        _current = null;
        final file = await _file();
        if (await file.exists()) await file.delete();
      });

  /// Campagne interrompue à reprendre (null s'il n'y en a pas).
  static Future<CampaignState?> loadInterrupted() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final state = CampaignState.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      return state.remainingContactIds.isEmpty ? null : state;
    } catch (_) {
      return null;
    }
  }
}
