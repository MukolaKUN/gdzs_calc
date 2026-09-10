class BackupTable {
  final String name;
  final String primaryKey;
  final Set<String> requiredColumns;
  final Map<String, String> foreignKeys;
  const BackupTable(
    this.name,
    this.primaryKey,
    this.requiredColumns, [
    this.foreignKeys = const {},
  ]);
}

const backupTables = <BackupTable>[
  BackupTable('units', 'id', {'id', 'name', 'city'}),
  BackupTable('apparatus', 'id', {
    'id',
    'name',
    'workingPressure',
    'cylinderVolume',
    'cylindersCount',
    'reservePressure',
  }),
  BackupTable('firefighters', 'id', {'id', 'fullName', 'watch'}),
  BackupTable('team_sessions', 'id', {
    'id',
    'unitId',
    'unitNameSnapshot',
    'apparatusId',
    'apparatusNameSnapshot',
    'apparatusWorkingPressure',
    'apparatusCylinderVolume',
    'apparatusCylindersCount',
    'apparatusReservePressure',
    'leaderFirefighterId',
    'workLoad',
    'stage',
    'inclusionTime',
    'createdAt',
    'updatedAt',
  }),
  BackupTable(
    'team_session_members',
    'id',
    {
      'id',
      'sessionId',
      'firefighterId',
      'firefighterNameSnapshot',
      'isLeader',
      'position',
      'startPressure',
    },
    {'sessionId': 'team_sessions'},
  ),
  BackupTable(
    'team_pressure_checks',
    'id',
    {
      'id',
      'sessionId',
      'checkedAt',
      'controllingFirefighterId',
      'remainingWorkMinutes',
      'plannedExitTimeAfterCheck',
      'emergencyMode',
    },
    {'sessionId': 'team_sessions'},
  ),
  BackupTable(
    'team_pressure_check_members',
    'id',
    {
      'id',
      'pressureCheckId',
      'firefighterId',
      'estimatedPressure',
      'actualPressure',
    },
    {'pressureCheckId': 'team_pressure_checks'},
  ),
  BackupTable(
    'team_session_events',
    'id',
    {'id', 'sessionId', 'eventTime', 'title', 'description'},
    {'sessionId': 'team_sessions'},
  ),
  BackupTable(
    'team_emergencies',
    'id',
    {
      'id',
      'sessionId',
      'reason',
      'startedAt',
      'stageAtStart',
      'communicationAvailable',
    },
    {'sessionId': 'team_sessions'},
  ),
  BackupTable('app_settings', 'settingKey', {'settingKey', 'settingValue'}),
];

final backupTableByName = {for (final table in backupTables) table.name: table};
