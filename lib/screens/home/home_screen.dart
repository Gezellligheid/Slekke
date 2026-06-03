import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/channel_model.dart';
import '../../models/organization_model.dart';
import '../../providers/firestore_provider.dart';
import '../../services/session_service.dart';
import '../dm/dm_conversation_view.dart';
import '../dm/dm_sidebar.dart';
import '../onboarding/create_or_join_screen.dart';
import '../shell/channel_view.dart';
import '../shell/org_switcher.dart';
import '../shell/shell_sidebar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _onboardingOpen = false;
  bool _sessionRestored = false;

  Future<void> _initSession(List<OrganizationModel> orgs) async {
    final session = await SessionService.load();

    if (session == null) {
      // No saved session — fall back to selecting the first org
      if (!ref.read(dmModeProvider) && ref.read(selectedOrgIdProvider) == null) {
        ref.read(selectedOrgIdProvider.notifier).state = orgs.first.id;
      }
      return;
    }

    if (session.isDm && session.dmId != null) {
      ref.read(dmModeProvider.notifier).state = true;
      ref.read(selectedDmIdProvider.notifier).state = session.dmId;
      return;
    }

    // Channel session
    final orgId = session.orgId;
    final shellId = session.shellId;
    final categoryId = session.categoryId;
    final channelId = session.channelId;

    if (orgId == null || shellId == null || categoryId == null || channelId == null) {
      ref.read(selectedOrgIdProvider.notifier).state = orgs.first.id;
      return;
    }

    // Verify org still exists
    if (!orgs.any((o) => o.id == orgId)) {
      ref.read(selectedOrgIdProvider.notifier).state = orgs.first.id;
      return;
    }

    ref.read(dmModeProvider.notifier).state = false;
    ref.read(selectedOrgIdProvider.notifier).state = orgId;
    ref.read(selectedShellIdProvider.notifier).state = shellId;

    final channel = await ref.read(firestoreServiceProvider).getChannelById(
      orgId: orgId,
      shellId: shellId,
      categoryId: categoryId,
      channelId: channelId,
    );
    if (mounted && channel != null) {
      ref.read(selectedChannelStateProvider.notifier).state = channel;
    }
  }

  void _showOnboarding() {
    if (_onboardingOpen) return;
    _onboardingOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _onboardingOpen = false;
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CreateOrJoinDialog(),
      ).then((_) {
        if (mounted) setState(() => _onboardingOpen = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(userOrgsProvider);
    final selectedOrgId = ref.watch(selectedOrgIdProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final dmMode = ref.watch(dmModeProvider);
    final selectedDmId = ref.watch(selectedDmIdProvider);
    final dmsAsync = ref.watch(userDmsProvider);

    // Restore last session once orgs have loaded
    ref.listen<AsyncValue<List<OrganizationModel>>>(userOrgsProvider, (_, next) {
      final orgs = next.valueOrNull;
      if (orgs == null || orgs.isEmpty || _sessionRestored) return;
      _sessionRestored = true;
      _initSession(orgs);
    });

    // Save session whenever channel or DM selection changes
    ref.listen<ChannelModel?>(selectedChannelStateProvider, (_, next) {
      if (next == null) return;
      SessionService.saveChannel(
        orgId: next.organizationId,
        shellId: next.shellId,
        categoryId: next.categoryId,
        channelId: next.id,
      );
    });

    ref.listen<String?>(selectedDmIdProvider, (_, next) {
      if (next == null) return;
      if (ref.read(dmModeProvider)) SessionService.saveDm(next);
    });

    return orgsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: SlekkeColors.background,
        body: Center(
            child:
                CircularProgressIndicator(color: SlekkeColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: SlekkeColors.background,
        body: Center(
            child: Text('Error: $e',
                style:
                    const TextStyle(color: SlekkeColors.danger))),
      ),
      data: (orgs) {

        if (orgs.isEmpty && selectedOrgId == null && !dmMode) {
          _showOnboarding();
          return const Scaffold(
            backgroundColor: SlekkeColors.background,
            body: SizedBox.shrink(),
          );
        }

        // Resolve main content
        Widget mainContent;
        if (dmMode) {
          final dms = dmsAsync.valueOrNull ?? [];
          final dm = selectedDmId != null
              ? dms.where((d) => d.id == selectedDmId).firstOrNull
              : null;
          mainContent = dm != null
              ? DmConversationView(key: ValueKey(dm.id), dm: dm)
              : const _DmPlaceholder();
        } else if (selectedChannel != null) {
          mainContent = ChannelView(channel: selectedChannel);
        } else {
          mainContent = const _NoChannelPlaceholder();
        }

        return Scaffold(
          backgroundColor: SlekkeColors.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OrgSwitcher(),
              if (dmMode)
                const DmSidebar()
              else if (selectedOrgId != null)
                const ShellSidebar(),
              Expanded(child: mainContent),
            ],
          ),
        );
      },
    );
  }
}

class _NoChannelPlaceholder extends StatelessWidget {
  const _NoChannelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tag, size: 64, color: SlekkeColors.textMuted),
          SizedBox(height: 16),
          Text(
            'Select a channel to start chatting',
            style:
                TextStyle(color: SlekkeColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DmPlaceholder extends StatelessWidget {
  const _DmPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: SlekkeColors.textMuted),
          SizedBox(height: 16),
          Text(
            'Select a conversation',
            style:
                TextStyle(color: SlekkeColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
