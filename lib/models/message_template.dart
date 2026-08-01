/// Modèle de message réutilisable (ex : relance, devis, bienvenue...).
class MessageTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;

  MessageTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
      };

  factory MessageTemplate.fromJson(Map<String, dynamic> json) => MessageTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        body: json['body'] as String,
      );
}
