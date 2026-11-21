import 'package:flutter/services.dart';

class DatabaseBackupService {
  static const MethodChannel _channel = MethodChannel(
    'com.eshokfix.mobile/database_backup',
  );

  Future<String?> exportDatabase({
    required String sourcePath,
    required String suggestedName,
  }) {
    return _channel.invokeMethod<String>('exportDatabaseBackup', {
      'sourcePath': sourcePath,
      'fileName': suggestedName,
    });
  }

  Future<String?> pickDatabaseBackup() {
    return _channel.invokeMethod<String>('pickDatabaseBackup');
  }
}
