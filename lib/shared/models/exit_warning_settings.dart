class ExitWarningSettings {
  final bool systemNotifications;
  final bool sound;
  final bool vibration;
  final bool fiveMinutes;
  final bool twoMinutes;
  final bool oneMinute;
  final bool permissionPrompted;

  const ExitWarningSettings({
    this.systemNotifications = true,
    this.sound = true,
    this.vibration = true,
    this.fiveMinutes = true,
    this.twoMinutes = true,
    this.oneMinute = true,
    this.permissionPrompted = false,
  });

  ExitWarningSettings copyWith({
    bool? systemNotifications,
    bool? sound,
    bool? vibration,
    bool? fiveMinutes,
    bool? twoMinutes,
    bool? oneMinute,
    bool? permissionPrompted,
  }) => ExitWarningSettings(
    systemNotifications: systemNotifications ?? this.systemNotifications,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    fiveMinutes: fiveMinutes ?? this.fiveMinutes,
    twoMinutes: twoMinutes ?? this.twoMinutes,
    oneMinute: oneMinute ?? this.oneMinute,
    permissionPrompted: permissionPrompted ?? this.permissionPrompted,
  );
}
