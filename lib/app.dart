import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
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
  final Set<String> _seededDms = {};

  @override
  Widget build(BuildContext context) {
    final dms = ref.watch(userDmsProvider).valueOrNull ?? [];

    for (final dm in dms) {
      ref.listen<AsyncValue<List>>(messagesProvider(dm.id), (prev, next) {
        final msgs = next.valueOrNull;
        if (msgs == null) return;
        if (!_seededDms.contains(dm.id)) {
          _seededDms.add(dm.id);
          return;
        }
        final prevCount = prev?.valueOrNull?.length ?? 0;
        if (msgs.length > prevCount) {
          ref.read(notificationServiceProvider).onNewMessage(
                channelId: dm.id,
                isDm: true,
              );
        }
      });
    }

    return widget.child;
  }
}
