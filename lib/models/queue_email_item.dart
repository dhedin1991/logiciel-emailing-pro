enum QueueItemStatus {
  waiting,
  preparing,
  connectingSmtp,
  sending,
  verifying,
  sent,
  failed,
  retrying,
  skipped,
  cancelled,
}

class QueueEmailItem {
  final String contactId;
  final String name;
  final String email;
  final String company;
  QueueItemStatus status;
  int attempts;
  String? lastError;
  DateTime? sentAt;
  int? durationMs;

  QueueEmailItem({
    required this.contactId,
    required this.name,
    required this.email,
    this.company = '',
    this.status = QueueItemStatus.waiting,
    this.attempts = 0,
    this.lastError,
    this.sentAt,
    this.durationMs,
  });
}

class QueueLogEntry {
  final DateTime time;
  final String email;
  final String smtpServer;
  final int? durationMs;
  final String? responseCode;
  final String? errorMessage;
  final bool success;

  QueueLogEntry({
    required this.time,
    required this.email,
    required this.smtpServer,
    required this.success,
    this.durationMs,
    this.responseCode,
    this.errorMessage,
  });
}
