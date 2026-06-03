import 'package:cloud_firestore/cloud_firestore.dart';

class Reaction {
  final String emoji;
  final List<String> userIds;

  const Reaction({required this.emoji, required this.userIds});

  factory Reaction.fromMap(Map<String, dynamic> m) => Reaction(
    emoji: m['emoji'] ?? '',
    userIds: List<String>.from(m['userIds'] ?? []),
  );

  Map<String, dynamic> toMap() => {'emoji': emoji, 'userIds': userIds};
}

class MessageModel {
  final String id;
  final String channelId;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime timestamp;
  final List<Reaction> reactions;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToAuthorName;
  final String? replyToAuthorId;
  final List<String> imageUrls;
  final bool isEdited;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    required this.channelId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.timestamp,
    this.reactions = const [],
    this.replyToId,
    this.replyToContent,
    this.replyToAuthorName,
    this.replyToAuthorId,
    this.imageUrls = const [],
    this.isEdited = false,
    this.editedAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawReactions = (d['reactions'] as List<dynamic>?) ?? [];
    return MessageModel(
      id: doc.id,
      channelId: d['channelId'] ?? '',
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      authorPhotoUrl: d['authorPhotoUrl'],
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: rawReactions
          .map((r) => Reaction.fromMap(r as Map<String, dynamic>))
          .toList(),
      replyToId: d['replyToId'],
      replyToContent: d['replyToContent'],
      replyToAuthorName: d['replyToAuthorName'],
      replyToAuthorId: d['replyToAuthorId'],
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
      isEdited: d['isEdited'] ?? false,
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'channelId': channelId,
    'content': content,
    'authorId': authorId,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'timestamp': Timestamp.fromDate(timestamp),
    'reactions': reactions.map((r) => r.toMap()).toList(),
    'replyToId': replyToId,
    'replyToContent': replyToContent,
    'replyToAuthorName': replyToAuthorName,
    'replyToAuthorId': replyToAuthorId,
    'imageUrls': imageUrls,
    'isEdited': isEdited,
    'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
  };

  MessageModel copyWith({
    String? content,
    List<Reaction>? reactions,
    bool? isEdited,
    DateTime? editedAt,
  }) => MessageModel(
    id: id,
    channelId: channelId,
    content: content ?? this.content,
    authorId: authorId,
    authorName: authorName,
    authorPhotoUrl: authorPhotoUrl,
    timestamp: timestamp,
    reactions: reactions ?? this.reactions,
    replyToId: replyToId,
    replyToContent: replyToContent,
    replyToAuthorName: replyToAuthorName,
    imageUrls: imageUrls,
    isEdited: isEdited ?? this.isEdited,
    editedAt: editedAt ?? this.editedAt,
  );
}
