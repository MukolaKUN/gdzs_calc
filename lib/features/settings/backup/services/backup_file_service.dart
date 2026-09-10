import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SelectedBackupFile {
  final String name;
  final Uint8List bytes;
  const SelectedBackupFile(this.name, this.bytes);
}

abstract interface class BackupFileService {
  Future<SelectedBackupFile?> pickBackup();
  Future<String> writeTemporary(String name, Uint8List bytes);
  Future<String> writeInternal(String name, Uint8List bytes);
  Future<void> share(String path);
}

class PlatformBackupFileService implements BackupFileService {
  const PlatformBackupFileService();

  @override
  Future<SelectedBackupFile?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gdzsbackup'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const FileSystemException('Немає доступу до файла');
    }
    return SelectedBackupFile(file.name, bytes);
  }

  @override
  Future<String> writeTemporary(String name, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<String> writeInternal(String name, Uint8List bytes) async {
    final directory = await getApplicationSupportDirectory();
    final folder = Directory(p.join(directory.path, 'backups'));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> share(String path) => Share.shareXFiles([
    XFile(path),
  ], subject: 'Резервна копія GDZS Calculator');
}
