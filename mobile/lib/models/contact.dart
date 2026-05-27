import 'package:uuid/uuid.dart';

enum ContactStatus { pending, sent, failed }

class Contact {
  Contact({
    String? id,
    required this.name,
    required this.phone,
    this.status = ContactStatus.pending,
    this.selected = true,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String phone;
  ContactStatus status;
  bool selected;

  String get normalizedPhone => phone.replaceAll(RegExp(r'\D'), '');

  bool get isValid => RegExp(r'^[1-9]\d{8,14}$').hasMatch(normalizedPhone);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'status': status.name,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: ContactStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => ContactStatus.pending,
        ),
      );
}
