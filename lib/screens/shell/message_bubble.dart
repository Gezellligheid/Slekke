import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../models/message_model.dart';
import '../../models/settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/settings_provider.dart';
import 'emoji_reaction_bar.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool grouped;
  final String channelId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.grouped,
    required this.channelId,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _hovered = false;
  bool _editing = false;
  final _editCtrl = TextEditingController();

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final currentUser = ref.watch(currentUserProvider);
    final isOwn = currentUser?.uid == msg.authorId;
    final density = ref.watch(settingsProvider.select((s) => s.messageDensity));

    final (topGrouped, topFirst, bottom) = switch (density) {
      MessageDensity.compact     => (1.0, 8.0, 1.0),
      MessageDensity.comfortable => (2.0, 16.0, 2.0),
      MessageDensity.spacious    => (4.0, 24.0, 4.0),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? SlekkeColors.elevated.withAlpha(40) : Colors.transparent,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: widget.grouped ? topGrouped : topFirst,
          bottom: bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar or spacer
            if (!widget.grouped)
              _Avatar(photoUrl: msg.authorPhotoUrl, name: msg.authorName)
            else
              const SizedBox(width: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply reference
                  if (msg.replyToId != null) _ReplyPreview(message: msg),
                  // Author + timestamp
                  if (!widget.grouped)
                    Row(
                      children: [
                        Text(
                          msg.authorName,
                          style: const TextStyle(
                            color: SlekkeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(msg.timestamp),
                          style: const TextStyle(
                            color: SlekkeColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  // Content
                  if (_editing)
                    _EditField(
                      initial: msg.content,
                      onSave: (newContent) async {
                        await ref.read(firestoreServiceProvider).editMessage(
                          channelId: widget.channelId,
                          messageId: msg.id,
                          newContent: newContent,
                        );
                        setState(() => _editing = false);
                      },
                      onCancel: () => setState(() => _editing = false),
                    )
                  else
                    MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: SlekkeColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        code: const TextStyle(
                          color: SlekkeColors.textPrimary,
                          backgroundColor: SlekkeColors.inputBg,
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: SlekkeColors.inputBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  if (msg.isEdited)
                    const Text(
                      '(edited)',
                      style: TextStyle(color: SlekkeColors.textMuted, fontSize: 10),
                    ),
                  // Images
                  if (msg.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: msg.imageUrls.map((url) => _ImageAttachment(url: url)).toList(),
                      ),
                    ),
                  // Reactions
                  if (msg.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: EmojiReactionBar(
                        message: msg,
                        channelId: widget.channelId,
                      ),
                    ),
                ],
              ),
            ),
            // Action toolbar (on hover)
            if (!_editing)
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: _MessageActions(
                  message: msg,
                  isOwn: isOwn,
                  channelId: widget.channelId,
                  onEdit: () => setState(() => _editing = true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  const _Avatar({this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SlekkeColors.elevated,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: SlekkeColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ReplyPreview extends ConsumerWidget {
  final MessageModel message;
  const _ReplyPreview({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final isToMe = message.replyToAuthorId != null &&
        message.replyToAuthorId == currentUid;

    final borderColor =
        isToMe ? SlekkeColors.success : SlekkeColors.textMuted;
    final bgColor = isToMe
        ? SlekkeColors.success.withAlpha(18)
        : SlekkeColors.elevated.withAlpha(60);
    final nameColor =
        isToMe ? SlekkeColors.success : SlekkeColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: borderColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 13, color: borderColor.withAlpha(180)),
          const SizedBox(width: 5),
          Text(
            isToMe ? 'you' : (message.replyToAuthorName ?? ''),
            style: TextStyle(
              color: nameColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message.replyToContent ?? '',
              style: TextStyle(
                color: isToMe
                    ? SlekkeColors.textSecondary
                    : SlekkeColors.textMuted,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatefulWidget {
  final String initial;
  final Future<void> Function(String) onSave;
  final VoidCallback onCancel;

  const _EditField({
    required this.initial,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_EditField> createState() => _EditFieldState();
}

class _EditFieldState extends State<_EditField> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          style: const TextStyle(color: SlekkeColors.textPrimary, fontSize: 14),
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel', style: TextStyle(color: SlekkeColors.textMuted, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(text);
  }
}

class _ImageAttachment extends StatelessWidget {
  final String url;
  const _ImageAttachment({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 240,
        fit: BoxFit.cover,
        placeholder: (ctx, progress) => Container(
          width: 240,
          height: 160,
          color: SlekkeColors.inputBg,
        ),
      ),
    );
  }
}

class _MessageActions extends ConsumerWidget {
  final MessageModel message;
  final bool isOwn;
  final String channelId;
  final VoidCallback onEdit;

  const _MessageActions({
    required this.message,
    required this.isOwn,
    required this.channelId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final canDelete = isOwn || perms.manageMessages;

    return Container(
      decoration: BoxDecoration(
        color: SlekkeColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SlekkeColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            icon: Icons.emoji_emotions_outlined,
            tooltip: 'Add reaction',
            onTap: () => _pickEmoji(context, ref),
          ),
          _ActionBtn(
            icon: Icons.reply,
            tooltip: 'Reply',
            onTap: () {
              ref.read(replyToMessageProvider.notifier).state = message;
            },
          ),
          if (isOwn)
            _ActionBtn(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: onEdit),
          if (canDelete)
            _ActionBtn(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              onTap: () => _delete(context, ref),
            ),
        ],
      ),
    );
  }

  void _pickEmoji(BuildContext context, WidgetRef ref) {
    final userId = ref.read(currentUserProvider)?.uid ?? '';
    final firestoreService = ref.read(firestoreServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) => _QuickEmojiDialog(
        onSelect: (emoji) async {
          Navigator.of(ctx).pop();
          await firestoreService.toggleReaction(
            channelId: channelId,
            messageId: message.id,
            emoji: emoji,
            userId: userId,
            add: true,
          );
        },
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlekkeColors.surface,
        title: const Text('Delete message?', style: TextStyle(color: SlekkeColors.textPrimary)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: SlekkeColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: SlekkeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SlekkeColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await firestoreService.deleteMessage(
        channelId: channelId,
        messageId: message.id,
      );
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: SlekkeColors.textSecondary),
        ),
      ),
    );
  }
}

class _QuickEmojiDialog extends StatelessWidget {
  final void Function(String) onSelect;
  static const _emojis = [
    '👍', '❤️', '😂', '😮', '😢', '😡',
    '🎉', '🔥', '✅', '👀', '🙏', '💯',
  ];

  const _QuickEmojiDialog({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SlekkeColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis.map(
            (e) => InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onSelect(e),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }
}
