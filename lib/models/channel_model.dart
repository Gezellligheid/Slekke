import 'package:cloud_firestore/cloud_firestore.dart';

enum ChannelType { text, voice }

class ChannelModel {
  final String id;
  final String categoryId;
  final String shellId;
  final String organizationId;
  final String name;
  final ChannelType type;
  final int position;
  final String? parentChannelId;
  final String? topic;
  final String? githubRepo;

  const ChannelModel({
    required this.id,
    required this.categoryId,
    required this.shellId,
    required this.organizationId,
    required this.name,
    required this.type,
    required this.position,
    this.parentChannelId,
    this.topic,
    this.githubRepo,
  });

  factory ChannelModel.fromDoc(
    DocumentSnapshot doc,
    String categoryId,
    String shellId,
    String orgId,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    return ChannelModel(
      id: doc.id,
      categoryId: categoryId,
      shellId: shellId,
      organizationId: orgId,
      name: d['name'] ?? '',
      type: d['type'] == 'voice' ? ChannelType.voice : ChannelType.text,
      position: d['position'] ?? 0,
      parentChannelId: d['parentChannelId'],
      topic: d['topic'],
      githubRepo: d['githubRepo'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'position': position,
    'parentChannelId': parentChannelId,
    'topic': topic,
  };
}
