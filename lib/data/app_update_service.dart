import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const String eShokFixCurrentVersion = String.fromEnvironment(
  'ESHOKFIX_VERSION',
  defaultValue: '0.2.0+2',
);

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileSize,
  });
  final String version;
  final Uri downloadUrl;
  final String releaseNotes;
  final int fileSize;
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('com.eshokfix.mobile/app_updates');

  Future<AppUpdateInfo?> checkForUpdate() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/eShokTech/eShokFixMobile/releases/latest',
      ));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'eShokFix-Mobile');
      final response = await request.close();
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub respondió HTTP ${response.statusCode}.');
      }
      final raw = await response.transform(utf8.decoder).join();
      final release = jsonDecode(raw) as Map<String, dynamic>;
      final notes = (release['body'] ?? '').toString();
      final match = RegExp(r'Version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)').firstMatch(notes);
      if (match == null) throw const FormatException('La publicación no contiene una versión válida.');
      final version = match.group(1)!;
      final remoteBuild = int.tryParse(version.split('+').last) ?? 0;
      final localBuild = int.tryParse(eShokFixCurrentVersion.split('+').last) ?? 0;
      if (remoteBuild <= localBuild) return null;
      final assets = release['assets'];
      if (assets is! List) throw const FormatException('La publicación no contiene archivos.');
      Map<String, dynamic>? apk;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> && asset['name'] == 'eShokFix-Mobile-release.apk') {
          apk = asset;
          break;
        }
      }
      if (apk == null) throw const FormatException('No se encontró el APK de actualización.');
      final url = Uri.tryParse((apk['browser_download_url'] ?? '').toString());
      if (url == null || url.scheme != 'https') throw const FormatException('La dirección del APK no es segura.');
      return AppUpdateInfo(
        version: version,
        downloadUrl: url,
        releaseNotes: notes,
        fileSize: (apk['size'] as num?)?.toInt() ?? 0,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> downloadUpdate(AppUpdateInfo info, {void Function(double)? onProgress}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    final directory = await getTemporaryDirectory();
    final destination = File('${directory.path}/eshokfix-update.apk');
    IOSink? sink;
    try {
      final request = await client.getUrl(info.downloadUrl);
      request.headers.set(HttpHeaders.userAgentHeader, 'eShokFix-Mobile');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('No se pudo descargar el APK (HTTP ${response.statusCode}).');
      }
      final expected = response.contentLength > 0 ? response.contentLength : info.fileSize;
      var received = 0;
      sink = destination.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (expected > 0) onProgress?.call(received / expected);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      final actual = await destination.length();
      if (actual < 1024 || (expected > 0 && actual != expected)) {
        throw const FileSystemException('La descarga del APK quedó incompleta.');
      }
      return destination;
    } catch (_) {
      if (sink != null) await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  Future<void> requestInstallPermission() async {
    await _channel.invokeMethod<void>('requestInstallPermission');
  }

  Future<void> installApk(File apk) async {
    await _channel.invokeMethod<void>('installApk', {'path': apk.path});
  }
}
