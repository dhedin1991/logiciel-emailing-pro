/// Représente un e-mail dont l'envoi est programmé pour plus tard.
class ScheduledEmail {
  final String id;
  final String accountEmail;
  final String to;
  final String cc;
  final String subject;
  final String body;
  final List<String> attachmentPaths;
  final DateTime sendAt;
  final bool sent;
  final String? errorMessage;
  /// null = envoi unique ; sinon 'daily', 'weekly', ou 'monthly'.
  final String? recurrence;

  ScheduledEmail({
    required this.id,
    required this.accountEmail,
    required this.to,
    required this.subject,
    required this.body,
    required this.sendAt,
    this.cc = '',
    this.attachmentPaths = const [],
    this.sent = false,
    this.errorMessage,
    this.recurrence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountEmail': accountEmail,
        'to': to,
        'cc': cc,
        'subject': subject,
        'body': body,
        'attachmentPaths': attachmentPaths,
        'sendAt': sendAt.toIso8601String(),
        'sent': sent,
        'errorMessage': errorMessage,
        'recurrence': recurrence,
      };

  factory ScheduledEmail.fromJson(Map<String, dynamic> json) => ScheduledEmail(
        id: json['id'] as String,
        accountEmail: json['accountEmail'] as String,
        to: json['to'] as String,
        cc: json['cc'] as String? ?? '',
        subject: json['subject'] as String,
        body: json['body'] as String,
        attachmentPaths: (json['attachmentPaths'] as List<dynamic>? ?? []).cast<String>(),
        sendAt: DateTime.parse(json['sendAt'] as String),
        sent: json['sent'] as bool? ?? false,
        errorMessage: json['errorMessage'] as String?,
        recurrence: json['recurrence'] as String?,
      );

  ScheduledEmail copyWith({bool? sent, String? errorMessage, DateTime? sendAt}) => ScheduledEmail(
        id: id,
        accountEmail: accountEmail,
        to: to,
        cc: cc,
        subject: subject,
        body: body,
        attachmentPaths: attachmentPaths,
        sendAt: sendAt ?? this.sendAt,
        sent: sent ?? this.sent,
        errorMessage: errorMessage ?? this.errorMessage,
        recurrence: recurrence,
      );
}
