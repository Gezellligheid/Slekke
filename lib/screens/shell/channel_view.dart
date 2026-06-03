import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/channel_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
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

    ref.listen(messagesProvider(channel.id), (prev, _) {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        ref.read(firestoreServiceProvider).markChannelRead(uid, channel.id);
      }
    });

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

class _ChannelHeader extends ConsumerWidget {
  final ChannelModel channel;
  const _ChannelHeader({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedMessagesProvider(channel.id));
    final pinnedCount = pinnedAsync.valueOrNull?.length ?? 0;

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
          ] else
            const Spacer(),
          if (pinnedCount > 0)
            Tooltip(
              message: '$pinnedCount pinned message${pinnedCount == 1 ? '' : 's'}',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _showPinnedPanel(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, size: 16, color: SlekkeColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$pinnedCount',
                        style: const TextStyle(
                          color: SlekkeColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPinnedPanel(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _PinnedMessagesPanel(channel: channel),
    );
  }
}

class _PinnedMessagesPanel extends ConsumerWidget {
  final ChannelModel channel;
  const _PinnedMessagesPanel({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedMessagesProvider(channel.id));
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final canUnpin = org?.ownerId == currentUid || perms.manageMessages;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Container(
          decoration: BoxDecoration(
            color: SlekkeColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SlekkeColors.elevated),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16, color: SlekkeColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Pinned in #${channel.name}',
                      style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: SlekkeColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: SlekkeColors.divider),
              // List
              Expanded(
                child: pinnedAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: SlekkeColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('$e',
                        style: const TextStyle(color: SlekkeColors.danger)),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('No pinned messages',
                            style: TextStyle(color: SlekkeColors.textMuted)),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: SlekkeColors.divider),
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SlekkeColors.elevated,
                                  image: msg.authorPhotoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(msg.authorPhotoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: msg.authorPhotoUrl == null
                                    ? Text(
                                        msg.authorName.isNotEmpty
                                            ? msg.authorName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: SlekkeColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          msg.authorName,
                                          style: const TextStyle(
                                            color: SlekkeColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(msg.timestamp),
                                          style: const TextStyle(
                                            color: SlekkeColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      msg.content,
                                      style: const TextStyle(
                                        color: SlekkeColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canUnpin)
                                Tooltip(
                                  message: 'Unpin',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => ref
                                        .read(firestoreServiceProvider)
                                        .togglePinMessage(
                                          channelId: channel.id,
                                          messageId: msg.id,
                                          pin: false,
                                        ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.push_pin_outlined,
                                          size: 16, color: SlekkeColors.textMuted),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
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
  List<MessageModel> _older = [];
  bool _loadingMore = false;
  bool _noMore = false;

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
  void didUpdateWidget(_MessageList old) {
    super.didUpdateWidget(old);
    // Clear cached older messages when switching channels
    if (old.channelId != widget.channelId) {
      _older = [];
      _noMore = false;
    }
    if (widget.messages.length > old.messages.length &&
        old.messages.isNotEmpty) {
      ref
          .read(notificationServiceProvider)
          .onNewMessage(channelId: widget.channelId);
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
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    _atBottom = pos.pixels >= pos.maxScrollExtent - 80;
    if (!_loadingMore && !_noMore && pos.pixels <= 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final all = [..._older, ...widget.messages];
    if (all.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await ref
          .read(firestoreServiceProvider)
          .loadMoreMessages(widget.channelId, before: all.first.timestamp);
      if (!mounted) return;
      if (more.isEmpty) {
        setState(() => _noMore = true);
      } else {
        final prevExtent = _scrollCtrl.hasClients
            ? _scrollCtrl.position.maxScrollExtent
            : 0.0;
        setState(() => _older = [...more, ..._older]);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollCtrl.hasClients) return;
          final added = _scrollCtrl.position.maxScrollExtent - prevExtent;
          _scrollCtrl.jumpTo(_scrollCtrl.offset + added);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._older, ...widget.messages];
    if (all.isEmpty) {
      return const Center(
        child: Text('No messages yet. Say hello!',
            style: TextStyle(color: SlekkeColors.textMuted)),
      );
    }

    final hasHeader = _loadingMore || _noMore;

    return ListView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.only(top: hasHeader ? 0 : 16, bottom: 16),
      itemCount: all.length + (hasHeader ? 1 : 0),
      itemBuilder: (_, i) {
        if (hasHeader && i == 0) {
          return _loadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: SlekkeColors.textMuted),
                    ),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Beginning of conversation',
                        style: TextStyle(
                            color: SlekkeColors.textMuted, fontSize: 11)),
                  ),
                );
        }
        final msgIdx = i - (hasHeader ? 1 : 0);
        final msg = all[msgIdx];
        final prev = msgIdx > 0 ? all[msgIdx - 1] : null;
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
