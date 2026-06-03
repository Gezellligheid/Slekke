import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../models/dm_model.dart';
import '../models/org_role_model.dart';
import '../models/organization_model.dart';
import '../models/shell_model.dart';
import '../models/category_model.dart';
import '../models/channel_model.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchUserProfile(user.uid);
});

// ── Selected state ────────────────────────────────────────────────────────────

final selectedOrgIdProvider = StateProvider<String?>((ref) => null);
final selectedShellIdProvider = StateProvider<String?>((ref) => null);
final selectedChannelIdProvider = StateProvider<String?>((ref) => null);

// ── Organizations ─────────────────────────────────────────────────────────────

final userOrgsProvider = StreamProvider<List<OrganizationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchUserOrgsFlat(user.uid);
});

final selectedOrgProvider = Provider<OrganizationModel?>((ref) {
  final orgId = ref.watch(selectedOrgIdProvider);
  final orgs = ref.watch(userOrgsProvider).valueOrNull ?? [];
  if (orgId == null) return null;
  try {
    return orgs.firstWhere((o) => o.id == orgId);
  } catch (_) {
    return null;
  }
});

// ── Shells ────────────────────────────────────────────────────────────────────

final shellsProvider = StreamProvider<List<ShellModel>>((ref) {
  final orgId = ref.watch(selectedOrgIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchShells(orgId);
});

final selectedShellProvider = Provider<ShellModel?>((ref) {
  final shellId = ref.watch(selectedShellIdProvider);
  final shells = ref.watch(shellsProvider).valueOrNull ?? [];
  if (shellId == null) return null;
  try {
    return shells.firstWhere((s) => s.id == shellId);
  } catch (_) {
    return null;
  }
});

// ── Categories ────────────────────────────────────────────────────────────────

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final orgId = ref.watch(selectedOrgIdProvider);
  final shellId = ref.watch(selectedShellIdProvider);
  if (orgId == null || shellId == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchCategories(orgId, shellId);
});

// ── Channels ──────────────────────────────────────────────────────────────────

final channelsProvider = StreamProvider.family<List<ChannelModel>, String>(
  (ref, categoryId) {
    final orgId = ref.watch(selectedOrgIdProvider);
    final shellId = ref.watch(selectedShellIdProvider);
    if (orgId == null || shellId == null) return const Stream.empty();
    return ref
        .watch(firestoreServiceProvider)
        .watchChannels(orgId, shellId, categoryId);
  },
);

// Public mutable state for the selected channel
final selectedChannelStateProvider = StateProvider<ChannelModel?>((ref) => null);

final selectedChannelProvider = Provider<ChannelModel?>((ref) {
  return ref.watch(selectedChannelStateProvider);
});

// ── Messages ──────────────────────────────────────────────────────────────────

final messagesProvider = StreamProvider.family<List<MessageModel>, String>(
  (ref, channelId) {
    return ref.watch(firestoreServiceProvider).watchMessages(channelId);
  },
);

// Reply-to state
final replyToMessageProvider = StateProvider<MessageModel?>((ref) => null);

// ── Direct Messages ───────────────────────────────────────────────────────────

final dmModeProvider = StateProvider<bool>((ref) => false);
final selectedDmIdProvider = StateProvider<String?>((ref) => null);

final userDmsProvider = StreamProvider<List<DmModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchUserDms(user.uid);
});

// ── Org Roles & Permissions ───────────────────────────────────────────────────

final orgRolesProvider = StreamProvider<List<OrgRole>>((ref) {
  final orgId = ref.watch(selectedOrgIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchOrgRoles(orgId);
});

final orgMemberRolesProvider = StreamProvider<List<OrgMemberRoles>>((ref) {
  final orgId = ref.watch(selectedOrgIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).watchOrgMemberRoles(orgId);
});

final currentUserOrgPermissionsProvider = Provider<OrgPermissions>((ref) {
  final user = ref.watch(currentUserProvider);
  final org = ref.watch(selectedOrgProvider);
  final roles = ref.watch(orgRolesProvider).valueOrNull ?? [];
  final memberRoles = ref.watch(orgMemberRolesProvider).valueOrNull ?? [];

  if (user == null) return const OrgPermissions();
  // Org owner always has all permissions
  if (org?.ownerId == user.uid) return OrgPermissions.all;

  final everyone =
      roles.where((r) => r.isEveryone).firstOrNull?.permissions ??
          const OrgPermissions(inviteMembers: true);

  final myRoleIds = memberRoles
      .where((m) => m.userId == user.uid)
      .expand((m) => m.roleIds)
      .toSet();

  return roles
      .where((r) => myRoleIds.contains(r.id))
      .fold(everyone, (acc, role) => acc | role.permissions);
});

// ── Typing ────────────────────────────────────────────────────────────────────

final typingProvider =
    StreamProvider.family<List<String>, String>((ref, channelId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(firestoreServiceProvider)
      .watchTyping(channelId, user.uid);
});
