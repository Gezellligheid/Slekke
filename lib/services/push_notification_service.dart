import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/notify_config.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';

/// Top-level handler required by firebase_messaging for background isolates.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // On mobile/desktop the OS shows the notification automatically.
}

class PushNotificationService {
  static bool _initialized = false;

  // Called from a ConsumerState widget, so we use WidgetRef.
  static Future<void> initialize(WidgetRef ref) async {
    if (_initialized) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) return;

    _initialized = true;
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _initialized = false;
      return;
    }

    await _saveToken(ref, messaging);
    messaging.onTokenRefresh.listen((_) => _saveToken(ref, messaging));

    FirebaseMessaging.onMessage.listen((_) {
      // Foreground: in-app sound/badge system already handles this.
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _navigate(ref, msg));

    final initial = await messaging.getInitialMessage();
    if (initial != null) _navigate(ref, initial);
  }

  static Future<void> _saveToken(WidgetRef ref, FirebaseMessaging messaging) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final token = await messaging.getToken(
      vapidKey: kIsWeb ? NotifyConfig.webVapidKey : null,
    );
    if (token == null) return;
    // ignore: avoid_print
    print('🔔 FCM TOKEN: $token');

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

    await ref
        .read(firestoreServiceProvider)
        .saveFcmToken(uid: uid, token: token, platform: platform);
  }

  static void _navigate(WidgetRef ref, RemoteMessage msg) {
    final data = msg.data;
    final type = data['type'];

    if (type == 'dm') {
      final dmId = data['dmId'] as String?;
      if (dmId == null) return;
      ref.read(dmModeProvider.notifier).state = true;
      ref.read(selectedDmIdProvider.notifier).state = dmId;
    } else if (type == 'channel') {
      final orgId   = data['orgId']   as String?;
      final shellId = data['shellId'] as String?;
      if (orgId == null) return;
      ref.read(dmModeProvider.notifier).state = false;
      ref.read(selectedOrgIdProvider.notifier).state = orgId;
      if (shellId != null && shellId.isNotEmpty) {
        ref.read(selectedShellIdProvider.notifier).state = shellId;
      }
    }
  }
}
