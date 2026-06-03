import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'models/dm_model.dart';
import 'providers/firestore_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

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
        _lastDmTimes[dm.id] = dm.lastMessageAt;
        final newTime = dm.lastMessageAt;
        if (newTime == null || prevTime == null) continue;
        if (newTime.isAfter(prevTime)) {
          ref.read(notificationServiceProvider).onNewMessage(
                channelId: dm.id,
                isDm: true,
              );
          break; // one sound per batch update
        }
      }
    });

    // ── Channel notifications via single org metadata stream ─────────────────
    final orgId = ref.watch(selectedOrgIdProvider);
    if (orgId != null) {
      ref.listen<AsyncValue<Map<String, DateTime?>>>(
        orgChannelMetaProvider(orgId),
        (prev, next) {
          final prevMeta = prev?.valueOrNull;
          final nextMeta = next.valueOrNull;
          if (prevMeta == null || nextMeta == null) return;
          for (final entry in nextMeta.entries) {
            final newTime = entry.value;
            final oldTime = prevMeta[entry.key];
            if (newTime == null) continue;
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
