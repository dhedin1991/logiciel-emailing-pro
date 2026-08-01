class SentEmailLog {
  final String id;
  final String accountEmail;
  final String to;
  final String subject;
  final DateTime sentAt;
  final bool success;
  final String? errorMessage;

  SentEmailLog({
    required this.id,
    required this.accountEmail,
    required this.to,
    required this.subject,
    required this.sentAt,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountEmail': accountEmail,
        'to': to,
        'subject': subject,
        'sentAt': sentAt.toIso8601String(),
        'success': success,
        'errorMessage': errorMessage,
      };

  factory SentEmailLog.fromJson(Map<String, dynamic> json) => SentEmailLog(
        id: json['id'] as String,
        accountEmail: json['accountEmail'] as String,
        to: json['to'] as String,
        subject: json['subject'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        success: json['success'] as bool,
        errorMessage: json['errorMessage'] as String?,
      );
}
