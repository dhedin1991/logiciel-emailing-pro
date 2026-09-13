import 'cctld_country_map.dart';

/// Étiquettes prédéfinies suggérées (l'utilisateur peut aussi en taper
/// une personnalisée directement dans le champ).
const predefinedContactTags = [
  'Client',
  'Client VIP',
  'Prospect',
  'Nouveau prospect',
  'À relancer',
  'Important',
  'Ne plus contacter',
];

/// Représente un contact du carnet d'adresses.
class Contact {
  final String id;
  final String name;
  final String email;
  final String company;
  final String phone;
  final List<String> tags;
  final String note;
  final String status;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    this.company = '',
    this.phone = '',
    this.tags = const [],
    this.note = '',
    this.status = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Domaine déduit de l'adresse e-mail (ex : "exemple.fr").
  String get domain {
    final atIndex = email.lastIndexOf('@');
    return atIndex == -1 ? '' : email.substring(atIndex + 1).toLowerCase();
  }

  /// Pays déduit de l'adresse e-mail (null si indéterminable).
  String? get country => detectCountryFromEmail(email);

  Contact copyWith({
    String? name,
    String? email,
    String? company,
    String? phone,
    List<String>? tags,
    String? note,
    String? status,
  }) =>
      Contact(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        company: company ?? this.company,
        phone: phone ?? this.phone,
        tags: tags ?? this.tags,
        note: note ?? this.note,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'company': company,
        'phone': phone,
        'tags': tags,
        'note': note,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        company: json['company'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        note: json['note'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      );
}
