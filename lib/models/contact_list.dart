class ContactList {
  final String id;
  final String name;
  final List<String> contactIds;

  ContactList({required this.id, required this.name, required this.contactIds});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'contactIds': contactIds};

  factory ContactList.fromJson(Map<String, dynamic> json) => ContactList(
        id: json['id'] as String,
        name: json['name'] as String,
        contactIds: (json['contactIds'] as List<dynamic>? ?? []).cast<String>(),
      );
}
