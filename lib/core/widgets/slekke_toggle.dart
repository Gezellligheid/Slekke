import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SlekkeToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SlekkeToggle({super.key, required this.value, required this.onChanged});

  @override
  State<SlekkeToggle> createState() => _SlekkeToggleState();
}

class _SlekkeToggleState extends State<SlekkeToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const _w = 34.0;
  static const _h = 18.0;
  static const _thumb = 12.0;
  static const _pad = 3.0;
  static const _travel = _w - _thumb - _pad * 2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      value: widget.value ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(SlekkeToggle old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value;
            final trackColor = Color.lerp(
              SlekkeColors.elevated,
              SlekkeColors.success.withAlpha(180),
              t,
            )!;
            final thumbColor =
                Color.lerp(SlekkeColors.textMuted, Colors.white, t)!;

            return Container(
              width: _w,
              height: _h,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(_h / 2),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: _pad + _travel * t,
                    top: _pad,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
