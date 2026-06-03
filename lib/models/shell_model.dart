import 'package:cloud_firestore/cloud_firestore.dart';

class ShellModel {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? iconUrl;
  final DateTime createdAt;

  const ShellModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.iconUrl,
    required this.createdAt,
  });

  factory ShellModel.fromDoc(DocumentSnapshot doc, String orgId) {
    final d = doc.data() as Map<String, dynamic>;
    return ShellModel(
      id: doc.id,
      organizationId: orgId,
      name: d['name'] ?? '',
      description: d['description'],
      iconUrl: d['iconUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'iconUrl': iconUrl,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
