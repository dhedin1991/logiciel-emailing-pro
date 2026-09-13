/// Un message en cours de rédaction, sauvegardé sans être envoyé.
class EmailDraft {
  final String id;
  final String subject;
  final String body;
  final DateTime savedAt;

  EmailDraft({
    required this.id,
    required this.subject,
    required this.body,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'body': body,
        'savedAt': savedAt.toIso8601String(),
      };

  factory EmailDraft.fromJson(Map<String, dynamic> json) => EmailDraft(
        id: json['id'] as String,
        subject: json['subject'] as String,
        body: json['body'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
