import 'dart:convert';
import 'dart:typed_data';

class GdzsBackup {
  static const formatName = 'gdzs_backup';
  static const currentFormatVersion = 1;

  final int databaseSchemaVersion;
  final DateTime createdAtUtc;
  final String appVersion;
  final Map<String, int> recordCounts;
  final Map<String, List<Map<String, Object?>>> payload;
  final String checksum;

  const GdzsBackup({
    required this.databaseSchemaVersion,
    required this.createdAtUtc,
    required this.appVersion,
    required this.recordCounts,
    required this.payload,
    required this.checksum,
  });

  Map<String, Object?> toJson() => {
    'format': formatName,
    'formatVersion': currentFormatVersion,
    'databaseSchemaVersion': databaseSchemaVersion,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'recordCounts': recordCounts,
    'payload': encodePayload(payload),
    'checksum': checksum,
  };

  String encode() => jsonEncode(toJson());

  static Object? encodeValue(Object? value) => switch (value) {
    Uint8List bytes => {'\$blob': base64Encode(bytes)},
    _ => value,
  };

  static Object? decodeValue(Object? value) {
    if (value is Map && value.length == 1 && value['\$blob'] is String) {
      return base64Decode(value['\$blob'] as String);
    }
    return value;
  }

  static Map<String, Object?> encodePayload(
    Map<String, List<Map<String, Object?>>> payload,
  ) => {
    for (final table in payload.entries)
      table.key: [
        for (final row in table.value)
          {for (final cell in row.entries) cell.key: encodeValue(cell.value)},
      ],
  };
}
