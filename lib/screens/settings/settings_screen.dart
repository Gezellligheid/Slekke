import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/slekke_toggle.dart';
import '../../models/settings_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/settings_provider.dart';

void showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _SettingsDialog(),
  );
}

// ─── Dialog shell ────────────────────────────────────────────────────────────

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const _SettingsLayout(),
        ),
      ),
    );
  }
}

// ─── Layout (sidebar + content) ──────────────────────────────────────────────

class _SettingsLayout extends StatefulWidget {
  const _SettingsLayout();

  @override
  State<_SettingsLayout> createState() => _SettingsLayoutState();
}

class _SettingsLayoutState extends State<_SettingsLayout> {
  _Section _selected = _Section.account;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Sidebar(
          selected: _selected,
          onSelect: (s) => setState(() => _selected = s),
        ),
        Expanded(
          child: _ContentPanel(section: _selected),
        ),
      ],
    );
  }
}

// ─── Sections enum ───────────────────────────────────────────────────────────

enum _Section { account, appearance, notifications, privacy }

extension _SectionLabel on _Section {
  String get label => switch (this) {
        _Section.account => 'My Account',
        _Section.appearance => 'Appearance',
        _Section.notifications => 'Notifications',
        _Section.privacy => 'Privacy',
      };

  IconData get icon => switch (this) {
        _Section.account => Icons.person_outline,
        _Section.appearance => Icons.palette_outlined,
        _Section.notifications => Icons.notifications_none,
        _Section.privacy => Icons.lock_outline,
      };
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final _Section selected;
  final ValueChanged<_Section> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: SlekkeColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'SETTINGS',
              style: TextStyle(
                color: SlekkeColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final s in _Section.values)
            _SidebarItem(
              section: s,
              selected: s == selected,
              onTap: () => onSelect(s),
            ),
          const Spacer(),
          const Divider(height: 1, color: SlekkeColors.divider),
          _CloseRow(onClose: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

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
              Icon(
                widget.section.icon,
                size: 16,
                color: widget.selected
                    ? SlekkeColors.textPrimary
                    : SlekkeColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.section.label,
                style: TextStyle(
                  color: widget.selected
                      ? SlekkeColors.textPrimary
                      : SlekkeColors.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseRow extends StatefulWidget {
  final VoidCallback onClose;
  const _CloseRow({required this.onClose});

  @override
  State<_CloseRow> createState() => _CloseRowState();
}

class _CloseRowState extends State<_CloseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _hovered ? SlekkeColors.elevated.withAlpha(80) : Colors.transparent,
          child: Row(
            children: [
              Icon(
                Icons.close,
                size: 16,
                color: _hovered ? SlekkeColors.textSecondary : SlekkeColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Close',
                style: TextStyle(
                  color: _hovered ? SlekkeColors.textSecondary : SlekkeColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Content panel ───────────────────────────────────────────────────────────

class _ContentPanel extends StatelessWidget {
  final _Section section;
  const _ContentPanel({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SlekkeColors.background,
      child: switch (section) {
        _Section.account => const _AccountSection(),
        _Section.appearance => const _AppearanceSection(),
        _Section.notifications => const _NotificationsSection(),
        _Section.privacy => const _PrivacySection(),
      },
    );
  }
}

// ─── Shared layout helpers ────────────────────────────────────────────────────

class _SectionScroll extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionScroll({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
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
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  const _SettingsGroup({this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: const TextStyle(
              color: SlekkeColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: SlekkeColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SlekkeColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  const _ToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: SlekkeColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SlekkeToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (divider)
          const Divider(height: 1, indent: 16, endIndent: 16, color: SlekkeColors.divider),
      ],
    );
  }
}

// ─── Account section ─────────────────────────────────────────────────────────

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _editingName = false;
  bool _savingName = false;
  bool _uploadingPhoto = false;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? '.${file.name.split('.').last}' : '.jpg';
      final url = await ref.read(storageServiceProvider).uploadProfilePicture(
            uid: uid, bytes: bytes, extension: ext);
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, photoUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveName() async {
    final uid = ref.read(currentUserProvider)?.uid;
    final name = _nameCtrl.text.trim();
    if (uid == null || name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, displayName: name);
      if (mounted) setState(() => _editingName = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final displayName = profile?.displayName ?? user?.displayName ?? '';
    final photoUrl = profile?.photoUrl ?? user?.photoURL;
    final email = user?.email ?? '';

    return _SectionScroll(
      title: 'My Account',
      children: [
        _SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Clickable avatar
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SlekkeColors.elevated,
                              image: photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: _uploadingPhoto
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SlekkeColors.primary))
                                : photoUrl == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: SlekkeColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                          ),
                          if (!_uploadingPhoto)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SlekkeColors.primary,
                                  border: Border.all(
                                      color: SlekkeColors.background, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_editingName)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: const TextStyle(
                                      color: SlekkeColors.textPrimary,
                                      fontSize: 14),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    filled: true,
                                    fillColor: SlekkeColors.inputBg,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: SlekkeColors.divider)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: SlekkeColors.divider)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: SlekkeColors.primary)),
                                  ),
                                  onSubmitted: (_) => _saveName(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _savingName
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: SlekkeColors.primary))
                                  : IconButton(
                                      icon: const Icon(Icons.check,
                                          size: 16, color: SlekkeColors.success),
                                      onPressed: _saveName,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Save',
                                    ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: SlekkeColors.textMuted),
                                onPressed: () =>
                                    setState(() => _editingName = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Cancel',
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName.isNotEmpty ? displayName : '—',
                                  style: const TextStyle(
                                    color: SlekkeColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 15, color: SlekkeColors.textMuted),
                                onPressed: () {
                                  _nameCtrl.text = displayName;
                                  setState(() => _editingName = true);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit nickname',
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            color: SlekkeColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          label: 'Account Info',
          children: [
            _InfoRow(
                label: 'Nickname',
                value: displayName.isNotEmpty ? displayName : '—'),
            _InfoRow(label: 'Email', value: email, divider: false),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _InfoRow({
    required this.label,
    required this.value,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SlekkeColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: SlekkeColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (divider)
          const Divider(height: 1, indent: 16, endIndent: 16, color: SlekkeColors.divider),
      ],
    );
  }
}

// ─── Appearance section ───────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return _SectionScroll(
      title: 'Appearance',
      children: [
        _SettingsGroup(
          label: 'Display',
          children: [
            _ToggleRow(
              title: 'Compact sidebar',
              subtitle: 'Reduce sidebar padding and icon sizes',
              value: settings.compactSidebar,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(compactSidebar: v)),
            ),
            _DensityRow(settings: settings, notifier: notifier),
          ],
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        _SettingsGroup(
          label: 'Profile banner',
          children: [
            _BannerColorRow(settings: settings, notifier: notifier),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          label: 'Text',
          children: [
            _FontScaleRow(settings: settings, notifier: notifier),
          ],
        ),
      ],
    );
  }
}

class _DensityRow extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _DensityRow({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Message density',
            style: TextStyle(
              color: SlekkeColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: MessageDensity.values.map((d) {
              final selected = settings.messageDensity == d;
              final label = switch (d) {
                MessageDensity.compact => 'Compact',
                MessageDensity.comfortable => 'Comfortable',
                MessageDensity.spacious => 'Spacious',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      notifier.update(settings.copyWith(messageDensity: d)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? SlekkeColors.elevated
                          : SlekkeColors.inputBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: selected
                            ? SlekkeColors.textMuted
                            : SlekkeColors.divider,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? SlekkeColors.textPrimary
                            : SlekkeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BannerColorRow extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;

  const _BannerColorRow({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final hex = settings.bannerColorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _pickColor(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: settings.bannerColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SlekkeColors.divider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Banner colour',
                      style: TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$hex',
                      style: const TextStyle(
                        color: SlekkeColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.colorize_outlined, size: 15, color: SlekkeColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _pickColor(BuildContext context) {
    Color draft = settings.bannerColor;
    final hexCtrl = TextEditingController(
      text: colorToHex(draft, includeHashSign: false, enableAlpha: false),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void syncHex(Color c) {
            setDialogState(() => draft = c);
            hexCtrl.text = colorToHex(c, includeHashSign: false, enableAlpha: false);
            hexCtrl.selection = TextSelection.collapsed(offset: hexCtrl.text.length);
          }

          return Dialog(
            child: SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BANNER COLOUR',
                      style: TextStyle(
                        color: SlekkeColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SlidePicker(
                      pickerColor: draft,
                      onColorChanged: syncHex,
                      colorModel: ColorModel.hsv,
                      enableAlpha: false,
                      displayThumbColor: true,
                      showParams: false,
                      showIndicator: false,
                      sliderSize: const Size(double.infinity, 28),
                    ),
                    const SizedBox(height: 14),
                    // Hex input
                    Row(
                      children: [
                        const Text(
                          '#',
                          style: TextStyle(
                            color: SlekkeColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: hexCtrl,
                            style: const TextStyle(
                              color: SlekkeColors.textPrimary,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              hintText: 'RRGGBB',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (v) {
                              if (v.length == 6) {
                                final parsed = colorFromHex('#$v');
                                if (parsed != null) {
                                  setDialogState(() => draft = parsed);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Live preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(height: 36, color: draft),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: SlekkeColors.textMuted,
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: SlekkeColors.textPrimary,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            notifier.update(
                              settings.copyWith(bannerColorValue: draft.toARGB32()),
                            );
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FontScaleRow extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _FontScaleRow({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Font size',
                style: TextStyle(
                  color: SlekkeColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(settings.fontScale * 100).round()}%',
                style: const TextStyle(
                  color: SlekkeColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.fontScale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            activeColor: SlekkeColors.textSecondary,
            inactiveColor: SlekkeColors.elevated,
            thumbColor: SlekkeColors.textPrimary,
            onChanged: (v) =>
                notifier.update(settings.copyWith(fontScale: v)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('80%', style: TextStyle(color: SlekkeColors.textMuted, fontSize: 10)),
              Text('100%', style: TextStyle(color: SlekkeColors.textMuted, fontSize: 10)),
              Text('140%', style: TextStyle(color: SlekkeColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Notifications section ────────────────────────────────────────────────────

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _SectionScroll(
      title: 'Notifications',
      children: [
        _SettingsGroup(
          children: [
            _ToggleRow(
              title: 'Enable notifications',
              subtitle: 'Master toggle for all notifications',
              value: s.notificationsEnabled,
              onChanged: (v) => n.update(s.copyWith(notificationsEnabled: v)),
              divider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AbsorbPointer(
          absorbing: !s.notificationsEnabled,
          child: AnimatedOpacity(
            opacity: s.notificationsEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 150),
            child: Column(
              children: [
                _SettingsGroup(
                  label: 'Notify me about',
                  children: [
                    _ToggleRow(
                      title: 'Direct messages',
                      value: s.notifyDirectMessages,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyDirectMessages: v)),
                    ),
                    _ToggleRow(
                      title: 'Mentions',
                      value: s.notifyMentions,
                      onChanged: (v) => n.update(s.copyWith(notifyMentions: v)),
                    ),
                    _ToggleRow(
                      title: 'All channel messages',
                      value: s.notifyAllChannelMessages,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyAllChannelMessages: v)),
                    ),
                    _ToggleRow(
                      title: 'New channel created',
                      value: s.notifyChannelCreated,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyChannelCreated: v)),
                    ),
                    _ToggleRow(
                      title: 'Organisation updates',
                      value: s.notifyOrgUpdates,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyOrgUpdates: v)),
                    ),
                    _ToggleRow(
                      title: 'Member joined',
                      value: s.notifyMemberJoined,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyMemberJoined: v)),
                      divider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsGroup(
                  label: 'Notification style',
                  children: [
                    _ToggleRow(
                      title: 'Sound',
                      value: s.notifySoundEnabled,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifySoundEnabled: v)),
                    ),
                    _ToggleRow(
                      title: 'Show message preview',
                      value: s.notifyShowPreview,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyShowPreview: v)),
                    ),
                    _ToggleRow(
                      title: 'Desktop badge',
                      value: s.notifyDesktopBadge,
                      onChanged: (v) =>
                          n.update(s.copyWith(notifyDesktopBadge: v)),
                      divider: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Privacy section ──────────────────────────────────────────────────────────

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _SectionScroll(
      title: 'Privacy',
      children: [
        _SettingsGroup(
          label: 'Presence',
          children: [
            _ToggleRow(
              title: 'Show online status',
              subtitle: 'Let others see when you are active',
              value: s.showOnlineStatus,
              onChanged: (v) => n.update(s.copyWith(showOnlineStatus: v)),
              divider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          label: 'Messaging',
          children: [
            _ToggleRow(
              title: 'Send read receipts',
              subtitle: 'Let others know you have read their messages',
              value: s.sendReadReceipts,
              onChanged: (v) => n.update(s.copyWith(sendReadReceipts: v)),
            ),
            _ToggleRow(
              title: 'Allow direct messages from anyone',
              subtitle: 'Members outside shared organisations can message you',
              value: s.allowDMsFromAll,
              onChanged: (v) => n.update(s.copyWith(allowDMsFromAll: v)),
              divider: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsGroup(
          label: 'Profile',
          children: [
            _ToggleRow(
              title: 'Show email on profile',
              subtitle: 'Your email address is visible to other members',
              value: s.showEmailOnProfile,
              onChanged: (v) => n.update(s.copyWith(showEmailOnProfile: v)),
              divider: false,
            ),
          ],
        ),
      ],
    );
  }
}
