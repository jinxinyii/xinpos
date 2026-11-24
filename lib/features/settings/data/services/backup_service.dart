import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';

class BackupRecord {
  const BackupRecord({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.automatic,
  });

  final String path;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final bool automatic;

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'createdAt': createdAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'automatic': automatic,
  };

  factory BackupRecord.fromJson(Map<String, dynamic> json) => BackupRecord(
    path: json['path'] as String,
    fileName: json['fileName'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    sizeBytes: json['sizeBytes'] as int,
    automatic: json['automatic'] as bool,
  );
}

class BackupService {
  BackupService(this.database);

  final AppDatabase database;
  static const _historyKey = 'xinpos_backup_history_v1';
  static const _magic = 'XINPOSBACKUP1\n';
  static const _retentionCount = 10;

  Future<Directory> _backupDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/xinpos_backups');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<List<BackupRecord>> history() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_historyKey) ?? [];
    final records = <BackupRecord>[];
    for (final value in values) {
      try {
        final record = BackupRecord.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
        if (await File(record.path).exists()) records.add(record);
      } catch (_) {}
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<BackupRecord> createBackup({bool automatic = false}) async {
    final rows = await database.customSelect('PRAGMA database_list').get();
    final databasePath = rows
        .map((row) => row.data['file'] as String?)
        .whereType<String>()
        .firstWhere((path) => path.isNotEmpty);
    await database.customStatement('PRAGMA wal_checkpoint(FULL)');
    final source = File(databasePath);
    if (!await source.exists()) {
      throw StateError('The xinPOS database file could not be located.');
    }

    final databaseBytes = await source.readAsBytes();
    final now = DateTime.now();
    final stamp = now.toIso8601String().replaceAll(':', '-');
    final fileName = 'xinpos-backup-$stamp.xinbackup';
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'xinPOS-backup',
        'formatVersion': 1,
        'app': 'xinPOS',
        'schemaVersion': 6,
        'createdAt': now.toUtc().toIso8601String(),
        'databaseFile': 'xinpos_db.sqlite',
        'databaseBytes': databaseBytes.length,
        'automatic': automatic,
        'encrypted': false,
      }),
    );
    final bytes = BytesBuilder()
      ..add(utf8.encode(_magic))
      ..add(_uint32(manifest.length))
      ..add(manifest)
      ..add(databaseBytes);

    final directory = await _backupDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes.takeBytes(), flush: true);

    final record = BackupRecord(
      path: file.path,
      fileName: fileName,
      createdAt: now,
      sizeBytes: await file.length(),
      automatic: automatic,
    );
    await _saveRecord(record);
    if (automatic) await _applyRetention();
    return record;
  }

  Uint8List _uint32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big);

  Future<void> _saveRecord(BackupRecord record) async {
    final preferences = await SharedPreferences.getInstance();
    final records = await history();
    records.removeWhere((item) => item.path == record.path);
    records.insert(0, record);
    await preferences.setStringList(
      _historyKey,
      records.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _applyRetention() async {
    final records = await history();
    final automatic = records.where((item) => item.automatic).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final record in automatic.skip(_retentionCount)) {
      final file = File(record.path);
      if (await file.exists()) await file.delete();
    }
    final retained = await history();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _historyKey,
      retained.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> deleteManualBackup(BackupRecord record) async {
    if (record.automatic) {
      throw StateError('Automatic backups cannot be deleted manually.');
    }
    final directory = await _backupDirectory();
    final file = File(record.path);
    final normalizedDirectory = directory.absolute.path;
    if (file.parent.absolute.path != normalizedDirectory ||
        file.uri.pathSegments.last != record.fileName) {
      throw StateError(
        'The selected backup is not in the xinPOS backup folder.',
      );
    }
    if (await file.exists()) await file.delete();
    await _removeHistoryRecords({record.path});
  }

  Future<int> deleteAllManualBackups() async {
    final records = await history();
    final manual = records.where((record) => !record.automatic).toList();
    final paths = <String>{};
    for (final record in manual) {
      final directory = await _backupDirectory();
      final file = File(record.path);
      if (file.parent.absolute.path != directory.absolute.path ||
          file.uri.pathSegments.last != record.fileName) {
        throw StateError(
          'A selected backup is not in the xinPOS backup folder.',
        );
      }
      if (await file.exists()) await file.delete();
      paths.add(record.path);
    }
    await _removeHistoryRecords(paths);
    return manual.length;
  }

  Future<void> _removeHistoryRecords(Set<String> paths) async {
    final preferences = await SharedPreferences.getInstance();
    final remaining = (await history())
        .where((record) => !paths.contains(record.path))
        .toList();
    await preferences.setStringList(
      _historyKey,
      remaining.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  Future<bool> createDailyBackupIfNeeded() async {
    final preferences = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final last = preferences.getString('xinpos_last_auto_backup_day');
    final day = '${today.year}-${today.month}-${today.day}';
    if (last == day) return false;
    await createBackup(automatic: true);
    await preferences.setString('xinpos_last_auto_backup_day', day);
    return true;
  }

  Future<bool> exportBackup(BackupRecord record) async {
    final bytes = await File(record.path).readAsBytes();
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save xinPOS backup',
      fileName: record.fileName,
      bytes: bytes,
      mimeType: 'application/octet-stream',
    );
    return saved != null;
  }

  Future<void> exportLatestBackup() async {
    final records = await history();
    if (records.isEmpty) throw StateError('No backup is available to share.');
    await exportBackup(records.first);
  }

  Future<BackupRecord> restoreBackup(Uint8List packageBytes) async {
    final parsed = _parsePackage(packageBytes);
    final databaseBytes = parsed.databaseBytes;
    final tempDirectory = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final candidate = File(
      '${tempDirectory.path}/xinpos-restore-$stamp.sqlite',
    );
    await candidate.writeAsBytes(databaseBytes, flush: true);

    try {
      _validateSqlite(candidate.path, parsed.schemaVersion);
      final safetyBackup = await createBackup();
      final rows = await database.customSelect('PRAGMA database_list').get();
      final databasePath = rows
          .map((row) => row.data['file'] as String?)
          .whereType<String>()
          .firstWhere((path) => path.isNotEmpty);
      final target = File(databasePath);
      final rollback = File('$databasePath.pre-restore-$stamp');
      if (await target.exists()) await target.copy(rollback.path);

      await database.close();
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$databasePath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }

      try {
        final replacement = File('$databasePath.restore-$stamp');
        await candidate.copy(replacement.path);
        if (await target.exists()) await target.delete();
        await replacement.rename(target.path);
        final verification = sqlite3.open(target.path, mode: OpenMode.readOnly);
        try {
          final result = verification.select('PRAGMA integrity_check');
          if (result.isEmpty || result.first.values.first != 'ok') {
            throw StateError(
              'Restored database failed integrity verification.',
            );
          }
        } finally {
          verification.close();
        }
        if (await rollback.exists()) await rollback.delete();
      } catch (_) {
        if (await rollback.exists()) {
          if (await target.exists()) await target.delete();
          await rollback.rename(target.path);
        }
        rethrow;
      }

      return safetyBackup;
    } finally {
      if (await candidate.exists()) await candidate.delete();
    }
  }

  Future<String?> pickAndRestoreBackup() async {
    final selectedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xinbackup'],
    );
    if (selectedFile == null) return null;
    final bytes = await selectedFile.readAsBytes();
    final safetyBackup = await restoreBackup(bytes);
    return safetyBackup.fileName;
  }

  _ParsedBackup _parsePackage(Uint8List bytes) {
    final magicBytes = utf8.encode(_magic);
    if (bytes.length < magicBytes.length + 4) {
      throw const FormatException('Backup file is incomplete.');
    }
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw const FormatException('This is not a valid xinPOS backup.');
      }
    }

    final manifestLength = ByteData.sublistView(
      bytes,
      magicBytes.length,
      magicBytes.length + 4,
    ).getUint32(0, Endian.big);
    final manifestStart = magicBytes.length + 4;
    final databaseStart = manifestStart + manifestLength;
    if (manifestLength == 0 || databaseStart >= bytes.length) {
      throw const FormatException('Backup manifest or database is missing.');
    }

    final manifest = jsonDecode(
      utf8.decode(bytes.sublist(manifestStart, databaseStart)),
    ) as Map<String, dynamic>;
    if (manifest['format'] != 'xinPOS-backup' ||
        manifest['formatVersion'] != 1 ||
        manifest['app'] != 'xinPOS' ||
        manifest['encrypted'] != false ||
        manifest['databaseFile'] != 'xinpos_db.sqlite') {
      throw const FormatException('Unsupported backup format.');
    }

    final schemaVersionValue = manifest['schemaVersion'];
    if (schemaVersionValue is! int || schemaVersionValue != 6) {
      throw FormatException(
        'This backup uses database schema $schemaVersionValue. '
        'This app currently supports schema 6 backups.',
      );
    }
    final schemaVersion = schemaVersionValue;

    final databaseBytes = Uint8List.fromList(bytes.sublist(databaseStart));
    if (manifest['databaseBytes'] != databaseBytes.length) {
      throw const FormatException(
        'Backup database size does not match manifest.',
      );
    }
    if (databaseBytes.length < 100 ||
        utf8.decode(databaseBytes.sublist(0, 16), allowMalformed: true) !=
            'SQLite format 3\u0000') {
      throw const FormatException(
        'Backup does not contain a valid SQLite database.',
      );
    }

    return _ParsedBackup(schemaVersion, databaseBytes);
  }

  void _validateSqlite(String path, int expectedSchemaVersion) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final integrity = db.select('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const FormatException('Backup database failed integrity check.');
      }
      final version =
          db.select('PRAGMA user_version').first.values.first as int;
      if (version != expectedSchemaVersion) {
        throw FormatException(
          'Database schema mismatch. Expected $expectedSchemaVersion, found $version.',
        );
      }
    } finally {
      db.close();
    }
  }
}

class _ParsedBackup {
  const _ParsedBackup(this.schemaVersion, this.databaseBytes);

  final int schemaVersion;
  final Uint8List databaseBytes;
}
