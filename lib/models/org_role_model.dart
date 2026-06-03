import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrgPermissions {
  final bool manageOrg;
  final bool manageShells;
  final bool manageRoles;
  final bool manageMessages;
  final bool inviteMembers;

  const OrgPermissions({
    this.manageOrg = false,
    this.manageShells = false,
    this.manageRoles = false,
    this.manageMessages = false,
    this.inviteMembers = false,
  });

  static const all = OrgPermissions(
    manageOrg: true,
    manageShells: true,
    manageRoles: true,
    manageMessages: true,
    inviteMembers: true,
  );

  static const none = OrgPermissions();

  OrgPermissions operator |(OrgPermissions other) => OrgPermissions(
        manageOrg: manageOrg || other.manageOrg,
        manageShells: manageShells || other.manageShells,
        manageRoles: manageRoles || other.manageRoles,
        manageMessages: manageMessages || other.manageMessages,
        inviteMembers: inviteMembers || other.inviteMembers,
      );

  OrgPermissions copyWith({
    bool? manageOrg,
    bool? manageShells,
    bool? manageRoles,
    bool? manageMessages,
    bool? inviteMembers,
  }) =>
      OrgPermissions(
        manageOrg: manageOrg ?? this.manageOrg,
        manageShells: manageShells ?? this.manageShells,
        manageRoles: manageRoles ?? this.manageRoles,
        manageMessages: manageMessages ?? this.manageMessages,
        inviteMembers: inviteMembers ?? this.inviteMembers,
      );

  Map<String, dynamic> toMap() => {
        'manageOrg': manageOrg,
        'manageShells': manageShells,
        'manageRoles': manageRoles,
        'manageMessages': manageMessages,
        'inviteMembers': inviteMembers,
      };

  factory OrgPermissions.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const OrgPermissions();
    return OrgPermissions(
      manageOrg: m['manageOrg'] as bool? ?? false,
      manageShells: m['manageShells'] as bool? ?? false,
      manageRoles: m['manageRoles'] as bool? ?? false,
      manageMessages: m['manageMessages'] as bool? ?? false,
      inviteMembers: m['inviteMembers'] as bool? ?? false,
    );
  }
}

class OrgRole {
  final String id;
  final String name;
  final int colorValue;
  final int position;
  final OrgPermissions permissions;
  final bool isEveryone;

  const OrgRole({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.position,
    required this.permissions,
    this.isEveryone = false,
  });

  Color get color => Color(colorValue);

  factory OrgRole.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrgRole(
      id: doc.id,
      name: d['name'] as String? ?? 'Role',
      colorValue: d['colorValue'] as int? ?? 0xFF7A7A7A,
      position: d['position'] as int? ?? 0,
      permissions:
          OrgPermissions.fromMap(d['permissions'] as Map<String, dynamic>?),
      isEveryone: d['isEveryone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'colorValue': colorValue,
        'position': position,
        'permissions': permissions.toMap(),
        'isEveryone': isEveryone,
      };

  OrgRole copyWith({
    String? name,
    int? colorValue,
    int? position,
    OrgPermissions? permissions,
  }) =>
      OrgRole(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        position: position ?? this.position,
        permissions: permissions ?? this.permissions,
        isEveryone: isEveryone,
      );
}

class OrgMemberRoles {
  final String userId;
  final List<String> roleIds;

  const OrgMemberRoles({required this.userId, required this.roleIds});

  factory OrgMemberRoles.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrgMemberRoles(
      userId: doc.id,
      roleIds: List<String>.from(d['roleIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {'roleIds': roleIds};
}
