import 'package:flutter/material.dart';

enum MessageDensity { compact, comfortable, spacious }

class AppSettings {
  final ThemeMode themeMode;
  final int accentColorValue;
  final int bannerColorValue;
  final double fontScale;
  final MessageDensity messageDensity;
  final bool compactSidebar;

  // Notifications
  final bool notificationsEnabled;
  final bool notifyDirectMessages;
  final bool notifyMentions;
  final bool notifyAllChannelMessages;
  final bool notifyChannelCreated;
  final bool notifyOrgUpdates;
  final bool notifyMemberJoined;
  final bool notifySoundEnabled;
  final bool notifyShowPreview;
  final bool notifyDesktopBadge;

  // Privacy
  final bool showOnlineStatus;
  final bool sendReadReceipts;
  final bool allowDMsFromAll;
  final bool showEmailOnProfile;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.accentColorValue = 0xFF4CA87D,
    this.bannerColorValue = 0xFF2D2D2D,
    this.fontScale = 1.0,
    this.messageDensity = MessageDensity.comfortable,
    this.compactSidebar = false,
    this.notificationsEnabled = true,
    this.notifyDirectMessages = true,
    this.notifyMentions = true,
    this.notifyAllChannelMessages = true,
    this.notifyChannelCreated = true,
    this.notifyOrgUpdates = true,
    this.notifyMemberJoined = false,
    this.notifySoundEnabled = true,
    this.notifyShowPreview = true,
    this.notifyDesktopBadge = true,
    this.showOnlineStatus = true,
    this.sendReadReceipts = true,
    this.allowDMsFromAll = true,
    this.showEmailOnProfile = false,
  });

  Color get accentColor => Color(accentColorValue);
  Color get bannerColor => Color(bannerColorValue);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentColorValue,
    int? bannerColorValue,
    double? fontScale,
    MessageDensity? messageDensity,
    bool? compactSidebar,
    bool? notificationsEnabled,
    bool? notifyDirectMessages,
    bool? notifyMentions,
    bool? notifyAllChannelMessages,
    bool? notifyChannelCreated,
    bool? notifyOrgUpdates,
    bool? notifyMemberJoined,
    bool? notifySoundEnabled,
    bool? notifyShowPreview,
    bool? notifyDesktopBadge,
    bool? showOnlineStatus,
    bool? sendReadReceipts,
    bool? allowDMsFromAll,
    bool? showEmailOnProfile,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      bannerColorValue: bannerColorValue ?? this.bannerColorValue,
      fontScale: fontScale ?? this.fontScale,
      messageDensity: messageDensity ?? this.messageDensity,
      compactSidebar: compactSidebar ?? this.compactSidebar,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyDirectMessages: notifyDirectMessages ?? this.notifyDirectMessages,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notifyAllChannelMessages: notifyAllChannelMessages ?? this.notifyAllChannelMessages,
      notifyChannelCreated: notifyChannelCreated ?? this.notifyChannelCreated,
      notifyOrgUpdates: notifyOrgUpdates ?? this.notifyOrgUpdates,
      notifyMemberJoined: notifyMemberJoined ?? this.notifyMemberJoined,
      notifySoundEnabled: notifySoundEnabled ?? this.notifySoundEnabled,
      notifyShowPreview: notifyShowPreview ?? this.notifyShowPreview,
      notifyDesktopBadge: notifyDesktopBadge ?? this.notifyDesktopBadge,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      sendReadReceipts: sendReadReceipts ?? this.sendReadReceipts,
      allowDMsFromAll: allowDMsFromAll ?? this.allowDMsFromAll,
      showEmailOnProfile: showEmailOnProfile ?? this.showEmailOnProfile,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'accentColorValue': accentColorValue,
        'bannerColorValue': bannerColorValue,
        'fontScale': fontScale,
        'messageDensity': messageDensity.index,
        'compactSidebar': compactSidebar,
        'notificationsEnabled': notificationsEnabled,
        'notifyDirectMessages': notifyDirectMessages,
        'notifyMentions': notifyMentions,
        'notifyAllChannelMessages': notifyAllChannelMessages,
        'notifyChannelCreated': notifyChannelCreated,
        'notifyOrgUpdates': notifyOrgUpdates,
        'notifyMemberJoined': notifyMemberJoined,
        'notifySoundEnabled': notifySoundEnabled,
        'notifyShowPreview': notifyShowPreview,
        'notifyDesktopBadge': notifyDesktopBadge,
        'showOnlineStatus': showOnlineStatus,
        'sendReadReceipts': sendReadReceipts,
        'allowDMsFromAll': allowDMsFromAll,
        'showEmailOnProfile': showEmailOnProfile,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values[json['themeMode'] as int? ?? 2],
        accentColorValue: json['accentColorValue'] as int? ?? 0xFF4CA87D,
        bannerColorValue: json['bannerColorValue'] as int? ?? 0xFF2D2D2D,
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
        messageDensity: MessageDensity.values[json['messageDensity'] as int? ?? 1],
        compactSidebar: json['compactSidebar'] as bool? ?? false,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        notifyDirectMessages: json['notifyDirectMessages'] as bool? ?? true,
        notifyMentions: json['notifyMentions'] as bool? ?? true,
        notifyAllChannelMessages: json['notifyAllChannelMessages'] as bool? ?? true,
        notifyChannelCreated: json['notifyChannelCreated'] as bool? ?? true,
        notifyOrgUpdates: json['notifyOrgUpdates'] as bool? ?? true,
        notifyMemberJoined: json['notifyMemberJoined'] as bool? ?? false,
        notifySoundEnabled: json['notifySoundEnabled'] as bool? ?? true,
        notifyShowPreview: json['notifyShowPreview'] as bool? ?? true,
        notifyDesktopBadge: json['notifyDesktopBadge'] as bool? ?? true,
        showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
        sendReadReceipts: json['sendReadReceipts'] as bool? ?? true,
        allowDMsFromAll: json['allowDMsFromAll'] as bool? ?? true,
        showEmailOnProfile: json['showEmailOnProfile'] as bool? ?? false,
      );
}
