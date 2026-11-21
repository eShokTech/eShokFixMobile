part of '../app.dart';

class UsersPage extends StatefulWidget { const UsersPage({super.key, required this.store}); final LocalStore store; @override State<UsersPage> createState() => _UsersPageState(); }
class _UsersPageState extends State<UsersPage> { late Future<List<Map<String, Object?>>> _future; @override void initState() { super.initState(); _refresh(); } void _refresh() => _future = widget.store.users(); @override Widget build(BuildContext context) => PageFrame(child: Column(children: [SectionHeading('Usuarios y roles', subtitle: 'Catálogo local de perfiles', trailing: FilledButton.tonalIcon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => UserDialog(store: widget.store)); if (ok == true && mounted) setState(_refresh); }, icon: const Icon(Icons.person_add_alt, size: 17), label: const Text('Nuevo'))), const SizedBox(height: 12), GlassCard(child: const Text('En esta beta se administra el catálogo de usuarios de prueba. La autenticación segura, permisos efectivos por operación y sesiones se conectarán al servidor de licencias/API antes de producción.', style: TextStyle(fontSize: 10, color: Color(0xFF7E7489), height: 1.4))), const SizedBox(height: 10), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); return ListView(children: snap.data!.map((u) => Padding(padding: const EdgeInsets.only(top: 7), child: GlassCard(child: Row(children: [const Icon(Icons.account_circle_outlined, color: eShokPurple, size: 27), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(u['display_name']), style: const TextStyle(fontWeight: FontWeight.w800)), Text('@${_str(u['username'])} · ${_str(u['role'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF81778D)))])), Text(_num(u['active']) == 1 ? 'ACTIVO' : 'INACTIVO', style: const TextStyle(fontSize: 9, color: Color(0xFF29966F), fontWeight: FontWeight.w900))])))).toList()); }))])); }
class UserDialog extends StatefulWidget { const UserDialog({super.key, required this.store}); final LocalStore store; @override State<UserDialog> createState() => _UserDialogState(); }
class _UserDialogState extends State<UserDialog> { final username = TextEditingController(); final name = TextEditingController(); String role = 'TECNICO'; @override void dispose() { username.dispose(); name.dispose(); super.dispose(); } @override Widget build(BuildContext context) => AlertDialog(title: const Text('Nuevo usuario'), content: Column(mainAxisSize: MainAxisSize.min, children: [_field(username, 'Usuario', required: true), const SizedBox(height: 8), _field(name, 'Nombre visible', required: true), const SizedBox(height: 8), DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Rol'), items: const ['ADMIN','ENCARGADO','TECNICO','CAJA'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => role = v ?? role))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (username.text.trim().isEmpty || name.text.trim().isEmpty) return; try { await widget.store.saveUser(username: username.text, name: name.text, role: role); if (context.mounted) Navigator.pop(context, true); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('Guardar'))]); }

class SettingsPage extends StatefulWidget { const SettingsPage({super.key, required this.store, required this.open}); final LocalStore store; final ValueChanged<String> open; @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> {
  final shop = TextEditingController();
  final warranty = TextEditingController();
  bool loaded = false;
  late Future<Map<String, int>> _demoCounts;

  @override
  void initState() {
    super.initState();
    _demoCounts = widget.store.demoDataCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) _load();
  }

  Future<void> _load() async {
    shop.text = await widget.store.setting('shop_name', fallback: 'eShokFix');
    warranty.text = await widget.store.setting('default_warranty_days', fallback: '30');
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _createBackup() async {
    try {
      final uri = await widget.store.exportBackup();
      if (uri == null) return;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copia de seguridad guardada en la ubicación elegida.')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la copia: $error')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final path = await DatabaseBackupService().pickDatabaseBackup();
    if (path == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar copia de seguridad'),
        content: const Text(
          'La base de datos actual será reemplazada por la copia seleccionada. '
          'Crea una copia de la base actual antes de continuar. La aplicación se cerrará al terminar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB65E69)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reemplazar datos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.restoreBackup(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copia restaurada. Abre de nuevo eShokFix para cargar los datos.')),
        );
      }
      await SystemNavigator.pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restaurar la copia: $error')),
      );
    }
  }

  Future<void> _removeDemoData() async {
    final counts = await widget.store.demoDataCounts();
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quedan registros de demostración por retirar.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar datos de demostración'),
        content: Text(
          'Se retirarán ${counts['clients']} clientes, ${counts['orders']} órdenes y ${counts['items']} artículos marcados como demo. Los registros reales vinculados se conservarán. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB65E69)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirar datos demo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.store.removeDemoData();
      if (!mounted) return;
      setState(() => _demoCounts = widget.store.demoDataCounts());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de demostración retirados. Tus registros reales se conservaron.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron retirar los datos demo: $e')),
      );
    }
  }

  @override
  void dispose() {
    shop.dispose();
    warranty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: ListView(children: [
      const SectionHeading('Configuración', subtitle: 'Identidad y reglas generales'),
      const SizedBox(height: 13),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Datos del taller', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        TextField(controller: shop, decoration: const InputDecoration(labelText: 'Nombre comercial')),
        const SizedBox(height: 8),
        TextField(controller: warranty, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Garantía predeterminada (días)')),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: loaded ? () async {
            final days = int.tryParse(warranty.text.trim());
            if (shop.text.trim().isEmpty || days == null || days < 0 || days > 3650) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Revisa el nombre del taller y los días de garantía (0 a 3650).')),
              );
              return;
            }
            await widget.store.saveSetting('shop_name', shop.text.trim());
            await widget.store.saveSetting('default_warranty_days', days.toString());
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Configuración guardada localmente.')),
            );
          } : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
      ])),
      const SizedBox(height: 10),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Base de datos y respaldos', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text(
          'Exporta una copia SQLite a Archivos o restaura una copia previa. Se recomienda respaldar antes de actualizar o limpiar datos.',
          style: TextStyle(fontSize: 10, color: Color(0xFF7E7489), height: 1.4),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Crear respaldo'),
          ),
          OutlinedButton.icon(
            onPressed: _restoreBackup,
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Restaurar'),
          ),
        ]),
      ])),
      const SizedBox(height: 10),
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Datos de demostración', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text(
          'La primera instalación incluye registros ficticios para probar la aplicación. Retíralos antes de empezar a operar con clientes reales.',
          style: TextStyle(fontSize: 10, color: Color(0xFF7E7489), height: 1.4),
        ),
        const SizedBox(height: 9),
        FutureBuilder<Map<String, int>>(
          future: _demoCounts,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final data = snap.data!;
            return Text(
              'Clientes: ${data['clients']}  ·  Órdenes: ${data['orders']}  ·  Artículos: ${data['items']}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _removeDemoData,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Retirar datos de demostración'),
        ),
      ])),
      const SizedBox(height: 10),
      _settingsRow(context, Icons.people_outline, 'Usuarios y roles', 'Catálogo local de perfiles', () => widget.open('usuarios')),
      _settingsRow(context, Icons.notifications_active_outlined, 'Eventos de WhatsApp', 'Solo recepción, listo y entrega', () => widget.open('whatsapp')),
      _settingsRow(context, Icons.vpn_key_outlined, 'Licenciamiento', 'Conexión con servidor pendiente', () => widget.open('licencias')),
      const SizedBox(height: 12),
      GlassCard(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Política de comunicación', style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text(
          'El flujo previsto genera únicamente tres eventos automáticos: recepción del equipo, equipo listo para recoger y comprobante con garantía al registrar la entrega. Los estados internos no disparan mensajes.',
          style: TextStyle(fontSize: 10, color: Color(0xFF7E7489), height: 1.45),
        ),
      ])),
    ]),
  );
}


Widget _settingsRow(
  BuildContext context,
  IconData icon,
  String title,
  String detail,
  VoidCallback onTap,
) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: GlassCard(
    child: InkWell(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: eShokPurple),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(detail, style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296))),
          ],
        )),
        const Icon(Icons.chevron_right, color: Color(0xFF9C91A8)),
      ]),
    ),
  ),
);

class WhatsAppEventsPage extends StatefulWidget { const WhatsAppEventsPage({super.key, required this.store}); final LocalStore store; @override State<WhatsAppEventsPage> createState() => _WhatsAppEventsPageState(); }
class _WhatsAppEventsPageState extends State<WhatsAppEventsPage> { late Future<List<Map<String, Object?>>> _future; @override void initState() { super.initState(); _future = widget.store.whatsappEvents(); } @override Widget build(BuildContext context) => PageFrame(child: Column(children: [const SectionHeading('Eventos de WhatsApp', subtitle: 'Registro local de los tres avisos autorizados'), const SizedBox(height: 10), GlassCard(child: const Text('Estos registros todavía no envían mensajes. La integración con WhatsApp Business Platform requiere configurar un número, credenciales, consentimiento y plantillas; la conversación normal del técnico permanece fuera de eShokFix.', style: TextStyle(fontSize: 10, color: Color(0xFF7D7389), height: 1.4))), const SizedBox(height: 10), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; if (rows.isEmpty) return const EmptyState(title: 'Sin eventos', message: 'Al recibir, marcar listo o entregar un expediente aparecerán aquí.'); return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final e = rows[i]; return Padding(padding: const EdgeInsets.only(top: 8), child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.chat_bubble_outline, color: eShokPurple), const SizedBox(width: 8), Expanded(child: Text(_str(e['event_type']), style: const TextStyle(fontWeight: FontWeight.w800))), const Text('PENDIENTE', style: TextStyle(fontSize: 8, color: Color(0xFFB47A2C), fontWeight: FontWeight.w900))]), const SizedBox(height: 5), Text('${_str(e['folio'])} · ${_str(e['client_name'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))), const SizedBox(height: 7), Text(_str(e['message']), style: const TextStyle(fontSize: 11))]))); }); }))])); }

class LicensePage extends StatelessWidget { const LicensePage({super.key}); @override Widget build(BuildContext context) => PageFrame(child: ListView(children: [const SectionHeading('Licenciamiento', subtitle: 'Servidor eShokFix License Server'), const SizedBox(height: 12), GlassCard(gradient: const LinearGradient(colors: [Color(0xFFF3ECFB), Colors.white]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.vpn_key_outlined, color: eShokPurple, size: 35), const SizedBox(height: 9), const Text('Modo de prueba local', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('La validación de licencia todavía no está conectada. Esta compilación no activa ni simula una licencia comercial.', style: TextStyle(fontSize: 11, color: Color(0xFF7E7489), height: 1.4)), const SizedBox(height: 11), const StatusChip(status: 'ESPERA_AUTORIZACION') ])), const SizedBox(height: 12), GlassCard(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Arquitectura prevista', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 7), Text('La app consultará una dirección HTTPS fija. El servidor de licencias correrá como servicio independiente en la PC del local y emitirá autorizaciones firmadas. El teléfono conservará una autorización local con vencimiento y política de gracia. El descubrimiento remoto y el túnel seguro se configurarán después de comprobar el acceso de red del local.', style: TextStyle(fontSize: 10, color: Color(0xFF7E7489), height: 1.45))]))])); }
