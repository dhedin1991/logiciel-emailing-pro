/// Un texte court réutilisable (formule de politesse, accroche...),
/// insérable en un clic dans le corps d'un message.
class Snippet {
  final String id;
  final String label;
  final String content;

  Snippet({required this.id, required this.label, required this.content});

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'content': content};

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as String,
        label: json['label'] as String,
        content: json['content'] as String,
      );
}
