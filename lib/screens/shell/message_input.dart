import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/emoji_converter.dart';
import '../../core/config/notify_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';
import 'gif_picker.dart';

// Use the global storageServiceProvider from firestore_provider.dart
// (keeping a local alias so the rest of this file doesn't need changes)
final _storageServiceProvider = storageServiceProvider;

class MessageInput extends ConsumerStatefulWidget {
  final String channelId;
  const MessageInput({super.key, required this.channelId});

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  List<File> _attachments = [];
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(MessageInput old) {
    super.didUpdateWidget(old);
    if (old.channelId != widget.channelId) {
      // Clear the typing indicator on the OLD channel immediately —
      // dispose() won't be called when the channel prop just changes.
      _stopTyping(old.channelId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _stopTyping();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      _stopTyping();
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      _pushTyping();
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _stopTyping);
  }

  void _pushTyping() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(firestoreServiceProvider).setTyping(
      channelId: widget.channelId,
      userId: user.uid,
      displayName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ?? user.displayName ?? 'Someone',
    );
  }

  void _stopTyping([String? channelId]) {
    if (!_isTyping) return;
    _isTyping = false;
    _typingTimer?.cancel();
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(firestoreServiceProvider).clearTyping(
      channelId: channelId ?? widget.channelId,
      userId: user.uid,
    );
  }

  Future<void> _send() async {
    final text = convertAsciiEmoji(_ctrl.text.trim());
    if (text.isEmpty && _attachments.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Clear immediately so rapid Enter presses don't duplicate the message.
    // Restored in the catch block if the send fails.
    _ctrl.clear();
    _onTextChanged(''); // reset typing state
    setState(() => _sending = true);

    try {
      // Upload images first
      List<String> imageUrls = [];
      if (_attachments.isNotEmpty) {
        final storage = ref.read(_storageServiceProvider);
        for (final file in _attachments) {
          final url = await storage.uploadMessageImage(
            channelId: widget.channelId,
            file: file,
          );
          imageUrls.add(url);
        }
      }

      final replyTo = ref.read(replyToMessageProvider);

      _stopTyping();
      final svc = ref.read(firestoreServiceProvider);
      final isDm = ref.read(selectedDmIdProvider) == widget.channelId;

      // Mark as read BEFORE sending so our own message doesn't flash as unread.
      if (isDm) {
        svc.markDmRead(user.uid, widget.channelId);
        if (text.isNotEmpty) {
          svc.updateDmLastMessage(
              dmId: widget.channelId, lastMessage: text, authorId: user.uid);
        }
      } else {
        svc.markChannelRead(user.uid, widget.channelId);
      }

      await svc.sendMessage(
        channelId: widget.channelId,
        content: text,
        authorId: user.uid,
        authorName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ?? user.displayName ?? 'Unknown',
        authorPhotoUrl: ref.read(currentUserProfileProvider).valueOrNull?.photoUrl ?? user.photoURL,
        // DMs must not carry org/shell metadata — otherwise the flat channels
        // doc gets tagged with the sender's current org and appears as an
        // unread channel in watchOrgChannelMeta.
        shellId: isDm ? null : ref.read(selectedShellIdProvider),
        orgId: isDm ? null : ref.read(selectedOrgIdProvider),
        channelName: isDm ? null : ref.read(selectedChannelProvider)?.name,
        shellName: isDm ? null : ref.read(selectedShellProvider)?.name,
        categoryId: isDm ? null : ref.read(selectedChannelProvider)?.categoryId,
        replyToId: replyTo?.id,
        replyToContent: replyTo?.content,
        replyToAuthorName: replyTo?.authorName,
        replyToAuthorId: replyTo?.authorId,
        imageUrls: imageUrls,
      );

      // Post-send mark-as-read: guarantees lastReadAt ≥ lastMessageAt
      // even if the pre-send mark lost the server-timestamp race.
      if (isDm) {
        svc.markDmRead(user.uid, widget.channelId);
      } else {
        svc.markChannelRead(user.uid, widget.channelId);
      }

      setState(() => _attachments = []);
      ref.read(replyToMessageProvider.notifier).state = null;
      _focusNode.requestFocus();

      // Fire push notification via Vercel (best-effort, don't await)
      _notifyVercel(
        channelId: widget.channelId,
        authorId: user.uid,
        authorName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ?? user.displayName ?? 'Someone',
        content: text,
        imageCount: imageUrls.length,
        orgId: isDm ? null : ref.read(selectedOrgIdProvider),
        shellId: isDm ? null : ref.read(selectedShellIdProvider),
        channelName: isDm ? null : ref.read(selectedChannelProvider)?.name,
      );
    } catch (e) {
      // Restore text so the user can retry without retyping.
      if (mounted) {
        _ctrl.text = text;
        _ctrl.selection = TextSelection.collapsed(offset: text.length);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendGif(String gifUrl) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final svc = ref.read(firestoreServiceProvider);
      final isDm = ref.read(selectedDmIdProvider) == widget.channelId;
      if (isDm) {
        svc.markDmRead(user.uid, widget.channelId);
      } else {
        svc.markChannelRead(user.uid, widget.channelId);
      }
      await svc.sendMessage(
        channelId: widget.channelId,
        content: '',
        authorId: user.uid,
        authorName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ??
            user.displayName ?? 'Unknown',
        authorPhotoUrl: ref.read(currentUserProfileProvider).valueOrNull?.photoUrl ??
            user.photoURL,
        shellId: isDm ? null : ref.read(selectedShellIdProvider),
        orgId: isDm ? null : ref.read(selectedOrgIdProvider),
        channelName: isDm ? null : ref.read(selectedChannelProvider)?.name,
        shellName: isDm ? null : ref.read(selectedShellProvider)?.name,
        categoryId: isDm ? null : ref.read(selectedChannelProvider)?.categoryId,
        imageUrls: [gifUrl],
      );
      if (isDm) {
        svc.markDmRead(user.uid, widget.channelId);
      } else {
        svc.markChannelRead(user.uid, widget.channelId);
      }
      _focusNode.requestFocus();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showGifPicker(BuildContext context) {
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
          // Anchor above the message input (fixed bottom offset)
          Positioned(
            left: 16,
            bottom: 76,
            child: GifPicker(
              onSelected: (url) {
                Navigator.of(dialogCtx).pop();
                _sendGif(url);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyVercel({
    required String channelId,
    required String authorId,
    required String authorName,
    required String content,
    required int imageCount,
    String? orgId,
    String? shellId,
    String? channelName,
  }) async {
    final url = NotifyConfig.endpointUrl;
    // ignore: avoid_print
    print('📤 [notify] endpoint=$url');
    if (url.isEmpty || url.contains('YOUR-PROJECT')) {
      // ignore: avoid_print
      print('📤 [notify] skipped — endpoint not configured in notify_config.dart');
      return;
    }
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final secret = NotifyConfig.secret;
      if (secret.isNotEmpty && !secret.contains('YOUR_')) {
        headers['Authorization'] = 'Bearer $secret';
      }

      final body = jsonEncode({
        'channelId': channelId,
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
        'imageCount': imageCount,
        if (orgId != null) 'orgId': orgId,
        if (shellId != null) 'shellId': shellId,
        if (channelName != null) 'channelName': channelName,
      });
      // ignore: avoid_print
      print('📤 [notify] POST $url body=$body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      // ignore: avoid_print
      print('📤 [notify] response ${response.statusCode}: ${response.body}');
    } catch (e) {
      // ignore: avoid_print
      print('📤 [notify] error: $e');
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;
    setState(() {
      _attachments = result.paths.whereType<String>().map(File.new).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(selectedChannelProvider);
    final name = channel?.name ?? 'channel';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          if (_attachments.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                separatorBuilder: (_, i) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        _attachments[i],
                        width: 80,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _attachments.removeAt(i),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SlekkeColors.danger,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: SlekkeColors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: SlekkeColors.textMuted),
                  tooltip: 'Attach image',
                  onPressed: _sending ? null : _pickFiles,
                ),
                Builder(
                  builder: (btnCtx) => IconButton(
                    icon: const Icon(Icons.gif_outlined, color: SlekkeColors.textMuted),
                    tooltip: 'Send GIF',
                    onPressed: _sending ? null : () => _showGifPicker(btnCtx),
                  ),
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _send();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: SlekkeColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message #$name',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      enabled: !_sending,
                      onChanged: _onTextChanged,
                    ),
                  ),
                ),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SlekkeColors.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send, color: SlekkeColors.primary),
                    tooltip: 'Send (Enter)',
                    onPressed: _send,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
