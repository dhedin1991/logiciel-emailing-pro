/// Modèle de message réutilisable (ex : relance, devis, bienvenue...).
class MessageTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String folder;

  MessageTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.folder = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
        'folder': folder,
      };

  factory MessageTemplate.fromJson(Map<String, dynamic> json) => MessageTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        body: json['body'] as String,
        folder: json['folder'] as String? ?? '',
      );
}
