import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

enum LogLevel { debug, info, warning, error, fatal }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  String toLine() {
    final buffer = StringBuffer()
      ..write(timestamp.toUtc().toIso8601String())
      ..write(' [${level.name.toUpperCase()}] ')
      ..writeln(message);
    if (error != null && error!.isNotEmpty) {
      buffer.writeln('Error: $error');
    }
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer.writeln(stackTrace);
    }
    return buffer.toString();
  }
}

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();
  static const int _maxFileBytes = 1024 * 1024;
  static const int _retainedFiles = 3;

  File? _logFile;
  Future<void> _writeQueue = Future<void>.value();
  bool _initialized = false;
  bool _writingFailed = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final directory = await getApplicationDocumentsDirectory();
    final logDirectory = Directory('${directory.path}/xinpos_logs');
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    _logFile = File('${logDirectory.path}/xinpos.log');
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }
    _initialized = true;
    info('Logger initialized');
  }

  void debug(String message) => _record(LogLevel.debug, message);
  void info(String message) => _record(LogLevel.info, message);
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.error, message, error: error, stackTrace: stackTrace);
  void fatal(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.fatal, message, error: error, stackTrace: stackTrace);

  void _record(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
    final line = entry.toLine();
    debugPrint(line);
    final file = _logFile;
    if (file == null || _writingFailed) return;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _rotateIfNeeded(file, line.length);
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (writeError, writeStack) {
        _writingFailed = true;
        debugPrint(
          'xinPOS logger could not write a log: $writeError\n$writeStack',
        );
      }
    });
  }

  Future<void> _rotateIfNeeded(File file, int incomingCharacters) async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length + incomingCharacters < _maxFileBytes) return;

    final oldest = File('${file.path}.$_retainedFiles');
    if (await oldest.exists()) await oldest.delete();

    for (var index = _retainedFiles - 1; index >= 1; index--) {
      final source = File('${file.path}.$index');
      if (await source.exists()) {
        await source.rename('${file.path}.${index + 1}');
      }
    }

    if (length > 0) {
      await file.rename('${file.path}.1');
    }
    await file.create();
  }

  Future<String> readLogs() async {
    await _writeQueue;
    final file = _logFile;
    if (file == null || !await file.exists()) return 'No logs available.';
    final rotated = <File>[];
    for (var index = _retainedFiles; index >= 1; index--) {
      final candidate = File('${file.path}.$index');
      if (await candidate.exists()) rotated.add(candidate);
    }
    rotated.add(file);
    final contents = StringBuffer();
    for (final item in rotated) {
      contents.writeln(await item.readAsString());
    }
    return contents.toString();
  }

  Future<bool> exportLogs() async {
    final content = await readLogs();
    final bytes = Uint8List.fromList(utf8.encode(content));
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export xinPOS diagnostic logs',
      fileName: 'xinpos-diagnostic-logs.txt',
      bytes: bytes,
      mimeType: 'text/plain',
    );
    return saved != null;
  }

  Future<void> clearLogs() async {
    await _writeQueue;
    final file = _logFile;
    if (file == null) return;
    if (await file.exists()) await file.writeAsString('', flush: true);
    for (var index = 1; index <= _retainedFiles; index++) {
      final rotated = File('${file.path}.$index');
      if (await rotated.exists()) await rotated.delete();
    }
    _writingFailed = false;
    info('Diagnostic logs cleared');
  }
}
