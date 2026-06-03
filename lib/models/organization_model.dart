import 'package:cloud_firestore/cloud_firestore.dart';

class OrgMember {
  final String userId;
  final String role; // 'owner' | 'admin' | 'member'

  const OrgMember({required this.userId, required this.role});

  factory OrgMember.fromMap(Map<String, dynamic> m) =>
      OrgMember(userId: m['userId'] ?? '', role: m['role'] ?? 'member');

  Map<String, dynamic> toMap() => {'userId': userId, 'role': role};
}

class OrganizationModel {
  final String id;
  final String name;
  final String ownerId;
  final String inviteToken;
  final List<OrgMember> members;
  final DateTime createdAt;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteToken,
    required this.members,
    required this.createdAt,
  });

  factory OrganizationModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawMembers = (d['members'] as List<dynamic>?) ?? [];
    return OrganizationModel(
      id: doc.id,
      name: d['name'] ?? '',
      ownerId: d['ownerId'] ?? '',
      inviteToken: d['inviteToken'] ?? '',
      members: rawMembers
          .map((m) => OrgMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerId': ownerId,
    'inviteToken': inviteToken,
    'members': members.map((m) => m.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  bool isMember(String userId) => members.any((m) => m.userId == userId);
}
