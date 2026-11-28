part of '../app.dart';

class AppUpdateSettingsSection extends StatefulWidget {
  const AppUpdateSettingsSection({super.key});
  @override
  State<AppUpdateSettingsSection> createState() => _AppUpdateSettingsSectionState();
}

class _AppUpdateSettingsSectionState extends State<AppUpdateSettingsSection> {
  final AppUpdateService _service = AppUpdateService();
  AppUpdateInfo? _update;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;
  String _message = 'Versión instalada: ' + eShokFixCurrentVersion;

  Future<void> _check() async {
    setState(() { _checking = true; _message = 'Buscando actualizaciones…'; });
    try {
      final update = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _update = update;
        _message = update == null ? 'Tu aplicación está actualizada.' : 'Nueva versión disponible: ' + update.version;
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo comprobar: $error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null) return;
    try {
      if (!await _service.canInstallPackages()) {
        await _service.requestInstallPermission();
        if (mounted) setState(() => _message = 'Autoriza a eShokFix para instalar actualizaciones y vuelve a pulsar Actualizar.');
        return;
      }
      setState(() { _downloading = true; _progress = 0; _message = 'Descargando actualización…'; });
      final apk = await _service.downloadUpdate(update, onProgress: (value) {
        if (mounted) setState(() => _progress = value.clamp(0, 1).toDouble());
      });
      if (!mounted) return;
      setState(() => _message = 'Descarga completa. Abriendo instalador de Android…');
      await _service.installApk(apk);
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo instalar la actualización: $error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.system_update_alt, color: eShokPurple),
        const SizedBox(width: 9),
        const Expanded(child: Text('Actualizaciones de eShokFix', style: TextStyle(fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 6),
      const Text('Busca versiones nuevas y descárgalas desde la aplicación. Android confirma la actualización y conserva los datos.',
        style: TextStyle(fontSize: 10, color: Color(0xFF81778D), height: 1.4)),
      const SizedBox(height: 8),
      Text(_message, style: const TextStyle(fontSize: 10)),
      if (_downloading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _progress),
        Text('${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9)),
      ],
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _checking || _downloading ? null : _check,
          icon: _checking ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          label: const Text('Buscar actualizaciones'),
        ),
        if (_update != null)
          FilledButton.icon(onPressed: _downloading ? null : _downloadAndInstall,
            icon: const Icon(Icons.download), label: const Text('Actualizar ahora')),
      ]),
    ]),
  );
}
