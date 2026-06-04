import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/organization_model.dart';
import '../../models/user_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/widgets/context_menu.dart';
import '../../core/widgets/user_avatar.dart';
import '../onboarding/create_or_join_screen.dart';
import '../settings/settings_screen.dart';
import 'notification_panel.dart';
import 'org_settings_screen.dart';

// ─── Root ─────────────────────────────────────────────────────────────────────

class OrgSwitcher extends ConsumerWidget {
  const OrgSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrgsProvider);
    final selectedOrgId = ref.watch(selectedOrgIdProvider);
    final dmMode = ref.watch(dmModeProvider);

    return Container(
      width: 200,
      color: SlekkeColors.background,
      child: Column(
        children: [
          _DmNavItem(
            selected: dmMode,
            onTap: () {
              ref.read(dmModeProvider.notifier).state = true;
              ref.read(selectedOrgIdProvider.notifier).state = null;
              ref.read(selectedChannelStateProvider.notifier).state = null;
            },
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          Expanded(
            child: orgsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (orgs) => ListView(
                padding: const EdgeInsets.only(top: 4),
                children: orgs
                    .map((o) => _OrgAccordion(
                          org: o,
                          expanded: o.id == selectedOrgId,
                          onSelect: () {
                            ref.read(dmModeProvider.notifier).state = false;
                            ref.read(selectedOrgIdProvider.notifier).state =
                                o.id;
                            ref.read(selectedShellIdProvider.notifier).state =
                                null;
                            ref
                                .read(selectedChannelStateProvider.notifier)
                                .state = null;
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          _AddOrgRow(
            onTap: () => showDialog(
              context: context,
              builder: (_) => const CreateOrJoinDialog(),
            ),
          ),
          const Divider(height: 1, color: SlekkeColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _UserAvatar()),
                const SizedBox(width: 4),
                _BellButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DM nav item ─────────────────────────────────────────────────────────────

class _DmNavItem extends ConsumerStatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  const _DmNavItem({required this.selected, required this.onTap});

  @override
  ConsumerState<_DmNavItem> createState() => _DmNavItemState();
}

class _DmNavItemState extends ConsumerState<_DmNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final unreadDms = ref.watch(dmUnreadCountProvider);
    final dmBadge = widget.selected ? 0 : unreadDms.clamp(0, 9);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: widget.selected
              ? SlekkeColors.channelSelected
              : _hovered
                  ? SlekkeColors.elevated.withAlpha(60)
                  : Colors.transparent,
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: widget.selected
                    ? SlekkeColors.textPrimary
                    : SlekkeColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct Messages',
                  style: TextStyle(
                    color: widget.selected
                        ? SlekkeColors.textPrimary
                        : SlekkeColors.textSecondary,
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (dmBadge > 0) _UnreadBadge(count: dmBadge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Org accordion row ────────────────────────────────────────────────────────

class _OrgAccordion extends ConsumerStatefulWidget {
  final OrganizationModel org;
  final bool expanded;
  final VoidCallback onSelect;

  const _OrgAccordion({
    required this.org,
    required this.expanded,
    required this.onSelect,
  });

  @override
  ConsumerState<_OrgAccordion> createState() => _OrgAccordionState();
}

class _OrgAccordionState extends ConsumerState<_OrgAccordion>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _chevronCtrl;
  late final Animation<double> _chevronAnim;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.expanded ? 1.0 : 0.0,
    );
    _chevronAnim = CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_OrgAccordion old) {
    super.didUpdateWidget(old);
    if (widget.expanded != old.expanded) {
      widget.expanded ? _chevronCtrl.forward() : _chevronCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  Future<void> _showOrgContextMenu(BuildContext context, Offset position) async {
    final currentUid = ref.read(currentUserProvider)?.uid;
    final isOwner = widget.org.ownerId == currentUid;
    final perms = ref.read(currentUserOrgPermissionsProvider);
    final canManage = isOwner || perms.manageRoles || perms.manageShells;

    final items = <ContextMenuItem<String>>[
      const ContextMenuItem(
        value: 'mark_read',
        icon: Icons.done_all,
        label: 'Mark as read',
      ),
      if (isOwner || perms.manageOrg)
        const ContextMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          label: 'Edit org',
          dividerAbove: true,
        ),
      if (canManage)
        const ContextMenuItem(
          value: 'settings',
          icon: Icons.settings_outlined,
          label: 'Settings',
        ),
      if (!isOwner)
        ContextMenuItem(
          value: 'leave',
          icon: Icons.exit_to_app,
          label: 'Leave org',
          color: SlekkeColors.danger,
          dividerAbove: true,
        ),
      if (isOwner)
        ContextMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete org',
          color: SlekkeColors.danger,
          dividerAbove: !canManage,
        ),
    ];

    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: items,
    );

    if (!mounted) return;

    switch (result) {
      case 'mark_read':
        _markOrgAsRead();
      case 'rename':
        _renameOrg(context);
      case 'settings':
        showOrgSettingsDialog(context);
      case 'leave':
        _confirmLeave(context);
      case 'delete':
        _confirmDeleteOrg(context);
    }
  }

  Future<void> _renameOrg(BuildContext context) async {
    final name = await _inputDialog(
      context,
      title: 'Rename organisation',
      hint: 'Organisation name',
      initial: widget.org.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await ref.read(firestoreServiceProvider).updateOrgName(
          orgId: widget.org.id,
          name: name,
        );
  }

  Future<void> _confirmDeleteOrg(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlekkeColors.surface,
        title: const Text('Delete org',
            style: TextStyle(color: SlekkeColors.textPrimary)),
        content: Text(
          'Permanently delete "${widget.org.name}"? This cannot be undone.',
          style: const TextStyle(color: SlekkeColors.textSecondary),
        ),
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
    if (confirmed == true && mounted) {
      await ref.read(firestoreServiceProvider).deleteOrg(widget.org.id);
      ref.read(selectedOrgIdProvider.notifier).state = null;
      ref.read(selectedShellIdProvider.notifier).state = null;
      ref.read(selectedChannelStateProvider.notifier).state = null;
    }
  }

  void _markOrgAsRead() {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final channelIds = ref
        .read(orgChannelMetaProvider(widget.org.id))
        .valueOrNull
        ?.keys
        .toList() ?? [];
    ref.read(firestoreServiceProvider).batchMarkRead(
          uid: uid,
          channelIds: channelIds,
        );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlekkeColors.surface,
        title: const Text('Leave org',
            style: TextStyle(color: SlekkeColors.textPrimary)),
        content: Text(
          'Are you sure you want to leave "${widget.org.name}"? You will need an invite to rejoin.',
          style: const TextStyle(color: SlekkeColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: SlekkeColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave',
                style: TextStyle(color: SlekkeColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).leaveOrg(widget.org.id, uid);
    if (!mounted) return;
    // Clear selection if we left the selected org
    if (ref.read(selectedOrgIdProvider) == widget.org.id) {
      ref.read(selectedOrgIdProvider.notifier).state = null;
      ref.read(selectedShellIdProvider.notifier).state = null;
      ref.read(selectedChannelStateProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final isOwner = widget.org.ownerId == currentUid;
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final canManage = isOwner || perms.manageRoles || perms.manageShells;
    final orgUnread = ref.watch(orgUnreadCountProvider(widget.org.id));
    final orgBadge = widget.expanded ? 0 : orgUnread.clamp(0, 9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Org header row
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (e.buttons == 2) _showOrgContextMenu(context, e.position);
            },
            child: GestureDetector(
            onTap: widget.onSelect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: _hovered && !widget.expanded
                  ? SlekkeColors.elevated.withAlpha(60)
                  : Colors.transparent,
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _chevronAnim,
                    builder: (context, _) => Transform.rotate(
                      angle: _chevronAnim.value * 1.5708, // 0 → 90°
                      child: Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: widget.expanded
                            ? SlekkeColors.textPrimary
                            : SlekkeColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.org.name,
                      style: TextStyle(
                        color: widget.expanded
                            ? SlekkeColors.textPrimary
                            : SlekkeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: widget.expanded
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (orgBadge > 0) ...[
                    const SizedBox(width: 4),
                    _UnreadBadge(count: orgBadge),
                    const SizedBox(width: 4),
                  ],
                  AnimatedOpacity(
                    opacity: (_hovered && canManage) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: _HeaderIconBtn(
                      icon: Icons.settings_outlined,
                      tooltip: 'Org settings',
                      onTap: () => showOrgSettingsDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ), // Listener
        ),
        // Shells (shown when expanded)
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: widget.expanded
              ? _ShellList(org: widget.org)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Shell list (inside expanded accordion) ───────────────────────────────────

class _ShellList extends ConsumerWidget {
  final OrganizationModel org;
  const _ShellList({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellsAsync = ref.watch(shellsProvider);
    final selectedShellId = ref.watch(selectedShellIdProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final isOwner = org.ownerId == currentUid;
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final canManageShells = isOwner || perms.manageShells;

    return shellsAsync.when(
      loading: () => const SizedBox(height: 32),
      error: (e, _) => const SizedBox.shrink(),
      data: (shells) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...shells.map((shell) => _ShellRow(
                orgId: org.id,
                shellId: shell.id,
                name: shell.name,
                selected: shell.id == selectedShellId,
                canManage: canManageShells,
                onTap: () {
                  ref.read(dmModeProvider.notifier).state = false;
                  ref.read(selectedShellIdProvider.notifier).state = shell.id;
                  ref.read(selectedChannelStateProvider.notifier).state = null;
                },
              )),
          // Action rows
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4, top: 2),
            child: Row(
              children: [
                if (canManageShells) ...[
                  _SubActionBtn(
                    icon: Icons.add,
                    label: 'Shell',
                    onTap: () => _createShell(context, ref, org.id),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createShell(
      BuildContext context, WidgetRef ref, String orgId) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
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
                const Text('NEW SHELL',
                    style: TextStyle(
                        color: SlekkeColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(
                      color: SlekkeColors.textPrimary, fontSize: 13),
                  decoration:
                      const InputDecoration(hintText: 'Shell name'),
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
                          textStyle: const TextStyle(fontSize: 13)),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: SlekkeColors.textPrimary,
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      onPressed: () =>
                          Navigator.of(ctx).pop(ctrl.text.trim()),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    final shell = await ref
        .read(firestoreServiceProvider)
        .createShell(orgId: orgId, name: name);
    ref.read(dmModeProvider.notifier).state = false;
    ref.read(selectedShellIdProvider.notifier).state = shell.id;
  }
}

class _ShellRow extends ConsumerStatefulWidget {
  final String orgId;
  final String shellId;
  final String name;
  final bool selected;
  final bool canManage;
  final VoidCallback onTap;

  const _ShellRow({
    required this.orgId,
    required this.shellId,
    required this.name,
    required this.selected,
    required this.canManage,
    required this.onTap,
  });

  @override
  ConsumerState<_ShellRow> createState() => _ShellRowState();
}

class _ShellRowState extends ConsumerState<_ShellRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(shellUnreadCountProvider(widget.shellId));
    final count = widget.selected ? 0 : unread.clamp(0, 9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: widget.canManage
            ? (e) {
                if (e.buttons == 2) _showShellMenu(context, e.position);
              }
            : null,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hovered = v),
          borderRadius: BorderRadius.circular(4),
          mouseCursor: SystemMouseCursors.click,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 30,
            padding: const EdgeInsets.only(left: 28, right: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? SlekkeColors.channelSelected
                  : _hovered
                      ? SlekkeColors.elevated.withAlpha(60)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? SlekkeColors.textPrimary
                        : SlekkeColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: widget.selected
                          ? SlekkeColors.textPrimary
                          : SlekkeColors.textSecondary,
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) _UnreadBadge(count: count),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showShellMenu(BuildContext context, Offset position) async {
    final result = await showContextMenu<String>(
      context: context,
      position: position,
      items: [
        const ContextMenuItem(
          value: 'rename',
          icon: Icons.edit_outlined,
          label: 'Edit shell',
        ),
        ContextMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete shell',
          color: SlekkeColors.danger,
          dividerAbove: true,
        ),
      ],
    );
    if (!mounted) return;
    if (result == 'rename') {
      final name = await _inputDialog(
        context,
        title: 'Rename shell',
        hint: 'Shell name',
        initial: widget.name,
      );
      if (name == null || name.isEmpty) return;
      await ref.read(firestoreServiceProvider).updateShell(
            orgId: widget.orgId,
            shellId: widget.shellId,
            name: name,
          );
    } else if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SlekkeColors.surface,
          title: const Text('Delete shell',
              style: TextStyle(color: SlekkeColors.textPrimary)),
          content: Text(
            'Delete "${widget.name}"? All its categories and channels will be removed.',
            style: const TextStyle(color: SlekkeColors.textSecondary),
          ),
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
      if (confirmed == true && mounted) {
        if (ref.read(selectedShellIdProvider) == widget.shellId) {
          ref.read(selectedShellIdProvider.notifier).state = null;
          ref.read(selectedChannelStateProvider.notifier).state = null;
        }
        await ref.read(firestoreServiceProvider).deleteShell(
              orgId: widget.orgId,
              shellId: widget.shellId,
            );
      }
    }
  }
}

// ─── Shared dialog helpers ────────────────────────────────────────────────────

Future<String?> _inputDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) async {
  final ctrl = TextEditingController(text: initial);
  // Select all existing text so the user can immediately replace it
  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
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
                    onPressed: () =>
                        Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: const Text('Save'),
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

// ─── Bell button ──────────────────────────────────────────────────────────────

class _BellButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends ConsumerState<_BellButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(selectedOrgIdProvider);
    final unreadDmCount = ref.watch(dmUnreadCountProvider);
    final unreadChannelCount = orgId != null
        ? ref.watch(orgUnreadCountProvider(orgId))
        : 0;
    final totalUnread = (unreadDmCount + unreadChannelCount).clamp(0, 9);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showNotificationPanel(context, ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? SlekkeColors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 18,
                color:
                    _hovered ? SlekkeColors.textPrimary : SlekkeColors.textMuted,
              ),
              if (totalUnread > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: _UnreadBadge(count: totalUnread),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: SlekkeColors.danger,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _SubActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SubActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_SubActionBtn> createState() => _SubActionBtnState();
}

class _SubActionBtnState extends State<_SubActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hovered = v),
      mouseCursor: SystemMouseCursors.click,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon,
              size: 12,
              color: _hovered
                  ? SlekkeColors.textSecondary
                  : SlekkeColors.textMuted),
          const SizedBox(width: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: _hovered
                  ? SlekkeColors.textSecondary
                  : SlekkeColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add org row ──────────────────────────────────────────────────────────────

class _AddOrgRow extends StatefulWidget {
  final VoidCallback onTap;
  const _AddOrgRow({required this.onTap});

  @override
  State<_AddOrgRow> createState() => _AddOrgRowState();
}

class _AddOrgRowState extends State<_AddOrgRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(60)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.add,
                  size: 14,
                  color:
                      _hovered ? SlekkeColors.textSecondary : SlekkeColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'Add organisation',
                style: TextStyle(
                  color: _hovered
                      ? SlekkeColors.textSecondary
                      : SlekkeColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: SlekkeColors.textMuted),
        ),
      ),
    );
  }
}

// ─── User avatar + profile panel ─────────────────────────────────────────────

class _UserAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final displayName = profile?.displayName ?? user?.displayName ?? '';
    final photoUrl = profile?.photoUrl ?? user?.photoURL;
    final status =
        ref.watch(userStatusProvider).valueOrNull ?? UserStatus.online;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showProfilePanel(context, ref),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  UserAvatar(
                    photoUrl: photoUrl,
                    name: displayName,
                    size: 36,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _StatusDot(
                        status: status,
                        size: 11,
                        borderColor: SlekkeColors.background),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    status.label,
                    style: const TextStyle(
                        color: SlekkeColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePanel(BuildContext context, WidgetRef ref) {
    final rootCtx = context;
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
            left: 8,
            bottom: 60,
            child: _ProfileCard(
              onSettings: () {
                Navigator.of(dialogCtx).pop();
                showSettingsDialog(rootCtx);
              },
              onSignOut: () async {
                final auth = ref.read(authServiceProvider);
                Navigator.of(dialogCtx).pop();
                await auth.signOut();
              },
              onStatusChanged: (status) async {
                final uid = ref.read(currentUserProvider)?.uid;
                final fs = ref.read(firestoreServiceProvider);
                if (uid != null) {
                  await fs.updateUserStatus(uid, status);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends ConsumerWidget {
  final VoidCallback onSettings;
  final Future<void> Function() onSignOut;
  final Future<void> Function(UserStatus) onStatusChanged;

  const _ProfileCard({
    required this.onSettings,
    required this.onSignOut,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final displayName = profile?.displayName ?? user?.displayName ?? '—';
    final photoUrl = profile?.photoUrl ?? user?.photoURL;
    final status =
        ref.watch(userStatusProvider).valueOrNull ?? UserStatus.online;
    final bannerColor = ref.watch(settingsProvider.select((s) => s.bannerColor));

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: SlekkeColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SlekkeColors.elevated),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(140),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(7)),
                  child: Container(height: 56, color: bannerColor),
                ),
                Positioned(
                  left: 12,
                  top: 30,
                  // Simulate the 3px border by using a circle container with
                  // the surface colour as background + padding
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SlekkeColors.surface,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: UserAvatar(
                      photoUrl: photoUrl,
                      name: displayName,
                      size: 52,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: const TextStyle(
                                color: SlekkeColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '',
                            style: const TextStyle(
                                color: SlekkeColors.textMuted,
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _StatusDot(
                        status: status,
                        size: 11,
                        borderColor: SlekkeColors.surface),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: SlekkeColors.divider),
            _PanelRow(
              leading:
                  _StatusDot(status: status, size: 9, borderColor: SlekkeColors.surface),
              label: status.label,
              trailing: const Icon(Icons.chevron_right,
                  size: 14, color: SlekkeColors.textMuted),
              onTapUp: (pos) => _showStatusMenu(context, ref, pos, status),
            ),
            const Divider(height: 1, color: SlekkeColors.divider),
            _PanelRow(
              leading: const Icon(Icons.settings_outlined,
                  size: 15, color: SlekkeColors.textSecondary),
              label: 'Settings',
              onTap: onSettings,
            ),
            const Divider(height: 1, color: SlekkeColors.divider),
            _PanelRow(
              leading: const Icon(Icons.logout,
                  size: 15, color: SlekkeColors.danger),
              label: 'Sign out',
              color: SlekkeColors.danger,
              onTap: () => onSignOut(),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _showStatusMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    UserStatus current,
  ) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final firestoreService = ref.read(firestoreServiceProvider);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx + 8, position.dy - 80, position.dx + 200, position.dy),
      color: SlekkeColors.surface,
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text('SET STATUS',
              style: TextStyle(
                  color: SlekkeColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ),
        for (final s in UserStatus.values)
          PopupMenuItem<String>(
              value: s.name,
              height: 36,
              child: _StatusMenuRow(status: s, current: current)),
      ],
    );

    if (result != null && uid != null) {
      await firestoreService.updateUserStatus(
          uid, UserStatus.fromString(result));
    }
  }
}

// ─── Panel row ────────────────────────────────────────────────────────────────

class _PanelRow extends StatefulWidget {
  final Widget leading;
  final String label;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;
  final void Function(Offset)? onTapUp;

  const _PanelRow({
    required this.leading,
    required this.label,
    this.trailing,
    this.color,
    this.onTap,
    this.onTapUp,
  });

  @override
  State<_PanelRow> createState() => _PanelRowState();
}

class _PanelRowState extends State<_PanelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.color ?? SlekkeColors.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapUp: widget.onTapUp != null
            ? (d) => widget.onTapUp!(d.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 40,
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(100)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: widget.leading)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                      color: _hovered && widget.color == null
                          ? SlekkeColors.textPrimary
                          : fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status widgets ───────────────────────────────────────────────────────────

class _StatusMenuRow extends StatelessWidget {
  final UserStatus status;
  final UserStatus current;
  const _StatusMenuRow({required this.status, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusDot(status: status, size: 10, borderColor: SlekkeColors.surface),
        const SizedBox(width: 10),
        Expanded(
            child: Text(status.label,
                style: const TextStyle(
                    color: SlekkeColors.textPrimary, fontSize: 14))),
        if (status == current)
          const Icon(Icons.check,
              size: 14, color: SlekkeColors.textSecondary),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final UserStatus status;
  final double size;
  final Color borderColor;

  const _StatusDot(
      {required this.status,
      required this.size,
      required this.borderColor});

  Color get _color => switch (status) {
        UserStatus.online => SlekkeColors.success,
        UserStatus.away => SlekkeColors.warning,
        UserStatus.dnd => SlekkeColors.danger,
        UserStatus.invisible => SlekkeColors.elevated,
      };

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: borderColor, width: 2);
    if (status == UserStatus.invisible) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: SlekkeColors.textMuted, width: 1.5),
            color: borderColor),
      );
    }
    if (status == UserStatus.dnd) {
      return Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: _color, border: border),
        alignment: Alignment.center,
        child: Container(width: size * 0.45, height: 1.5, color: borderColor),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: _color, border: border),
    );
  }
}
