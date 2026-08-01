/// Signature réutilisable en bas d'un e-mail.
class Signature {
  final String id;
  final String name;
  final String content;

  Signature({
    required this.id,
    required this.name,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
      };

  factory Signature.fromJson(Map<String, dynamic> json) => Signature(
        id: json['id'] as String,
        name: json['name'] as String,
        content: json['content'] as String,
      );
}
