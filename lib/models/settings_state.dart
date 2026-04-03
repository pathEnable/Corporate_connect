class SettingsState {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final String cacheSize;
  final int accentColor;
  final double fontScale;
  final String ringtoneName;

  const SettingsState({
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.cacheSize = '0 B',
    this.accentColor = 0xFF26E9CF,
    this.fontScale = 1.0,
    this.ringtoneName = 'Défaut',
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? cacheSize,
    int? accentColor,
    double? fontScale,
    String? ringtoneName,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
      accentColor: accentColor ?? this.accentColor,
      fontScale: fontScale ?? this.fontScale,
      ringtoneName: ringtoneName ?? this.ringtoneName,
    );
  }
}
