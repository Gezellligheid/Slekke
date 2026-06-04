import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays a circular avatar that handles three sources:
///   • base64 data URL  (data:image/...;base64,...)
///   • regular https URL
///   • null / missing → shows initials fallback
///
/// Decodes base64 only once; re-decodes only when [photoUrl] actually changes.
class UserAvatar extends StatefulWidget {
  final String? photoUrl;
  final String name;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 32,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode(widget.photoUrl);
  }

  @override
  void didUpdateWidget(UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.photoUrl != widget.photoUrl) _decode(widget.photoUrl);
  }

  void _decode(String? url) {
    if (url != null && url.startsWith('data:')) {
      _bytes = base64Decode(url.split(',').last);
    } else {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl;
    final initial =
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    Widget content;
    if (_bytes != null) {
      content = Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, loaded) =>
            (loaded || frame != null) ? child : const SizedBox.shrink(),
        errorBuilder: (ctx, e, s) => _initials(initial),
      );
    } else if (url != null && url.isNotEmpty && url.startsWith('http')) {
      content = CachedNetworkImage(
        imageUrl: url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (ctx, u) => const SizedBox.shrink(),
        errorWidget: (ctx, u, e) => _initials(initial),
      );
    } else {
      content = _initials(initial);
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SlekkeColors.elevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _initials(String initial) => Center(
        child: Text(
          initial,
          style: TextStyle(
            color: SlekkeColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: widget.size * 0.4,
          ),
        ),
      );
}
