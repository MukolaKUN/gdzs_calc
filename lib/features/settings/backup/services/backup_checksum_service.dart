import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/gdzs_backup.dart';

class BackupChecksumService {
  const BackupChecksumService();

  String forPayload(Map<String, List<Map<String, Object?>>> payload) => sha256
      .convert(utf8.encode(jsonEncode(GdzsBackup.encodePayload(payload))))
      .toString();
}
