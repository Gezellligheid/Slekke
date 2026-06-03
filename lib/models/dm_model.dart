import 'package:cloud_firestore/cloud_firestore.dart';

class DmParticipant {
  final String uid;
  final String displayName;
  final String? photoUrl;

  const DmParticipant({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });

  factory DmParticipant.fromMap(Map<String, dynamic> m) => DmParticipant(
        uid: m['uid'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        photoUrl: m['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };
}

class DmModel {
  final String id;
  final List<DmParticipant> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  const DmModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
  });

  // Stable ID: sort UIDs so A→B and B→A always produce the same document
  static String makeId(String a, String b) {
    final parts = [a, b]..sort();
    return parts.join('__');
  }

  DmParticipant other(String myUid) =>
      participants.firstWhere((p) => p.uid != myUid,
          orElse: () => participants.first);

  factory DmModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawParts = (d['participants'] as List<dynamic>?) ?? [];
    return DmModel(
      id: doc.id,
      participants: rawParts
          .map((p) => DmParticipant.fromMap(p as Map<String, dynamic>))
          .toList(),
      lastMessage: d['lastMessage'] as String?,
      lastMessageAt:
          (d['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}
