import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firestore_provider.dart';
import '../providers/settings_provider.dart';
import 'sound_player.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

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

  void onNewMessage({required String channelId, bool isDm = false}) {
    final settings = _ref.read(settingsProvider);

    // Master toggle gates everything
    if (!settings.notificationsEnabled) return;

    // Type-specific toggles
    if (isDm && !settings.notifyDirectMessages) return;
    if (!isDm && !settings.notifyAllChannelMessages) return;

    // Sound toggle — badges still show regardless, only sound is gated here
    if (!settings.notifySoundEnabled) return;

    // Don't sound if the user is already looking at that conversation
    if (_appFocused) {
      final selectedChannel = _ref.read(selectedChannelProvider);
      final selectedDmId = _ref.read(selectedDmIdProvider);
      final dmMode = _ref.read(dmModeProvider);
      if (isDm && dmMode && selectedDmId == channelId) return;
      if (!isDm && !dmMode && selectedChannel?.id == channelId) return;
    }

    playNotificationSound();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
