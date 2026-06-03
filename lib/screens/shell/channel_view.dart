import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/channel_model.dart';
import '../../models/message_model.dart';
import '../../providers/firestore_provider.dart';
import '../../services/notification_service.dart';
import 'message_bubble.dart';
import 'message_input.dart';
import 'typing_indicator.dart';

class ChannelView extends ConsumerWidget {
  final ChannelModel channel;
  const ChannelView({super.key, required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(channel.id));
    final replyTo = ref.watch(replyToMessageProvider);

    return Container(
      color: SlekkeColors.surfaceVariant,
      child: Column(
        children: [
          _ChannelHeader(channel: channel),
          const Divider(height: 1, color: SlekkeColors.divider),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: SlekkeColors.primary),
              ),
              error: (e, _) => Center(
                child: Text('$e', style: const TextStyle(color: SlekkeColors.danger)),
              ),
              data: (messages) => _MessageList(
                key: ValueKey(channel.id),
                messages: messages,
                channelId: channel.id,
              ),
            ),
          ),
          TypingIndicator(channelId: channel.id),
          if (replyTo != null) _ReplyBanner(message: replyTo),
          MessageInput(channelId: channel.id),
        ],
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  final ChannelModel channel;
  const _ChannelHeader({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            channel.type == ChannelType.voice ? Icons.volume_up : Icons.tag,
            color: SlekkeColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            channel.name,
            style: const TextStyle(
              color: SlekkeColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (channel.topic != null && channel.topic!.isNotEmpty) ...[
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: SlekkeColors.divider,
            ),
            Expanded(
              child: Text(
                channel.topic!,
                style: const TextStyle(
                  color: SlekkeColors.textSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerStatefulWidget {
  final List<MessageModel> messages;
  final String channelId;

  const _MessageList({super.key, required this.messages, required this.channelId});

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  final _scrollCtrl = ScrollController();
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    _atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 80;
  }

  @override
  void didUpdateWidget(_MessageList old) {
    super.didUpdateWidget(old);
    if (widget.messages.length > old.messages.length) {
      // Notify only for genuinely new messages (not initial load)
      if (old.messages.isNotEmpty) {
        ref.read(notificationServiceProvider).onNewMessage(
              channelId: widget.channelId,
            );
      }
      if (_atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say hello!',
          style: TextStyle(color: SlekkeColors.textMuted),
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
            msg.timestamp.difference(prev.timestamp).inMinutes < 5;
        return MessageBubble(
          message: msg,
          grouped: isGrouped,
          channelId: widget.channelId,
        );
      },
    );
  }
}

class _ReplyBanner extends ConsumerWidget {
  final MessageModel message;
  const _ReplyBanner({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: SlekkeColors.inputBg,
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: SlekkeColors.textMuted),
          const SizedBox(width: 8),
          Text(
            'Replying to ${message.authorName}',
            style: const TextStyle(color: SlekkeColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content,
              style: const TextStyle(color: SlekkeColors.textMuted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: SlekkeColors.textMuted),
            onPressed: () => ref.read(replyToMessageProvider.notifier).state = null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
