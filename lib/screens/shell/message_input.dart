import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

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

  void _stopTyping() {
    if (!_isTyping) return;
    _isTyping = false;
    _typingTimer?.cancel();
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(firestoreServiceProvider).clearTyping(
      channelId: widget.channelId,
      userId: user.uid,
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

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
      // If sending into a DM channel, also update the DM's lastMessageAt
      // so the sidebar preview and notification watcher stay current.
      final isDm = ref.read(selectedDmIdProvider) == widget.channelId;
      if (isDm && text.isNotEmpty) {
        svc.updateDmLastMessage(
            dmId: widget.channelId, lastMessage: text, authorId: user.uid);
      }
      await svc.sendMessage(
        channelId: widget.channelId,
        content: text,
        authorId: user.uid,
        authorName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ?? user.displayName ?? 'Unknown',
        authorPhotoUrl: ref.read(currentUserProfileProvider).valueOrNull?.photoUrl ?? user.photoURL,
        shellId: ref.read(selectedShellIdProvider),
        orgId: ref.read(selectedOrgIdProvider),
        channelName: ref.read(selectedChannelProvider)?.name,
        shellName: ref.read(selectedShellProvider)?.name,
        categoryId: ref.read(selectedChannelProvider)?.categoryId,
        replyToId: replyTo?.id,
        replyToContent: replyTo?.content,
        replyToAuthorName: replyTo?.authorName,
        replyToAuthorId: replyTo?.authorId,
        imageUrls: imageUrls,
      );

      _ctrl.clear();
      setState(() => _attachments = []);
      ref.read(replyToMessageProvider.notifier).state = null;
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _send();
                      }
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
