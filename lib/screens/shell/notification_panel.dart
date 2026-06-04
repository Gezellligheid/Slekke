import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

void showNotificationPanel(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogCtx) => Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogCtx).pop(),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 208,
          bottom: 8,
          child: _NotificationPanel(
            onClose: () => Navigator.of(dialogCtx).pop(),
          ),
        ),
      ],
    ),
  );
}

class _NotificationPanel extends ConsumerWidget {
  final VoidCallback onClose;
  const _NotificationPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(selectedOrgIdProvider);
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final dms = ref.watch(userDmsProvider).valueOrNull ?? [];
    final reads = ref.watch(userReadsProvider).valueOrNull ?? {};
    final activeDmId = ref.watch(selectedDmIdProvider);
    final dmMode = ref.watch(dmModeProvider);
    final activeChannelId = ref.watch(selectedChannelProvider)?.id;

    // DMs — use channels/{id} fallback for DMs without lastMessageAt set
    final unreadDms = dms.where((dm) {
      if (dmMode && dm.id == activeDmId) return false; // currently viewing
      if (dm.lastMessageAuthorId != null && dm.lastMessageAuthorId == myUid) return false;
      final channelAt =
          ref.watch(channelLastMessageAtProvider(dm.id)).valueOrNull;
      final effectiveAt = dm.lastMessageAt ?? channelAt;
      final lastRead = reads['dm_${dm.id}'];
      return effectiveAt != null &&
          (lastRead == null || effectiveAt.isAfter(lastRead));
    }).toList();

    // Channels — only real channels (shellId non-empty excludes leaked DM docs)
    final allChannelNotifs = orgId != null
        ? (ref.watch(orgChannelNotifsProvider(orgId)).valueOrNull ?? [])
        : <ChannelNotifEntry>[];

    final unreadChannels = allChannelNotifs.where((e) {
      if (e.shellId.isEmpty) return false; // DM doc leaked in — skip
      if (!dmMode && e.channelId == activeChannelId) return false; // currently viewing
      if (e.lastMessageAuthorId != null && e.lastMessageAuthorId == myUid) return false;
      final lastRead = reads[e.channelId];
      return lastRead == null || e.lastMessageAt.isAfter(lastRead);
    }).toList();

    final hasAny = unreadDms.isNotEmpty || unreadChannels.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: SlekkeColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SlekkeColors.elevated),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(160),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'NOTIFICATIONS',
                      style: TextStyle(
                        color: SlekkeColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (hasAny)
                    GestureDetector(
                      onTap: () => _clearAll(ref, unreadDms
                          .map((d) => d.id)
                          .toList(), unreadChannels),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          color: SlekkeColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: SlekkeColors.divider),
            // Content
            if (!hasAny)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'You\'re all caught up',
                    style: TextStyle(
                        color: SlekkeColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    if (unreadDms.isNotEmpty) ...[
                      _SectionLabel(label: 'Direct Messages'),
                      ...unreadDms.map((dm) {
                        final other = dm.other(myUid);
                        return _NotifRow(
                          icon: Icons.chat_bubble_outline,
                          title: other.displayName,
                          subtitle: dm.lastMessage,
                          time: dm.lastMessageAt,
                          photoUrl: other.photoUrl,
                          onTap: () {
                            onClose();
                            ref
                                .read(dmModeProvider.notifier)
                                .state = true;
                            ref
                                .read(selectedDmIdProvider.notifier)
                                .state = dm.id;
                            _markDmRead(ref, dm.id);
                          },
                        );
                      }),
                    ],
                    if (unreadChannels.isNotEmpty) ...[
                      _SectionLabel(label: 'Channels'),
                      ...unreadChannels.map((entry) => _NotifRow(
                            icon: Icons.tag,
                            title: '#${entry.channelName}',
                            subtitle: entry.shellName.isNotEmpty
                                ? entry.shellName
                                : null,
                            time: entry.lastMessageAt,
                            onTap: () async {
                              onClose();
                              await _navigateToChannel(ref, entry);
                            },
                          )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _clearAll(WidgetRef ref, List<String> dmIds,
      List<ChannelNotifEntry> channels) {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    ref.read(firestoreServiceProvider).batchMarkRead(
          uid: uid,
          channelIds: channels.map((c) => c.channelId).toList(),
          dmIds: dmIds,
        );
  }

  void _markDmRead(WidgetRef ref, String dmId) {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    ref.read(firestoreServiceProvider).markDmRead(uid, dmId);
  }

  Future<void> _navigateToChannel(
      WidgetRef ref, ChannelNotifEntry entry) async {
    ref.read(dmModeProvider.notifier).state = false;
    ref.read(selectedOrgIdProvider.notifier).state = entry.orgId;
    ref.read(selectedShellIdProvider.notifier).state = entry.shellId;
    ref.read(selectedChannelStateProvider.notifier).state = null;

    if (entry.categoryId.isNotEmpty) {
      final channel = await ref
          .read(firestoreServiceProvider)
          .getChannelById(
            orgId: entry.orgId,
            shellId: entry.shellId,
            categoryId: entry.categoryId,
            channelId: entry.channelId,
          );
      if (channel != null) {
        ref.read(selectedChannelStateProvider.notifier).state = channel;
      }
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid != null) {
      ref
          .read(firestoreServiceProvider)
          .markChannelRead(uid, entry.channelId);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: SlekkeColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NotifRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? photoUrl;
  final DateTime? time;
  final VoidCallback onTap;

  const _NotifRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.photoUrl,
    this.time,
    required this.onTap,
  });

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(80)
              : Colors.transparent,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              widget.photoUrl != null
                  ? UserAvatar(photoUrl: widget.photoUrl, name: '', size: 28)
                  : Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SlekkeColors.elevated,
                      ),
                      alignment: Alignment.center,
                      child: Icon(widget.icon,
                          size: 14, color: SlekkeColors.textMuted),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          color: SlekkeColors.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (widget.time != null)
                Text(
                  timeago.format(widget.time!, locale: 'en_short'),
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
