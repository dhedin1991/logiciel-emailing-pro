/// Représente un contact du carnet d'adresses.
class Contact {
  final String id;
  final String name;
  final String email;
  final String company;
  final String phone;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    this.company = '',
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'company': company,
        'phone': phone,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        company: json['company'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}
