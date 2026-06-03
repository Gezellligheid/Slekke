import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

const _kSettingsKey = 'slekke_app_settings';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSettingsKey);
      if (raw != null) {
        state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSettingsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> reset() async {
    state = const AppSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSettingsKey);
    } catch (_) {}
  }
}
