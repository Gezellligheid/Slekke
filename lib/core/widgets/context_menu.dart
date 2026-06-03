import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ContextMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final Color? color;
  final bool dividerAbove;

  const ContextMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.color,
    this.dividerAbove = false,
  });
}

Future<T?> showContextMenu<T>({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuItem<T>> items,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    transitionBuilder: (ctx, anim, secondary, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOut),
        ),
        alignment: Alignment.topLeft,
        child: child,
      ),
    ),
    pageBuilder: (ctx, anim1, anim2) {
      final size = MediaQuery.of(ctx).size;
      // Clamp so the menu doesn't go off-screen
      const menuWidth = 200.0;
      const itemHeight = 36.0;
      final menuHeight = items.fold<double>(
        8,
        (h, item) => h + itemHeight + (item.dividerAbove ? 9 : 0),
      );
      final dx =
          (position.dx + menuWidth > size.width) ? size.width - menuWidth - 8 : position.dx;
      final dy =
          (position.dy + menuHeight > size.height) ? size.height - menuHeight - 8 : position.dy;

      return Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: dx,
            top: dy,
            child: Material(
              color: Colors.transparent,
              child: _ContextMenuCard(
                items: items,
                onSelect: (v) => Navigator.of(ctx).pop(v),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ContextMenuCard<T> extends StatelessWidget {
  final List<ContextMenuItem<T>> items;
  final ValueChanged<T> onSelect;

  const _ContextMenuCard({required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: SlekkeColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SlekkeColors.elevated),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.dividerAbove)
                const Divider(height: 9, thickness: 1, color: SlekkeColors.divider),
              _ContextMenuRow(item: item, onSelect: onSelect),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ContextMenuRow<T> extends StatefulWidget {
  final ContextMenuItem<T> item;
  final ValueChanged<T> onSelect;
  const _ContextMenuRow({required this.item, required this.onSelect});

  @override
  State<_ContextMenuRow<T>> createState() => _ContextMenuRowState<T>();
}

class _ContextMenuRowState<T> extends State<_ContextMenuRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.item.color ??
        (_hovered ? SlekkeColors.textPrimary : SlekkeColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.item.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 36,
          color: _hovered
              ? SlekkeColors.elevated.withAlpha(120)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 14, color: fg),
              const SizedBox(width: 10),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
