import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_state.dart';
import '../services/local_database.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _init();
    return const SettingsState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    
    final isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    final notificationsEnabled = _prefs.getBool('notificationsEnabled') ?? true;
    
    state = state.copyWith(
      isDarkMode: isDarkMode,
      notificationsEnabled: notificationsEnabled,
    );
    
    await _updateCacheSize();
  }

  Future<void> _updateCacheSize() async {
    final sizeInBytes = await LocalDatabase.instance.getCacheSize();
    final sizeInMB = sizeInBytes / (1024 * 1024);
    state = state.copyWith(cacheSize: '${sizeInMB.toStringAsFixed(2)} MB');
  }

  Future<void> toggleDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> toggleNotifications(bool value) async {
    await _prefs.setBool('notificationsEnabled', value);
    state = state.copyWith(notificationsEnabled: value);
    
    // Si on désactive, on pourrait potentiellement unregister sur FCM mais pour le moment 
    // on va juste l'afficher dans l'UI ou l'utiliser comme un réglage local.
  }

  Future<void> clearCache() async {
    await LocalDatabase.instance.clearCache();
    await _updateCacheSize();
  }
}
