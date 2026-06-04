import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/dm_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import 'new_dm_dialog.dart';

class DmSidebar extends ConsumerWidget {
  const DmSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmsAsync = ref.watch(userDmsProvider);
    final selectedDmId = ref.watch(selectedDmIdProvider);

    return Container(
      width: 240,
      color: SlekkeColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Direct Messages',
                    style: TextStyle(
                      color: SlekkeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'New message',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => showNewDmDialog(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: SlekkeColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          Expanded(
            child: dmsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: SlekkeColors.primary)),
              error: (e, _) => Center(
                  child: Text('$e',
                      style:
                          const TextStyle(color: SlekkeColors.danger))),
              data: (dms) {
                if (dms.isEmpty) {
                  return const Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(
                          color: SlekkeColors.textMuted, fontSize: 12),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: dms
                      .map((dm) => _DmTile(
                            dm: dm,
                            selected: dm.id == selectedDmId,
                            onTap: () {
                              ref
                                  .read(selectedDmIdProvider.notifier)
                                  .state = dm.id;
                            },
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DmTile extends ConsumerStatefulWidget {
  final DmModel dm;
  final bool selected;
  final VoidCallback onTap;

  const _DmTile(
      {required this.dm, required this.selected, required this.onTap});

  @override
  ConsumerState<_DmTile> createState() => _DmTileState();
}

class _DmTileState extends ConsumerState<_DmTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final other = widget.dm.other(myUid);
    // Watch the other participant's live profile for real-time avatar updates
    final liveOtherProfile =
        ref.watch(userProfileProvider(other.uid)).valueOrNull;
    final otherPhotoUrl = liveOtherProfile?.photoUrl ?? other.photoUrl;
    final otherDisplayName = liveOtherProfile?.displayName ?? other.displayName;
    final reads = ref.watch(userReadsProvider).valueOrNull ?? {};
    final lastReadAt = reads['dm_${widget.dm.id}'];
    // Use dms/{id}.lastMessageAt if set; fall back to channels/{id}.lastMessageAt
    // (sendMessage always writes the flat channels doc, so this covers older DMs too).
    final channelLastMsgAt =
        ref.watch(channelLastMessageAtProvider(widget.dm.id)).valueOrNull;
    final effectiveLastMsgAt = widget.dm.lastMessageAt ?? channelLastMsgAt;
    final hasUnread = !widget.selected &&
        effectiveLastMsgAt != null &&
        (lastReadAt == null || effectiveLastMsgAt.isAfter(lastReadAt));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          widget.onTap();
          final uid = ref.read(currentUserProvider)?.uid;
          if (uid != null) {
            ref.read(firestoreServiceProvider).markDmRead(uid, widget.dm.id);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? SlekkeColors.channelSelected
                : _hovered
                    ? SlekkeColors.elevated.withAlpha(80)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              UserAvatar(
                photoUrl: otherPhotoUrl,
                name: otherDisplayName,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      otherDisplayName,
                      style: TextStyle(
                        color: widget.selected || hasUnread
                            ? SlekkeColors.textPrimary
                            : SlekkeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: widget.selected || hasUnread
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.dm.lastMessage != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.dm.lastMessage!,
                        style: const TextStyle(
                            color: SlekkeColors.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SlekkeColors.primary,
                  ),
                )
              else if (widget.dm.lastMessageAt != null)
                Text(
                  timeago.format(widget.dm.lastMessageAt!,
                      locale: 'en_short'),
                  style: const TextStyle(
                      color: SlekkeColors.textMuted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
