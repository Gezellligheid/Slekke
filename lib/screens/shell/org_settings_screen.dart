import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/slekke_toggle.dart';
import '../../models/org_role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import 'invite_dialog.dart';

void showOrgSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _OrgSettingsDialog(),
  );
}

// ─── Dialog shell ─────────────────────────────────────────────────────────────

class _OrgSettingsDialog extends StatelessWidget {
  const _OrgSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const _OrgSettingsLayout(),
        ),
      ),
    );
  }
}

// ─── Layout ───────────────────────────────────────────────────────────────────

enum _Tab { roles, members }

class _OrgSettingsLayout extends StatefulWidget {
  const _OrgSettingsLayout();

  @override
  State<_OrgSettingsLayout> createState() => _OrgSettingsLayoutState();
}

class _OrgSettingsLayoutState extends State<_OrgSettingsLayout> {
  _Tab _tab = _Tab.roles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Sidebar(selected: _tab, onSelect: (t) => setState(() => _tab = t)),
        Expanded(
          child: Container(
            color: SlekkeColors.background,
            child: _tab == _Tab.roles
                ? const _RolesTab()
                : const _MembersTab(),
          ),
        ),
      ],
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _Tab selected;
  final ValueChanged<_Tab> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: SlekkeColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'ORG SETTINGS',
              style: TextStyle(
                color: SlekkeColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _SidebarItem(
            icon: Icons.shield_outlined,
            label: 'Roles',
            selected: selected == _Tab.roles,
            onTap: () => onSelect(_Tab.roles),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Members',
            selected: selected == _Tab.members,
            onTap: () => onSelect(_Tab.members),
          ),
          const Spacer(),
          const Divider(height: 1, color: SlekkeColors.divider),
          _CloseButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 36,
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
              Icon(widget.icon,
                  size: 15,
                  color: widget.selected
                      ? SlekkeColors.textPrimary
                      : SlekkeColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(80)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.close,
                  size: 15,
                  color:
                      _hovered ? SlekkeColors.textSecondary : SlekkeColors.textMuted),
              const SizedBox(width: 8),
              Text('Close',
                  style: TextStyle(
                      color: _hovered
                          ? SlekkeColors.textSecondary
                          : SlekkeColors.textMuted,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Roles tab ────────────────────────────────────────────────────────────────

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(orgRolesProvider);
    final orgId = ref.watch(selectedOrgIdProvider);
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final canManageRoles = org?.ownerId == currentUid || perms.manageRoles;

    return rolesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: SlekkeColors.primary)),
      error: (e, _) => Center(
          child: Text('$e',
              style: const TextStyle(color: SlekkeColors.danger))),
      data: (roles) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ROLES',
                  style: TextStyle(
                    color: SlekkeColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (canManageRoles)
                _SmallButton(
                  icon: Icons.add,
                  label: 'New role',
                  onTap: () => _showRoleEditor(context, orgId!, null, roles.length),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...roles.map((role) => _RoleRow(
                role: role,
                orgId: orgId!,
                onEdit: () => _showRoleEditor(context, orgId, role, roles.length),
              )),
        ],
      ),
    );
  }

  void _showRoleEditor(
    BuildContext context,
    String orgId,
    OrgRole? existing,
    int roleCount,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _RoleEditorDialog(
        orgId: orgId,
        existing: existing,
        nextPosition: roleCount,
      ),
    );
  }
}

class _RoleRow extends ConsumerWidget {
  final OrgRole role;
  final String orgId;
  final VoidCallback onEdit;

  const _RoleRow(
      {required this.role, required this.orgId, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final canManageRoles = org?.ownerId == currentUid || perms.manageRoles;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SlekkeColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SlekkeColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: role.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              role.name,
              style: const TextStyle(
                  color: SlekkeColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          _PermissionChips(permissions: role.permissions),
          if (canManageRoles) ...[
            const SizedBox(width: 8),
            _IconBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: onEdit),
            if (!role.isEveryone)
              _IconBtn(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: SlekkeColors.danger,
                onTap: () async {
                  await ref
                      .read(firestoreServiceProvider)
                      .deleteOrgRole(orgId: orgId, roleId: role.id);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _PermissionChips extends StatelessWidget {
  final OrgPermissions permissions;
  const _PermissionChips({required this.permissions});

  @override
  Widget build(BuildContext context) {
    final active = <String>[];
    if (permissions.manageOrg) active.add('Org');
    if (permissions.manageShells) active.add('Shells');
    if (permissions.manageRoles) active.add('Roles');
    if (permissions.manageMessages) active.add('Messages');
    if (permissions.inviteMembers) active.add('Invite');

    if (active.isEmpty) return const SizedBox.shrink();

    return Row(
      children: active
          .take(3)
          .map((p) => Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SlekkeColors.elevated,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(p,
                    style: const TextStyle(
                        color: SlekkeColors.textMuted, fontSize: 10)),
              ))
          .toList(),
    );
  }
}

// ─── Role editor dialog ───────────────────────────────────────────────────────

class _RoleEditorDialog extends ConsumerStatefulWidget {
  final String orgId;
  final OrgRole? existing;
  final int nextPosition;

  const _RoleEditorDialog(
      {required this.orgId,
      required this.existing,
      required this.nextPosition});

  @override
  ConsumerState<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<_RoleEditorDialog> {
  static const _colorPresets = [
    0xFF4CA87D, 0xFF5865F2, 0xFFED4245, 0xFFFEE75C,
    0xFFEB459E, 0xFFFF7043, 0xFF00BCD4, 0xFF7A7A7A,
  ];

  late final TextEditingController _nameCtrl;
  late OrgPermissions _perms;
  late int _colorValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _perms = widget.existing?.permissions ?? const OrgPermissions();
    _colorValue = widget.existing?.colorValue ?? _colorPresets.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      if (widget.existing != null) {
        await svc.updateOrgRole(
          orgId: widget.orgId,
          roleId: widget.existing!.id,
          name: name,
          colorValue: _colorValue,
          permissions: _perms,
        );
      } else {
        await svc.createOrgRole(
          orgId: widget.orgId,
          name: name,
          colorValue: _colorValue,
          permissions: _perms,
          position: widget.nextPosition,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEveryone = widget.existing?.isEveryone ?? false;
    return Dialog(
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'NEW ROLE' : 'EDIT ROLE',
                style: const TextStyle(
                    color: SlekkeColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                enabled: !isEveryone,
                style: const TextStyle(
                    color: SlekkeColors.textPrimary, fontSize: 13),
                decoration:
                    const InputDecoration(hintText: 'Role name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Color swatches
              const Text('COLOUR',
                  style: TextStyle(
                      color: SlekkeColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: _colorPresets
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => _colorValue = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(c),
                              border: Border.all(
                                color: _colorValue == c
                                    ? SlekkeColors.textPrimary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Permissions
              const Text('PERMISSIONS',
                  style: TextStyle(
                      color: SlekkeColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: SlekkeColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SlekkeColors.divider),
                ),
                child: Column(
                  children: [
                    _PermToggle(
                      label: 'Manage organisation',
                      subtitle: 'Rename org, manage settings',
                      value: _perms.manageOrg,
                      onChanged: (v) =>
                          setState(() => _perms = _perms.copyWith(manageOrg: v)),
                    ),
                    _PermToggle(
                      label: 'Manage shells & channels',
                      subtitle: 'Create, edit, delete shells/categories/channels',
                      value: _perms.manageShells,
                      onChanged: (v) => setState(
                          () => _perms = _perms.copyWith(manageShells: v)),
                    ),
                    _PermToggle(
                      label: 'Manage roles',
                      subtitle: 'Create roles and assign them to members',
                      value: _perms.manageRoles,
                      onChanged: (v) => setState(
                          () => _perms = _perms.copyWith(manageRoles: v)),
                    ),
                    _PermToggle(
                      label: 'Manage messages',
                      subtitle: 'Delete any message',
                      value: _perms.manageMessages,
                      onChanged: (v) => setState(
                          () => _perms = _perms.copyWith(manageMessages: v)),
                    ),
                    _PermToggle(
                      label: 'Invite members',
                      subtitle: 'Share invite codes',
                      value: _perms.inviteMembers,
                      divider: false,
                      onChanged: (v) => setState(
                          () => _perms = _perms.copyWith(inviteMembers: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: SlekkeColors.textMuted,
                        textStyle: const TextStyle(fontSize: 13)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: SlekkeColors.textPrimary,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: SlekkeColors.textPrimary))
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  const _PermToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: SlekkeColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(
                            color: SlekkeColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              SlekkeToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (divider)
          const Divider(
              height: 1, indent: 12, endIndent: 12, color: SlekkeColors.divider),
      ],
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab();

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  List<Map<String, dynamic>>? _profiles;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final org = ref.read(selectedOrgProvider);
    if (org == null) return;
    final profiles = await ref
        .read(firestoreServiceProvider)
        .getOrgMemberProfiles(org.members.map((m) => m.userId).toList());
    if (mounted) setState(() => _profiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(orgRolesProvider);
    final memberRolesAsync = ref.watch(orgMemberRolesProvider);
    final orgId = ref.watch(selectedOrgIdProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    final perms = ref.watch(currentUserOrgPermissionsProvider);
    final org = ref.watch(selectedOrgProvider);
    final canInvite = org?.ownerId == currentUid || perms.inviteMembers;

    if (_profiles == null) {
      return const Center(
          child: CircularProgressIndicator(color: SlekkeColors.primary));
    }

    final roles = rolesAsync.valueOrNull ?? [];
    final memberRoles = memberRolesAsync.valueOrNull ?? [];
    final nonEveryone = roles.where((r) => !r.isEveryone).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MEMBERS',
              style: TextStyle(
                  color: SlekkeColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
            if (canInvite)
              _SmallButton(
                icon: Icons.person_add_outlined,
                label: 'Invite',
                onTap: () => showInviteDialog(context, orgId!),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._profiles!.map((profile) {
          final uid = profile['id'] as String;
          final name = profile['displayName'] as String? ?? uid;
          final isOwner = org?.ownerId == uid;
          final myRoles = memberRoles
              .where((m) => m.userId == uid)
              .expand((m) => m.roleIds)
              .toSet();
          final assignedRoles =
              nonEveryone.where((r) => myRoles.contains(r.id)).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SlekkeColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SlekkeColors.divider),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SlekkeColors.elevated,
                    image: (profile['photoUrl'] as String?) != null
                        ? DecorationImage(
                            image:
                                NetworkImage(profile['photoUrl'] as String),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: (profile['photoUrl'] as String?) == null
                      ? Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: SlekkeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: SlekkeColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          if (isOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: SlekkeColors.success.withAlpha(40),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('Owner',
                                  style: TextStyle(
                                      color: SlekkeColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      if (assignedRoles.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          children: assignedRoles
                              .map((r) => _RoleChip(role: r))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((perms.manageRoles || org?.ownerId == currentUid) &&
                    !isOwner)
                  _IconBtn(
                    icon: Icons.manage_accounts_outlined,
                    tooltip: 'Assign roles',
                    onTap: () => _showRoleAssignment(
                      context,
                      orgId: orgId!,
                      userId: uid,
                      userName: name,
                      allRoles: nonEveryone,
                      assignedIds: myRoles,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showRoleAssignment(
    BuildContext context, {
    required String orgId,
    required String userId,
    required String userName,
    required List<OrgRole> allRoles,
    required Set<String> assignedIds,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _RoleAssignmentDialog(
        orgId: orgId,
        userId: userId,
        userName: userName,
        allRoles: allRoles,
        initialAssigned: assignedIds,
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final OrgRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: role.color.withAlpha(30),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: role.color.withAlpha(80)),
      ),
      child: Text(
        role.name,
        style: TextStyle(
            color: role.color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RoleAssignmentDialog extends ConsumerStatefulWidget {
  final String orgId;
  final String userId;
  final String userName;
  final List<OrgRole> allRoles;
  final Set<String> initialAssigned;

  const _RoleAssignmentDialog({
    required this.orgId,
    required this.userId,
    required this.userName,
    required this.allRoles,
    required this.initialAssigned,
  });

  @override
  ConsumerState<_RoleAssignmentDialog> createState() =>
      _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState
    extends ConsumerState<_RoleAssignmentDialog> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialAssigned);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).setMemberRoles(
            orgId: widget.orgId,
            userId: widget.userId,
            roleIds: _selected.toList(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROLES FOR ${widget.userName.toUpperCase()}',
                style: const TextStyle(
                    color: SlekkeColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: SlekkeColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SlekkeColors.divider),
                ),
                child: Column(
                  children: widget.allRoles.asMap().entries.map((e) {
                    final i = e.key;
                    final role = e.value;
                    final isLast = i == widget.allRoles.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: role.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(role.name,
                                    style: const TextStyle(
                                        color: SlekkeColors.textPrimary,
                                        fontSize: 13)),
                              ),
                              SlekkeToggle(
                                value: _selected.contains(role.id),
                                onChanged: (v) => setState(() {
                                  if (v) {
                                    _selected.add(role.id);
                                  } else {
                                    _selected.remove(role.id);
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: SlekkeColors.divider),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: SlekkeColors.textMuted,
                        textStyle: const TextStyle(fontSize: 13)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: SlekkeColors.textPrimary,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: _saving ? null : _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon,
              size: 15,
              color: color ?? SlekkeColors.textMuted),
        ),
      ),
    );
  }
}

class _SmallButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? SlekkeColors.elevated : SlekkeColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SlekkeColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 13, color: SlekkeColors.textSecondary),
              const SizedBox(width: 4),
              Text(widget.label,
                  style: const TextStyle(
                      color: SlekkeColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
