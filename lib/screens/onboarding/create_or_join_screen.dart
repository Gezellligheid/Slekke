import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

class CreateOrJoinDialog extends ConsumerStatefulWidget {
  const CreateOrJoinDialog({super.key});

  @override
  ConsumerState<CreateOrJoinDialog> createState() => _CreateOrJoinDialogState();
}

class _CreateOrJoinDialogState extends ConsumerState<CreateOrJoinDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _createCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _createCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final org = await ref.read(firestoreServiceProvider).createOrganization(
        name: name,
        ownerId: user.uid,
      );
      ref.read(selectedOrgIdProvider.notifier).state = org.id;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final token = _joinCtrl.text.trim();
    if (token.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final org = await ref
          .read(firestoreServiceProvider)
          .joinOrganizationByToken(
            token: token,
            userId: user.uid,
            displayName: user.displayName ?? '',
          );
      if (org == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid invite token.')),
          );
        }
        return;
      }
      ref.read(selectedOrgIdProvider.notifier).state = org.id;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SlekkeColors.surface,
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Get started',
                      style: TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: SlekkeColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TabBar(
                controller: _tabs,
                indicatorColor: SlekkeColors.textPrimary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 1.5,
                labelColor: SlekkeColors.textPrimary,
                unselectedLabelColor: SlekkeColors.textMuted,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                dividerColor: SlekkeColors.divider,
                tabs: const [
                  Tab(text: 'Create organisation'),
                  Tab(text: 'Join with invite'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 140,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _createCtrl,
                          style: const TextStyle(color: SlekkeColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Organisation name',
                          ),
                          onSubmitted: (_) => _create(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _create,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SlekkeColors.onPrimary,
                                    ),
                                  )
                                : const Text('Create'),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _joinCtrl,
                          style: const TextStyle(color: SlekkeColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Invite token (e.g. A1B2C3D4)',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _join(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _join,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SlekkeColors.onPrimary,
                                    ),
                                  )
                                : const Text('Join'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
