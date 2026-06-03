import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: d['displayName'] ?? '',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
