import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'models/dm_model.dart';
import 'providers/auth_provider.dart';
import 'providers/firestore_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';

class SlekkeApp extends ConsumerWidget {
  const SlekkeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationServiceProvider); // registers lifecycle observer
    final router = ref.watch(appRouterProvider);
    final fontScale = ref.watch(settingsProvider.select((s) => s.fontScale));
    return MaterialApp.router(
      title: 'Slekke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale),
        ),
        child: _DmNotificationWatcher(child: child!),
      ),
    );
  }
}

// Watches all DM message streams in the background so notifications fire
// even when the user is not currently viewing that conversation.
class _DmNotificationWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const _DmNotificationWatcher({required this.child});

  @override
  ConsumerState<_DmNotificationWatcher> createState() =>
      _DmNotificationWatcherState();
}

class _DmNotificationWatcherState
    extends ConsumerState<_DmNotificationWatcher> {
  // Track the last-seen lastMessageAt per DM so we detect new messages
  // via the single userDmsProvider stream instead of N per-DM message streams.
  final Map<String, DateTime?> _lastDmTimes = {};
  bool _dmSeeded = false;

  @override
  Widget build(BuildContext context) {
    // Initialise push notifications once the user is signed in
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      PushNotificationService.initialize(ref);
    }

    // ── DM notifications via single stream ──────────────────────────────────
    ref.listen<AsyncValue<List<DmModel>>>(userDmsProvider, (prev, next) {
      final dms = next.valueOrNull;
      if (dms == null) return;

      if (!_dmSeeded) {
        for (final dm in dms) {
          _lastDmTimes[dm.id] = dm.lastMessageAt;
        }
        _dmSeeded = true;
        return;
      }

      for (final dm in dms) {
        final prevTime = _lastDmTimes[dm.id];
        final newTime = dm.lastMessageAt;
        _lastDmTimes[dm.id] = newTime;

        if (newTime == null) continue;

        final sentByMe = dm.lastMessageAuthorId != null &&
            dm.lastMessageAuthorId == ref.read(currentUserProvider)?.uid;
        if (sentByMe) continue;

        // New DM conversation not yet tracked → treat as new message
        // Existing DM → only notify if lastMessageAt actually advanced
        if (prevTime != null && !newTime.isAfter(prevTime)) continue;

        ref.read(notificationServiceProvider).onNewMessage(
              channelId: dm.id,
              isDm: true,
              senderName: dm.other(ref.read(currentUserProvider)?.uid ?? '').displayName,
              preview: dm.lastMessage,
            );
        break; // one sound per batch update
      }
    });

    // ── Channel notifications via single org metadata stream ─────────────────
    final orgId = ref.watch(selectedOrgIdProvider);
    final currentUid = ref.watch(currentUserProvider)?.uid;
    if (orgId != null) {
      ref.listen<AsyncValue<Map<String, ({DateTime? at, String? authorId})>>>(
        orgChannelMetaProvider(orgId),
        (prev, next) {
          final prevMeta = prev?.valueOrNull;
          final nextMeta = next.valueOrNull;
          if (prevMeta == null || nextMeta == null) return;
          for (final entry in nextMeta.entries) {
            final newTime = entry.value.at;
            final oldTime = prevMeta[entry.key]?.at;
            final authorId = entry.value.authorId;
            if (newTime == null) continue;
            if (authorId != null && authorId == currentUid) continue;
            if (oldTime == null || newTime.isAfter(oldTime)) {
              ref
                  .read(notificationServiceProvider)
                  .onNewMessage(channelId: entry.key);
            }
          }
        },
      );
    }

    return widget.child;
  }
}
