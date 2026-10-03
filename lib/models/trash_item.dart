/// Un élément supprimé, conservé dans la corbeille jusqu'à restauration
/// ou suppression définitive.
class TrashItem {
  final String id;

  /// 'draft', 'contact', 'contactList', 'template', 'signature', 'snippet',
  /// 'scheduled', 'history'.
  final String type;
  final String label;

  /// Un ou plusieurs éléments du même type supprimés ensemble.
  final List<Map<String, dynamic>> payloads;
  final DateTime deletedAt;

  TrashItem({
    required this.id,
    required this.type,
    required this.label,
    required this.payloads,
    required this.deletedAt,
  });

  int get count => payloads.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'payloads': payloads,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        id: json['id'] as String,
        type: json['type'] as String,
        label: json['label'] as String,
        payloads: (json['payloads'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        deletedAt: DateTime.parse(json['deletedAt'] as String),
      );
}
