import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String shellId;
  final String organizationId;
  final String name;
  final int position;

  const CategoryModel({
    required this.id,
    required this.shellId,
    required this.organizationId,
    required this.name,
    required this.position,
  });

  factory CategoryModel.fromDoc(
    DocumentSnapshot doc,
    String shellId,
    String orgId,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      shellId: shellId,
      organizationId: orgId,
      name: d['name'] ?? '',
      position: d['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'position': position};

  CategoryModel copyWith({String? name, int? position}) => CategoryModel(
    id: id,
    shellId: shellId,
    organizationId: organizationId,
    name: name ?? this.name,
    position: position ?? this.position,
  );
}
