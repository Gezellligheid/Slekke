import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/firestore_provider.dart';

void showInviteDialog(BuildContext context, String orgId) {
  showDialog<void>(
    context: context,
    builder: (_) => _InviteDialog(orgId: orgId),
  );
}

class _InviteDialog extends ConsumerStatefulWidget {
  final String orgId;
  const _InviteDialog({required this.orgId});

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  bool _copied = false;
  bool _regenerating = false;

  Future<void> _copy(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      await ref.read(firestoreServiceProvider).regenerateInviteToken(widget.orgId);
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(selectedOrgProvider);
    final token = org?.inviteToken ?? '—';
    final orgName = org?.name ?? '';

    return Dialog(
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'INVITE PEOPLE',
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
                      child: Icon(Icons.close, size: 16, color: SlekkeColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Share this code to invite others to $orgName.',
                style: const TextStyle(
                  color: SlekkeColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              // Token row
              Container(
                decoration: BoxDecoration(
                  color: SlekkeColors.inputBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SlekkeColors.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        token,
                        style: const TextStyle(
                          color: SlekkeColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _copied
                          ? const Row(
                              key: ValueKey('copied'),
                              children: [
                                Icon(Icons.check, size: 14, color: SlekkeColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'Copied',
                                  style: TextStyle(
                                    color: SlekkeColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : TextButton.icon(
                              key: const ValueKey('copy'),
                              onPressed: () => _copy(token),
                              style: TextButton.styleFrom(
                                foregroundColor: SlekkeColors.textPrimary,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Copy'),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Regenerate
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 12, color: SlekkeColors.textMuted),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Anyone with this code can join. Regenerate to invalidate old codes.',
                      style: TextStyle(color: SlekkeColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: SlekkeColors.divider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _regenerating ? null : _regenerate,
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.textMuted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: _regenerating
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: SlekkeColors.textMuted,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 14),
                    label: const Text('Regenerate code'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SlekkeColors.textPrimary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Done'),
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
