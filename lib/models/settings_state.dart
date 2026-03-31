class SettingsState {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String cacheSize;

  const SettingsState({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.cacheSize = '0 B',
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? cacheSize,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
    );
  }
}
