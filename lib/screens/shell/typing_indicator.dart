import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/firestore_provider.dart';

class TypingIndicator extends ConsumerWidget {
  final String channelId;
  const TypingIndicator({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(typingProvider(channelId)).valueOrNull ?? [];

    final label = switch (typing.length) {
      0 => null,
      1 => '${typing[0]} is typing',
      2 => '${typing[0]} and ${typing[1]} are typing',
      _ => 'Several people are typing',
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: Alignment.bottomLeft,
      child: label == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
              child: Row(
                children: [
                  const _BouncingDots(),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: SlekkeColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Animated dots ────────────────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          // Each dot leads by 0.2 of the cycle, clamped to a sine bounce
          final phase = (_ctrl.value - i * 0.2) % 1.0;
          final bounce =
              phase < 0.5 ? math.sin(phase * math.pi) * 4.0 : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Transform.translate(
              offset: Offset(0, -bounce),
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SlekkeColors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
