import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/dm_model.dart';
import '../models/org_role_model.dart';
import '../models/organization_model.dart';
import '../models/shell_model.dart';
import '../models/category_model.dart';
import '../models/channel_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/user_status.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── User ──────────────────────────────────────────────────────────────────

  Future<void> updateUserStatus(String uid, UserStatus status) =>
      _db.collection('users').doc(uid).update({'status': status.name});

  Stream<UserModel?> watchUserProfile(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);

  Future<void> updateUserProfile(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (data.isEmpty) return Future.value();
    return _db.collection('users').doc(uid).update(data);
  }

  // ── Organizations ──────────────────────────────────────────────────────────

  Stream<List<OrganizationModel>> watchUserOrgs(String userId) {
    return _db
        .collection('organizations')
        .where('members', arrayContains: {'userId': userId, 'role': 'member'})
        .snapshots()
        .asyncMap((snap) async {
          // arrayContains on nested maps is unreliable; use a simpler approach:
          // store memberIds as a flat array for easy querying
          return snap.docs
              .map((d) => OrganizationModel.fromDoc(d))
              .toList();
        });
  }

  Stream<List<OrganizationModel>> watchUserOrgsFlat(String userId) {
    return _db
        .collection('organizations')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((s) => s.docs.map(OrganizationModel.fromDoc).toList());
  }

  Future<OrganizationModel> createOrganization({
    required String name,
    required String ownerId,
  }) async {
    final token = _uuid.v4().substring(0, 8).toUpperCase();
    final ref = await _db.collection('organizations').add({
      'name': name,
      'ownerId': ownerId,
      'inviteToken': token,
      'memberIds': [ownerId],
      'members': [
        {'userId': ownerId, 'role': 'owner'},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Seed Admin role and @everyone role
    final adminRef = await ref.collection('roles').add({
      ...OrgRole(
        id: '',
        name: 'Admin',
        colorValue: 0xFF4CA87D,
        position: 0,
        permissions: OrgPermissions.all,
      ).toMap(),
    });
    await ref.collection('roles').add({
      ...OrgRole(
        id: '',
        name: '@everyone',
        colorValue: 0xFF7A7A7A,
        position: 999,
        permissions: const OrgPermissions(inviteMembers: true),
        isEveryone: true,
      ).toMap(),
    });

    // Assign creator the Admin role
    await ref.collection('memberRoles').doc(ownerId).set({
      'roleIds': [adminRef.id],
    });

    final doc = await ref.get();
    return OrganizationModel.fromDoc(doc);
  }

  // ── Org Roles ──────────────────────────────────────────────────────────────

  Stream<List<OrgRole>> watchOrgRoles(String orgId) => _db
      .collection('organizations')
      .doc(orgId)
      .collection('roles')
      .orderBy('position')
      .snapshots()
      .map((s) => s.docs.map(OrgRole.fromDoc).toList());

  Future<OrgRole> createOrgRole({
    required String orgId,
    required String name,
    required int colorValue,
    required OrgPermissions permissions,
    required int position,
  }) async {
    final ref = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('roles')
        .add(OrgRole(
          id: '',
          name: name,
          colorValue: colorValue,
          position: position,
          permissions: permissions,
        ).toMap());
    final doc = await ref.get();
    return OrgRole.fromDoc(doc);
  }

  Future<void> updateOrgRole({
    required String orgId,
    required String roleId,
    String? name,
    int? colorValue,
    OrgPermissions? permissions,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (colorValue != null) updates['colorValue'] = colorValue;
    if (permissions != null) updates['permissions'] = permissions.toMap();
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('roles')
        .doc(roleId)
        .update(updates);
  }

  Future<void> deleteOrgRole({
    required String orgId,
    required String roleId,
  }) =>
      _db
          .collection('organizations')
          .doc(orgId)
          .collection('roles')
          .doc(roleId)
          .delete();

  // ── Org Member Roles ────────────────────────────────────────────────────────

  Stream<List<OrgMemberRoles>> watchOrgMemberRoles(String orgId) => _db
      .collection('organizations')
      .doc(orgId)
      .collection('memberRoles')
      .snapshots()
      .map((s) => s.docs.map(OrgMemberRoles.fromDoc).toList());

  Future<void> setMemberRoles({
    required String orgId,
    required String userId,
    required List<String> roleIds,
  }) =>
      _db
          .collection('organizations')
          .doc(orgId)
          .collection('memberRoles')
          .doc(userId)
          .set({'roleIds': roleIds});

  Future<List<Map<String, dynamic>>> getOrgMemberProfiles(
      List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < memberIds.length; i += 30) {
      final chunk = memberIds.sublist(
          i, i + 30 > memberIds.length ? memberIds.length : i + 30);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        results.add({
          'id': doc.id,
          'displayName': d['displayName'] ?? '',
          'photoUrl': d['photoUrl'],
          'email': d['email'] ?? '',
        });
      }
    }
    return results;
  }

  Future<String> regenerateInviteToken(String orgId) async {
    final token = _uuid.v4().substring(0, 8).toUpperCase();
    await _db.collection('organizations').doc(orgId).update({'inviteToken': token});
    return token;
  }

  Future<OrganizationModel?> joinOrganizationByToken({
    required String token,
    required String userId,
    required String displayName,
  }) async {
    final snap = await _db
        .collection('organizations')
        .where('inviteToken', isEqualTo: token.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'members': FieldValue.arrayUnion([
        {'userId': userId, 'role': 'member'},
      ]),
    });

    final updated = await doc.reference.get();
    return OrganizationModel.fromDoc(updated);
  }

  // ── Shells ─────────────────────────────────────────────────────────────────

  Stream<List<ShellModel>> watchShells(String orgId) {
    return _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => ShellModel.fromDoc(d, orgId)).toList());
  }

  Future<ShellModel> createShell({
    required String orgId,
    required String name,
    String? description,
  }) async {
    final ref = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .add({
          'name': name,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
        });
    // Seed a General category + general channel
    final catRef = await ref.collection('categories').add({
      'name': 'General',
      'position': 0,
    });
    await catRef.collection('channels').add({
      'name': 'general',
      'type': 'text',
      'position': 0,
      'parentChannelId': null,
      'topic': null,
    });
    final doc = await ref.get();
    return ShellModel.fromDoc(doc, orgId);
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  Stream<List<CategoryModel>> watchCategories(String orgId, String shellId) {
    return _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .orderBy('position')
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map((d) => CategoryModel.fromDoc(d, shellId, orgId))
                  .toList(),
        );
  }

  Future<void> createCategory({
    required String orgId,
    required String shellId,
    required String name,
    required int position,
  }) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .add({'name': name, 'position': position});
  }

  Future<void> updateCategory({
    required String orgId,
    required String shellId,
    required String categoryId,
    String? name,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .update(updates);
  }

  Future<void> deleteCategory({
    required String orgId,
    required String shellId,
    required String categoryId,
  }) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  // ── Channels ───────────────────────────────────────────────────────────────

  Stream<List<ChannelModel>> watchChannels(
    String orgId,
    String shellId,
    String categoryId,
  ) {
    return _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .collection('channels')
        .orderBy('position')
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map(
                    (d) => ChannelModel.fromDoc(d, categoryId, shellId, orgId),
                  )
                  .toList(),
        );
  }

  Future<ChannelModel> createChannel({
    required String orgId,
    required String shellId,
    required String categoryId,
    required String name,
    ChannelType type = ChannelType.text,
    String? parentChannelId,
    int position = 0,
  }) async {
    final ref = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .collection('channels')
        .add({
          'name': name,
          'type': type.name,
          'position': position,
          'parentChannelId': parentChannelId,
          'topic': null,
        });
    final doc = await ref.get();
    return ChannelModel.fromDoc(doc, categoryId, shellId, orgId);
  }

  Future<void> updateChannel({
    required String orgId,
    required String shellId,
    required String categoryId,
    required String channelId,
    String? name,
    String? topic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (topic != null) updates['topic'] = topic;
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .collection('channels')
        .doc(channelId)
        .update(updates);
  }

  Future<void> deleteChannel({
    required String orgId,
    required String shellId,
    required String categoryId,
    required String channelId,
  }) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('shells')
        .doc(shellId)
        .collection('categories')
        .doc(categoryId)
        .collection('channels')
        .doc(channelId)
        .delete();
  }

  // ── Direct Messages ────────────────────────────────────────────────────────

  Stream<List<DmModel>> watchUserDms(String userId) => _db
      .collection('dms')
      .where('participantIds', arrayContains: userId)
      .snapshots()
      .map((s) {
        final dms = s.docs.map(DmModel.fromDoc).toList();
        dms.sort((a, b) {
          final at = a.lastMessageAt;
          final bt = b.lastMessageAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        return dms;
      });

  Future<DmModel> openOrCreateDm({
    required String myUid,
    required String myName,
    required String? myPhoto,
    required String theirUid,
    required String theirName,
    required String? theirPhoto,
  }) async {
    final dmId = DmModel.makeId(myUid, theirUid);
    final ref = _db.collection('dms').doc(dmId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participantIds': [myUid, theirUid],
        'participants': [
          DmParticipant(uid: myUid, displayName: myName, photoUrl: myPhoto)
              .toMap(),
          DmParticipant(uid: theirUid, displayName: theirName, photoUrl: theirPhoto)
              .toMap(),
        ],
        'lastMessage': null,
        'lastMessageAt': null,
      });
    }
    final doc = await ref.get();
    return DmModel.fromDoc(doc);
  }

  Future<void> updateDmLastMessage({
    required String dmId,
    required String lastMessage,
  }) =>
      _db.collection('dms').doc(dmId).update({
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

  // ── Typing ─────────────────────────────────────────────────────────────────

  CollectionReference _typing(String channelId) =>
      _db.collection('channels').doc(channelId).collection('typing');

  Future<void> setTyping({
    required String channelId,
    required String userId,
    required String displayName,
  }) =>
      _typing(channelId).doc(userId).set({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> clearTyping({
    required String channelId,
    required String userId,
  }) =>
      _typing(channelId).doc(userId).delete();

  Stream<List<String>> watchTyping(String channelId, String currentUserId) {
    return _typing(channelId).snapshots().map((snap) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
      return snap.docs
          .where((d) => d.id != currentUserId)
          .where((d) {
            final ts = ((d.data() as Map<String, dynamic>)['updatedAt']
                    as Timestamp?)
                ?.toDate();
            return ts == null || ts.isAfter(cutoff);
          })
          .map((d) =>
              (d.data() as Map<String, dynamic>)['displayName'] as String? ??
              'Someone')
          .toList();
    });
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  // Messages live at a global path keyed by channelId for simplicity
  CollectionReference _messages(String channelId) =>
      _db.collection('channels').doc(channelId).collection('messages');

  Stream<List<MessageModel>> watchMessages(
    String channelId, {
    int limit = 50,
  }) {
    return _messages(channelId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map((d) => MessageModel.fromDoc(d))
                  .toList()
                  .reversed
                  .toList(),
        );
  }

  Future<List<MessageModel>> loadMoreMessages(
    String channelId, {
    required DocumentSnapshot lastDoc,
    int limit = 50,
  }) async {
    final snap = await _messages(channelId)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => MessageModel.fromDoc(d))
        .toList()
        .reversed
        .toList();
  }

  Future<DocumentSnapshot?> getMessageDoc(
    String channelId,
    String messageId,
  ) async {
    final doc = await _messages(channelId).doc(messageId).get();
    return doc.exists ? doc : null;
  }

  Future<void> sendMessage({
    required String channelId,
    required String content,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    String? replyToId,
    String? replyToContent,
    String? replyToAuthorName,
    String? replyToAuthorId,
    List<String> imageUrls = const [],
  }) async {
    await _messages(channelId).add({
      'channelId': channelId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': [],
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'replyToAuthorName': replyToAuthorName,
      'replyToAuthorId': replyToAuthorId,
      'imageUrls': imageUrls,
      'isEdited': false,
      'editedAt': null,
    });
  }

  Future<void> editMessage({
    required String channelId,
    required String messageId,
    required String newContent,
  }) async {
    await _messages(channelId).doc(messageId).update({
      'content': newContent,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String channelId,
    required String messageId,
  }) async {
    await _messages(channelId).doc(messageId).delete();
  }

  Future<void> toggleReaction({
    required String channelId,
    required String messageId,
    required String emoji,
    required String userId,
    required bool add,
  }) async {
    final doc = _messages(channelId).doc(messageId);
    final snap = await doc.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final rawReactions = List<Map<String, dynamic>>.from(
      (data['reactions'] as List<dynamic>? ?? []).map(
        (r) => Map<String, dynamic>.from(r as Map),
      ),
    );

    final idx = rawReactions.indexWhere((r) => r['emoji'] == emoji);
    if (idx == -1 && add) {
      rawReactions.add({'emoji': emoji, 'userIds': [userId]});
    } else if (idx != -1) {
      final users = List<String>.from(rawReactions[idx]['userIds'] ?? []);
      if (add) {
        if (!users.contains(userId)) users.add(userId);
      } else {
        users.remove(userId);
      }
      if (users.isEmpty) {
        rawReactions.removeAt(idx);
      } else {
        rawReactions[idx]['userIds'] = users;
      }
    }

    await doc.update({'reactions': rawReactions});
  }
}
