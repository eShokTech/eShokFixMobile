import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.assetUrl,
    required this.assetSize,
    required this.versionCode,
  });

  final String version;
  final String assetUrl;
  final int assetSize;
  final int versionCode;
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel(
    'com.eshokfix.mobile/app_updates',
  );
  static const String _releaseApi =
      'https://api.github.com/repos/eShokTech/eShokFixMobile/releases/latest';
  static const String _assetName = 'eShokFix-Mobile-release.apk';

  Future<int> installedVersionCode() async =>
      await _channel.invokeMethod<int>('getInstalledVersionCode') ?? 0;

  Future<AppUpdateRelease> latestRelease() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(_releaseApi));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'eShokFix-Mobile-Updater');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub respondió HTTP ${response.statusCode} al consultar actualizaciones.',
        );
      }
      final payload = jsonDecode(await response.transform(utf8.decoder).join());
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('La respuesta de actualización no es válida.');
      }
      final assets = payload['assets'];
      if (assets is! List) {
        throw const FormatException('La publicación no contiene archivos APK.');
      }
      for (final asset in assets) {
        if (asset is! Map) continue;
        if (asset['name'] != _assetName) continue;
        final url = asset['browser_download_url'];
        final size = asset['size'];
        if (url is! String || !url.startsWith('https://') ||
            size is! num || size <= 1024) {
          throw const FormatException('El APK publicado tiene datos incompletos.');
        }
        final tag = payload['tag_name'] as String? ?? '';
        final versionCode = int.tryParse(tag.startsWith('mobile-')
            ? tag.substring('mobile-'.length)
            : '');
        if (versionCode == null || versionCode <= 0) {
          throw FormatException('La publicación tiene una etiqueta de versión no válida: $tag');
        }
        return AppUpdateRelease(
          version: RegExp(r'Version:\s*([^\r\n]+)', caseSensitive: false)
                  .firstMatch(payload['body'] as String? ?? '')
                  ?.group(1)
                  ?.trim() ??
              tag,
          assetUrl: url,
          assetSize: size.toInt(),
          versionCode: versionCode,
        );
      }
      throw const FormatException(
        'La última publicación no contiene eShokFix-Mobile-release.apk.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(AppUpdateRelease release) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(release.assetUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'eShokFix-Mobile-Updater');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('No se pudo descargar el APK (HTTP ${response.statusCode}).');
      }
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/eShokFix-update.apk');
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();
      await response.pipe(sink);
      final actualSize = await file.length();
      if (actualSize != release.assetSize || actualSize < 1024) {
        await file.delete();
        throw const FileSystemException('El APK descargado está incompleto.');
      }
      final header = await file.open();
      final magic = await header.read(4);
      await header.close();
      if (magic.length != 4 || magic[0] != 0x50 || magic[1] != 0x4b) {
        await file.delete();
        throw const FormatException('El archivo descargado no es un APK válido.');
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<void> requestInstallPermission() =>
      _channel.invokeMethod<void>('requestInstallPermission');

  Future<void> install(File apk) =>
      _channel.invokeMethod<void>('installApk', {'path': apk.path});
}
