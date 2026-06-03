import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dm_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import '../shell/message_bubble.dart';
import '../shell/message_input.dart';
import '../shell/typing_indicator.dart';

class DmConversationView extends ConsumerStatefulWidget {
  final DmModel dm;
  const DmConversationView({super.key, required this.dm});

  @override
  ConsumerState<DmConversationView> createState() =>
      _DmConversationViewState();
}

class _DmConversationViewState extends ConsumerState<DmConversationView> {
  final _scrollCtrl = ScrollController();
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      _atBottom = _scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 80;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final other = widget.dm.other(myUid);
    final messagesAsync = ref.watch(messagesProvider(widget.dm.id));
    final replyTo = ref.watch(replyToMessageProvider);

    ref.listen(messagesProvider(widget.dm.id), (prev, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_atBottom && _scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    });

    return Container(
      color: SlekkeColors.surfaceVariant,
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SlekkeColors.elevated,
                        image: other.photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(other.photoUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: other.photoUrl == null
                          ? Text(
                              other.displayName.isNotEmpty
                                  ? other.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: SlekkeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Text(
                  other.displayName,
                  style: const TextStyle(
                    color: SlekkeColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: SlekkeColors.primary)),
              error: (e, _) => Center(
                  child: Text('$e',
                      style:
                          const TextStyle(color: SlekkeColors.danger))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SlekkeColors.elevated,
                            image: other.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(other.photoUrl!),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: other.photoUrl == null
                              ? Text(
                                  other.displayName.isNotEmpty
                                      ? other.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: SlekkeColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700))
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a conversation with ${other.displayName}',
                          style: const TextStyle(
                              color: SlekkeColors.textSecondary,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final prev = i > 0 ? messages[i - 1] : null;
                    final isGrouped = prev != null &&
                        prev.authorId == msg.authorId &&
                        msg.timestamp
                                .difference(prev.timestamp)
                                .inMinutes <
                            5;
                    return MessageBubble(
                      message: msg,
                      grouped: isGrouped,
                      channelId: widget.dm.id,
                    );
                  },
                );
              },
            ),
          ),
          TypingIndicator(channelId: widget.dm.id),
          if (replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: SlekkeColors.inputBg,
              child: Row(
                children: [
                  const Icon(Icons.reply,
                      size: 16, color: SlekkeColors.textMuted),
                  const SizedBox(width: 8),
                  Text('Replying to ${replyTo.authorName}',
                      style: const TextStyle(
                          color: SlekkeColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(replyTo.content,
                        style: const TextStyle(
                            color: SlekkeColors.textMuted,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: SlekkeColors.textMuted),
                    onPressed: () => ref
                        .read(replyToMessageProvider.notifier)
                        .state = null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          _DmMessageInput(dmId: widget.dm.id),
        ],
      ),
    );
  }
}

// DM message input — same as MessageInput but updates DM last message
class _DmMessageInput extends ConsumerStatefulWidget {
  final String dmId;
  const _DmMessageInput({required this.dmId});

  @override
  ConsumerState<_DmMessageInput> createState() => _DmMessageInputState();
}

class _DmMessageInputState extends ConsumerState<_DmMessageInput> {
  @override
  Widget build(BuildContext context) {
    // Reuse MessageInput — it uses channelId internally and works for DMs
    return MessageInput(channelId: widget.dmId);
  }
}
