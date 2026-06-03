import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

void showNewDmDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _NewDmDialog(),
  );
}

class _NewDmDialog extends ConsumerStatefulWidget {
  const _NewDmDialog();

  @override
  ConsumerState<_NewDmDialog> createState() => _NewDmDialogState();
}

class _NewDmDialogState extends ConsumerState<_NewDmDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final myUid = ref.read(currentUserProvider)?.uid ?? '';
    final orgs = ref.read(userOrgsProvider).valueOrNull ?? [];
    final svc = ref.read(firestoreServiceProvider);

    final seen = <String>{myUid};
    final members = <Map<String, dynamic>>[];

    for (final org in orgs) {
      final uids =
          org.members.map((m) => m.userId).where((id) => !seen.contains(id)).toList();
      if (uids.isEmpty) continue;
      seen.addAll(uids);
      final profiles = await svc.getOrgMemberProfiles(uids);
      members.addAll(profiles);
    }

    if (mounted) {
      setState(() {
        _allMembers = members;
        _filtered = members;
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allMembers
          : _allMembers
              .where((m) =>
                  (m['displayName'] as String? ?? '')
                      .toLowerCase()
                      .contains(q) ||
                  (m['email'] as String? ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _open(Map<String, dynamic> profile) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final me = ref.read(currentUserProvider);
      if (me == null) return;
      final dm = await ref.read(firestoreServiceProvider).openOrCreateDm(
            myUid: me.uid,
            myName: me.displayName ?? '',
            myPhoto: me.photoURL,
            theirUid: profile['id'] as String,
            theirName: profile['displayName'] as String? ?? '',
            theirPhoto: profile['photoUrl'] as String?,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.read(dmModeProvider.notifier).state = true;
      ref.read(selectedDmIdProvider.notifier).state = dm.id;
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'NEW DIRECT MESSAGE',
                      style: TextStyle(
                        color: SlekkeColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 16, color: SlekkeColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: SlekkeColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search by name or email…',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: SlekkeColors.textMuted),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: SlekkeColors.divider),
            // Results
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: SlekkeColors.primary))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchCtrl.text.isEmpty
                                ? 'No other members found'
                                : 'No results for "${_searchCtrl.text}"',
                            style: const TextStyle(
                                color: SlekkeColors.textMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _MemberRow(
                                profile: _filtered[i],
                                onTap: () => _open(_filtered[i]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onTap;
  const _MemberRow({required this.profile, required this.onTap});

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['displayName'] as String? ?? '';
    final email = widget.profile['email'] as String? ?? '';
    final photo = widget.profile['photoUrl'] as String?;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 52,
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(80)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SlekkeColors.elevated,
                  image: photo != null
                      ? DecorationImage(
                          image: NetworkImage(photo), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: photo == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: SlekkeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                            color: SlekkeColors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (_hovered)
                const Icon(Icons.send,
                    size: 14, color: SlekkeColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
