import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

class EmojiReactionBar extends ConsumerWidget {
  final MessageModel message;
  final String channelId;

  const EmojiReactionBar({
    super.key,
    required this.message,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.uid ?? '';

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: message.reactions.map((reaction) {
        final reacted = reaction.userIds.contains(userId);
        return _ReactionChip(
          emoji: reaction.emoji,
          count: reaction.userIds.length,
          reacted: reacted,
          onTap: () => ref.read(firestoreServiceProvider).toggleReaction(
            channelId: channelId,
            messageId: message.id,
            emoji: reaction.emoji,
            userId: userId,
            add: !reacted,
          ),
        );
      }).toList(),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool reacted;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.reacted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: reacted ? SlekkeColors.mentionBg : SlekkeColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reacted ? SlekkeColors.mention : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: reacted ? SlekkeColors.mention : SlekkeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
