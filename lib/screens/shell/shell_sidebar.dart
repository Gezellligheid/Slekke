import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/channel_model.dart';
import '../../models/category_model.dart';
import '../../core/widgets/context_menu.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/settings_provider.dart';

class ShellSidebar extends ConsumerWidget {
  const ShellSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedShellId = ref.watch(selectedShellIdProvider);
    final selectedShell = ref.watch(selectedShellProvider);
    final orgId = ref.watch(selectedOrgIdProvider)!;
    final compact = ref.watch(settingsProvider.select((s) => s.compactSidebar));
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final canManageShells = org?.ownerId == currentUid || perms.manageShells;

    return _ShellSidebarBody(
      orgId: orgId,
      selectedShellId: selectedShellId,
      shellName: selectedShell?.name,
      compact: compact,
      canManageShells: canManageShells,
    );
  }
}

class _ShellSidebarBody extends ConsumerWidget {
  final String orgId;
  final String? selectedShellId;
  final String? shellName;
  final bool compact;
  final bool canManageShells;

  const _ShellSidebarBody({
    required this.orgId,
    required this.selectedShellId,
    required this.shellName,
    required this.compact,
    required this.canManageShells,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? 200 : 240,
      color: SlekkeColors.surface,
      child: Column(
        children: [
          // Shell name header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                shellName ?? 'No shell selected',
                style: const TextStyle(
                  color: SlekkeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          Expanded(
            child: selectedShellId == null
                ? _OrgMembersPanel(orgId: orgId)
                : _CategoryList(orgId: orgId, shellId: selectedShellId!),
          ),
        ],
      ),
    );
  }

}

// ─── Org members panel (shown when no shell selected) ─────────────────────────

class _OrgMembersPanel extends ConsumerStatefulWidget {
  final String orgId;
  const _OrgMembersPanel({required this.orgId});

  @override
  ConsumerState<_OrgMembersPanel> createState() => _OrgMembersPanelState();
}

class _OrgMembersPanelState extends ConsumerState<_OrgMembersPanel> {
  List<Map<String, dynamic>>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final org = ref.read(selectedOrgProvider);
    if (org == null) return;
    final profiles = await ref
        .read(firestoreServiceProvider)
        .getOrgMemberProfiles(org.members.map((m) => m.userId).toList());
    if (mounted) setState(() => _profiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    if (_profiles == null) {
      return const Center(
          child:
              CircularProgressIndicator(color: SlekkeColors.primary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(
            'MEMBERS',
            style: TextStyle(
              color: SlekkeColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _profiles!.map((p) {
              final uid = p['id'] as String;
              final name = p['displayName'] as String? ?? uid;
              final photo = p['photoUrl'] as String?;
              final isMe = uid == myUid;
              return _MemberTile(
                uid: uid,
                displayName: name,
                photoUrl: photo,
                isMe: isMe,
                myUid: myUid,
                myName: ref.read(currentUserProvider)?.displayName ?? '',
                myPhoto: ref.read(currentUserProvider)?.photoURL,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends ConsumerStatefulWidget {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isMe;
  final String myUid;
  final String myName;
  final String? myPhoto;

  const _MemberTile({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.isMe,
    required this.myUid,
    required this.myName,
    required this.myPhoto,
  });

  @override
  ConsumerState<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends ConsumerState<_MemberTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.isMe ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isMe ? null : () => _openDm(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered && !widget.isMe
                ? SlekkeColors.elevated.withAlpha(80)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SlekkeColors.elevated,
                image: widget.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.photoUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: widget.photoUrl == null
                  ? Text(
                      widget.displayName.isNotEmpty
                          ? widget.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: SlekkeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isMe
                    ? '${widget.displayName} (you)'
                    : widget.displayName,
                style: TextStyle(
                  color: widget.isMe
                      ? SlekkeColors.textMuted
                      : SlekkeColors.textSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!widget.isMe && _hovered)
              const Icon(Icons.chevron_right,
                  size: 14, color: SlekkeColors.textMuted),
          ],
        ),    // Row
      ),      // AnimatedContainer
    ),        // GestureDetector
  );          // MouseRegion
  }

  Future<void> _openDm(BuildContext context) async {
    final dm = await ref.read(firestoreServiceProvider).openOrCreateDm(
          myUid: widget.myUid,
          myName: widget.myName,
          myPhoto: widget.myPhoto,
          theirUid: widget.uid,
          theirName: widget.displayName,
          theirPhoto: widget.photoUrl,
        );
    ref.read(dmModeProvider.notifier).state = true;
    ref.read(selectedDmIdProvider.notifier).state = dm.id;
  }
}

// ─── Categories ───────────────────────────────────────────────────────────────

class _CategoryList extends ConsumerWidget {
  final String orgId;
  final String shellId;

  const _CategoryList({required this.orgId, required this.shellId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final canManage = org?.ownerId == currentUid || perms.manageShells;

    return categoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: SlekkeColors.primary),
      ),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: SlekkeColors.danger))),
      data: (categories) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                categories
                    .map((cat) => _CategoryTile(
                          category: cat,
                          orgId: orgId,
                          shellId: shellId,
                        ))
                    .toList(),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (e.buttons == 2 && canManage) {
                  _showAddCategoryMenu(context, ref, e.position);
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryMenu(
      BuildContext context, WidgetRef ref, Offset position) async {
    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: const [
        ContextMenuItem(
          value: 'add_category',
          icon: Icons.create_new_folder_outlined,
          label: 'Add category',
        ),
      ],
    );
    if (!context.mounted || result != 'add_category') return;
    final name = await _nameDialog(context, 'New Category', 'Category name');
    if (name == null || name.isEmpty) return;
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    await ref.read(firestoreServiceProvider).createCategory(
          orgId: orgId,
          shellId: shellId,
          name: name,
          position: cats.length,
        );
  }
}

class _CategoryTile extends ConsumerStatefulWidget {
  final CategoryModel category;
  final String orgId;
  final String shellId;

  const _CategoryTile({
    required this.category,
    required this.orgId,
    required this.shellId,
  });

  @override
  ConsumerState<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends ConsumerState<_CategoryTile> {
  bool _collapsed = false;
  bool _headerHovered = false;

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider(widget.category.id));
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final canManage = org?.ownerId == currentUid || perms.manageShells;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _headerHovered = true),
          onExit: (_) => setState(() => _headerHovered = false),
          child: GestureDetector(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: _RightClickArea(
              enabled: canManage,
              onRightClick: (pos) => _showCategoryMenu(context, ref, pos),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                child: Row(
                  children: [
                    Icon(
                      _collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 16,
                      color: SlekkeColors.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        widget.category.name.toUpperCase(),
                        style: const TextStyle(
                          color: SlekkeColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canManage)
                      AnimatedOpacity(
                        opacity: _headerHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 100),
                        child: GestureDetector(
                          onTap: () => _addChannel(context, ref),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.add,
                              size: 14,
                              color: SlekkeColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!_collapsed)
          channelsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (channels) => Column(
              children: channels
                  .where((c) => c.parentChannelId == null)
                  .map((ch) => _ChannelTile(channel: ch, canManage: canManage))
                  .toList(),
            ),
          ),
      ],
    );
  }
  Future<void> _addChannel(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, 'New Channel', 'Channel name (no #)');
    if (name == null || name.isEmpty) return;
    final ch = await ref.read(firestoreServiceProvider).createChannel(
          orgId: widget.orgId,
          shellId: widget.shellId,
          categoryId: widget.category.id,
          name: name.toLowerCase().replaceAll(' ', '-'),
        );
    ref.read(selectedChannelStateProvider.notifier).state = ch;
  }

  void _showCategoryMenu(
      BuildContext context, WidgetRef ref, Offset position) async {
    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: [
        const ContextMenuItem(
          value: 'add_channel',
          icon: Icons.tag,
          label: 'Add channel',
        ),
        const ContextMenuItem(
          value: 'add_category',
          icon: Icons.create_new_folder_outlined,
          label: 'Add category',
        ),
        const ContextMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          label: 'Rename',
          dividerAbove: true,
        ),
        ContextMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete',
          color: SlekkeColors.danger,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (result) {
      case 'add_channel':
        final chName =
            await _nameDialog(context, 'New Channel', 'Channel name (no #)');
        if (chName == null || chName.isEmpty) return;
        final ch = await ref.read(firestoreServiceProvider).createChannel(
              orgId: widget.orgId,
              shellId: widget.shellId,
              categoryId: widget.category.id,
              name: chName.toLowerCase().replaceAll(' ', '-'),
            );
        ref.read(selectedChannelStateProvider.notifier).state = ch;
      case 'add_category':
        final catName =
            await _nameDialog(context, 'New Category', 'Category name');
        if (catName == null || catName.isEmpty) return;
        final cats = ref.read(categoriesProvider).valueOrNull ?? [];
        await ref.read(firestoreServiceProvider).createCategory(
              orgId: widget.orgId,
              shellId: widget.shellId,
              name: catName,
              position: cats.length,
            );
      case 'rename':
        final name = await _nameDialog(context, 'Rename Category', 'New name');
        if (name == null || name.isEmpty) return;
        await ref.read(firestoreServiceProvider).updateCategory(
              orgId: widget.orgId,
              shellId: widget.shellId,
              categoryId: widget.category.id,
              name: name,
            );
      case 'delete':
        final ok = await _confirmDelete(
          context,
          'Delete "${widget.category.name}"? All channels inside will also be removed.',
        );
        if (ok != true || !context.mounted) return;
        await ref.read(firestoreServiceProvider).deleteCategory(
              orgId: widget.orgId,
              shellId: widget.shellId,
              categoryId: widget.category.id,
            );
    }
  }
}

// ─── Channel tile ─────────────────────────────────────────────────────────────

class _ChannelTile extends ConsumerStatefulWidget {
  final ChannelModel channel;
  final bool canManage;
  const _ChannelTile({required this.channel, required this.canManage});

  @override
  ConsumerState<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends ConsumerState<_ChannelTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final isSelected = selectedChannel?.id == widget.channel.id;
    final compact = ref.watch(settingsProvider.select((s) => s.compactSidebar));
    final lastMessageAt = ref
        .watch(channelLastMessageAtProvider(widget.channel.id))
        .valueOrNull;
    final reads = ref.watch(userReadsProvider).valueOrNull ?? {};
    final lastReadAt = reads[widget.channel.id];
    final hasUnread = !isSelected &&
        lastMessageAt != null &&
        (lastReadAt == null || lastMessageAt.isAfter(lastReadAt));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _RightClickArea(
        enabled: true,
        onRightClick: (pos) => _showChannelSettings(context, ref, pos),
        child: GestureDetector(
          onTap: () {
            ref.read(selectedChannelStateProvider.notifier).state = widget.channel;
            final uid = ref.read(currentUserProvider)?.uid;
            if (uid != null) {
              ref.read(firestoreServiceProvider).markChannelRead(uid, widget.channel.id);
            }
          },
          child: Container(
          height: compact ? 28 : 34,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? SlekkeColors.channelSelected
                : _hovered
                    ? SlekkeColors.elevated.withAlpha(80)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.channel.type == ChannelType.voice
                    ? Icons.volume_up
                    : Icons.tag,
                size: 18,
                color: isSelected || hasUnread
                    ? SlekkeColors.textPrimary
                    : SlekkeColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.channel.name,
                  style: TextStyle(
                    color: isSelected || hasUnread
                        ? SlekkeColors.textPrimary
                        : SlekkeColors.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected || hasUnread
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SlekkeColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),  // _RightClickArea
    );
  }

  void _showChannelSettings(
      BuildContext context, WidgetRef ref, Offset position) async {
    final isOwner = ref.read(selectedOrgProvider)?.ownerId ==
        ref.read(currentUserProvider)?.uid;
    final perms = ref.read(currentUserOrgPermissionsProvider);
    final canManage = isOwner || perms.manageShells;

    final items = <ContextMenuItem<String>>[
      const ContextMenuItem(
        value: 'mark_read',
        icon: Icons.done_all,
        label: 'Mark as read',
      ),
      if (canManage) ...[
        ContextMenuItem(
          value: 'github',
          icon: Icons.code,
          label: widget.channel.githubRepo?.isNotEmpty == true
              ? 'Change GitHub repo'
              : 'Connect GitHub repo',
          dividerAbove: true,
        ),
        if (widget.channel.githubRepo?.isNotEmpty == true)
          const ContextMenuItem(
            value: 'github_disconnect',
            icon: Icons.link_off,
            label: 'Disconnect GitHub repo',
            color: SlekkeColors.danger,
          ),
        const ContextMenuItem(
          value: 'add_channel',
          icon: Icons.tag,
          label: 'Add channel here',
          dividerAbove: true,
        ),
        const ContextMenuItem(
          value: 'add_category',
          icon: Icons.create_new_folder_outlined,
          label: 'Add category',
        ),
        const ContextMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          label: 'Rename',
          dividerAbove: true,
        ),
        const ContextMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete channel',
          color: SlekkeColors.danger,
        ),
      ],
    ];

    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: items,
    );
    if (!context.mounted) return;

    switch (result) {
      case 'mark_read':
        final uid = ref.read(currentUserProvider)?.uid;
        if (uid != null) {
          ref.read(firestoreServiceProvider).markChannelRead(uid, widget.channel.id);
        }
      case 'add_channel':
        final chName =
            await _nameDialog(context, 'New Channel', 'Channel name (no #)');
        if (chName == null || chName.isEmpty) return;
        final ch = await ref.read(firestoreServiceProvider).createChannel(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              categoryId: widget.channel.categoryId,
              name: chName.toLowerCase().replaceAll(' ', '-'),
            );
        ref.read(selectedChannelStateProvider.notifier).state = ch;
      case 'add_category':
        final catName =
            await _nameDialog(context, 'New Category', 'Category name');
        if (catName == null || catName.isEmpty) return;
        final cats = ref.read(categoriesProvider).valueOrNull ?? [];
        await ref.read(firestoreServiceProvider).createCategory(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              name: catName,
              position: cats.length,
            );
      case 'github':
        final url = await _githubDialog(
            context, widget.channel.githubRepo ?? '');
        if (url == null || !context.mounted) return;
        await ref.read(firestoreServiceProvider).updateChannel(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              categoryId: widget.channel.categoryId,
              channelId: widget.channel.id,
              githubRepo: url,
            );
      case 'github_disconnect':
        await ref.read(firestoreServiceProvider).updateChannel(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              categoryId: widget.channel.categoryId,
              channelId: widget.channel.id,
              githubRepo: '',
            );
      case 'rename':
        final name = await _nameDialog(context, 'Rename Channel', 'New name');
        if (name == null || name.isEmpty) return;
        await ref.read(firestoreServiceProvider).updateChannel(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              categoryId: widget.channel.categoryId,
              channelId: widget.channel.id,
              name: name.toLowerCase().replaceAll(' ', '-'),
            );
      case 'delete':
        final ok = await _confirmDelete(
          context,
          'Delete #${widget.channel.name}? This cannot be undone.',
        );
        if (ok != true || !context.mounted) return;
        if (ref.read(selectedChannelProvider)?.id == widget.channel.id) {
          ref.read(selectedChannelStateProvider.notifier).state = null;
        }
        await ref.read(firestoreServiceProvider).deleteChannel(
              orgId: widget.channel.organizationId,
              shellId: widget.channel.shellId,
              categoryId: widget.channel.categoryId,
              channelId: widget.channel.id,
            );
    }
  }
}

// ─── Right-click area ─────────────────────────────────────────────────────────

class _RightClickArea extends StatelessWidget {
  final bool enabled;
  final void Function(Offset) onRightClick;
  final Widget child;

  const _RightClickArea({
    required this.enabled,
    required this.onRightClick,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        // button 2 = secondary (right) mouse button
        if (e.buttons == 2) onRightClick(e.position);
      },
      child: child,
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, String message) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlekkeColors.surface,
        title: const Text('Confirm delete',
            style: TextStyle(color: SlekkeColors.textPrimary, fontSize: 15)),
        content: Text(message,
            style: const TextStyle(
                color: SlekkeColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: SlekkeColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: SlekkeColors.danger)),
          ),
        ],
      ),
    );

// Returns the entered URL, or null if cancelled.
// Pass [initial] to pre-fill with the existing URL.
Future<String?> _githubDialog(BuildContext context, String initial) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONNECT GITHUB REPOSITORY',
                style: TextStyle(
                  color: SlekkeColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste the full GitHub URL (e.g. https://github.com/owner/repo)',
                style: TextStyle(color: SlekkeColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                style: const TextStyle(
                    color: SlekkeColors.textPrimary, fontSize: 13),
                decoration:
                    const InputDecoration(hintText: 'https://github.com/…'),
                autofocus: true,
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.textMuted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.primary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> _nameDialog(
  BuildContext context,
  String title,
  String hint,
) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: SlekkeColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                style: const TextStyle(
                    color: SlekkeColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(hintText: hint),
                autofocus: true,
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.textMuted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.textPrimary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
