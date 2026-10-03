/// Signature réutilisable en bas d'un e-mail.
///
/// [format] : 'text' (texte libre, ancien format), 'classic' (sobre),
/// 'accent' (trait de couleur à gauche) ou 'corporate' (grande entreprise).
/// Pour les trois formats structurés, les informations sont dans [fields]
/// (champs vides = non affichés) et [content] contient la version texte
/// générée automatiquement (pour l'aperçu en liste et la compatibilité).
class Signature {
  final String id;
  final String name;
  final String content;
  final String format;
  final Map<String, String> fields;
  final int accentColor;

  Signature({
    required this.id,
    required this.name,
    required this.content,
    this.format = 'text',
    this.fields = const {},
    this.accentColor = 0xFF2563EB,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'format': format,
        'fields': fields,
        'accentColor': accentColor,
      };

  factory Signature.fromJson(Map<String, dynamic> json) => Signature(
        id: json['id'] as String,
        name: json['name'] as String,
        content: json['content'] as String? ?? '',
        format: json['format'] as String? ?? 'text',
        fields: ((json['fields'] as Map?) ?? {}).map((k, v) => MapEntry('$k', '$v')),
        accentColor: json['accentColor'] as int? ?? 0xFF2563EB,
      );
}
