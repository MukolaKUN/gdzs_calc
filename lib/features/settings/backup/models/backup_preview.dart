class BackupPreview {
  final String fileName;
  final DateTime createdAtUtc;
  final String appVersion;
  final int databaseSchemaVersion;
  final Map<String, int> recordCounts;
  final bool hasActiveSession;
  final int completedSessions;

  const BackupPreview({
    required this.fileName,
    required this.createdAtUtc,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required this.recordCounts,
    required this.hasActiveSession,
    required this.completedSessions,
  });

  int get firefighters => recordCounts['firefighters'] ?? 0;
  int get pressureChecks => recordCounts['team_pressure_checks'] ?? 0;
  int get emergencies => recordCounts['team_emergencies'] ?? 0;
  int get totalRecords => recordCounts.values.fold(0, (a, b) => a + b);
}
