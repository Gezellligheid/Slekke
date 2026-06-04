import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import '../providers/firestore_provider.dart';
import '../providers/settings_provider.dart';
import 'sound_player.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

Future<void> initLocalNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  await localNotifier.setup(appName: 'Slekke');
}

class NotificationService with WidgetsBindingObserver {
  final Ref _ref;
  bool _appFocused = true;

  NotificationService(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appFocused = state == AppLifecycleState.resumed;
  }

  void onNewMessage({
    required String channelId,
    bool isDm = false,
    String? senderName,
    String? preview,
    String? messageId,
    String? orgId,
    String? shellId,
  }) {
    final settings = _ref.read(settingsProvider);

    if (!settings.notificationsEnabled) return;
    if (isDm && !settings.notifyDirectMessages) return;
    if (!isDm && !settings.notifyAllChannelMessages) return;

    // Don't notify if the user is already looking at that conversation
    if (_appFocused) {
      final selectedChannel = _ref.read(selectedChannelProvider);
      final selectedDmId = _ref.read(selectedDmIdProvider);
      final dmMode = _ref.read(dmModeProvider);
      if (isDm && dmMode && selectedDmId == channelId) return;
      if (!isDm && !dmMode && selectedChannel?.id == channelId) return;
    }

    if (settings.notifySoundEnabled) playNotificationSound();

    // Windows toast notification
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _showWindowsToast(
        title: senderName ?? (isDm ? 'New message' : 'New channel message'),
        body: (preview?.isNotEmpty == true) ? preview : null,
        channelId: channelId,
        isDm: isDm,
        messageId: messageId,
        orgId: orgId,
        shellId: shellId,
      );
    }
  }

  void _showWindowsToast({
    required String title,
    String? body,
    required String channelId,
    required bool isDm,
    String? messageId,
    String? orgId,
    String? shellId,
  }) {
    final notification = LocalNotification(title: title, body: body);

    notification.onClick = () {
      // Navigate to the right conversation
      if (isDm) {
        _ref.read(dmModeProvider.notifier).state = true;
        _ref.read(selectedDmIdProvider.notifier).state = channelId;
      } else {
        _ref.read(dmModeProvider.notifier).state = false;
        if (orgId != null) {
          _ref.read(selectedOrgIdProvider.notifier).state = orgId;
        }
        if (shellId != null) {
          _ref.read(selectedShellIdProvider.notifier).state = shellId;
        }
      }

      // Highlight the specific message after the channel/DM view has loaded
      if (messageId != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _ref.read(highlightedMessageIdProvider.notifier).state = messageId;
        });
      }
    };

    notification.show();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
