class SettingsState {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String cacheSize;
  final int accentColor;
  final double fontScale;

  const SettingsState({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.cacheSize = '0 B',
    this.accentColor = 0xFF00695C,
    this.fontScale = 1.0,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? cacheSize,
    int? accentColor,
    double? fontScale,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
      accentColor: accentColor ?? this.accentColor,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}
