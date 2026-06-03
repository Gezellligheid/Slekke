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
                : _RightClickArea(
                    enabled: canManageShells,
                    onRightClick: (pos) =>
                        _showContextMenu(context, ref, pos, orgId, selectedShellId!),
                    child: _CategoryList(orgId: orgId, shellId: selectedShellId!),
                  ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref,
      Offset position, String orgId, String shellId) async {
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
    if (!context.mounted) return;
    if (result == 'add_category') {
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

    return categoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: SlekkeColors.primary),
      ),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: SlekkeColors.danger))),
      data: (categories) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: categories
            .map((cat) => _CategoryTile(
                  category: cat,
                  orgId: orgId,
                  shellId: shellId,
                ))
            .toList(),
      ),
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
    if (result == 'add_channel') {
      final name =
          await _nameDialog(context, 'New Channel', 'Channel name (no #)');
      if (name == null || name.isEmpty) return;
      final ch = await ref.read(firestoreServiceProvider).createChannel(
            orgId: widget.orgId,
            shellId: widget.shellId,
            categoryId: widget.category.id,
            name: name.toLowerCase().replaceAll(' ', '-'),
          );
      ref.read(selectedChannelStateProvider.notifier).state = ch;
    } else if (result == 'rename') {
      final name = await _nameDialog(context, 'Rename Category', 'New name');
      if (name == null || name.isEmpty) return;
      await ref.read(firestoreServiceProvider).updateCategory(
            orgId: widget.orgId,
            shellId: widget.shellId,
            categoryId: widget.category.id,
            name: name,
          );
    } else if (result == 'delete') {
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _RightClickArea(
        enabled: widget.canManage,
        onRightClick: (pos) => _showChannelSettings(context, ref, pos),
        child: GestureDetector(
          onTap: () {
            ref.read(selectedChannelStateProvider.notifier).state = widget.channel;
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
                color: isSelected
                    ? SlekkeColors.textPrimary
                    : SlekkeColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.channel.name,
                  style: TextStyle(
                    color: isSelected
                        ? SlekkeColors.textPrimary
                        : SlekkeColors.textSecondary,
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: [
        const ContextMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          label: 'Rename',
        ),
        ContextMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete channel',
          color: SlekkeColors.danger,
          dividerAbove: true,
        ),
      ],
    );
    if (!context.mounted) return;
    if (result == 'rename') {
      final name = await _nameDialog(context, 'Rename Channel', 'New name');
      if (name == null || name.isEmpty) return;
      await ref.read(firestoreServiceProvider).updateChannel(
            orgId: widget.channel.organizationId,
            shellId: widget.channel.shellId,
            categoryId: widget.channel.categoryId,
            channelId: widget.channel.id,
            name: name.toLowerCase().replaceAll(' ', '-'),
          );
    } else if (result == 'delete') {
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
