import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final bool isDm;
  final String? orgId;
  final String? shellId;
  final String? categoryId;
  final String? channelId;
  final String? dmId;

  const SessionData({
    required this.isDm,
    this.orgId,
    this.shellId,
    this.categoryId,
    this.channelId,
    this.dmId,
  });
}

class SessionService {
  static const _key = 'slekke_last_session';

  static Future<void> saveChannel({
    required String orgId,
    required String shellId,
    required String categoryId,
    required String channelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, jsonEncode({
      'isDm': false,
      'orgId': orgId,
      'shellId': shellId,
      'categoryId': categoryId,
      'channelId': channelId,
    }));
  }

  static Future<void> saveDm(String dmId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, jsonEncode({'isDm': true, 'dmId': dmId}));
  }

  static Future<SessionData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SessionData(
        isDm: map['isDm'] as bool? ?? false,
        orgId: map['orgId'] as String?,
        shellId: map['shellId'] as String?,
        categoryId: map['categoryId'] as String?,
        channelId: map['channelId'] as String?,
        dmId: map['dmId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
