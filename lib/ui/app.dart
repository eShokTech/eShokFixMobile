import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../data/local_store.dart';
import '../domain/workflow.dart';
import 'theme.dart';

String _str(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _money(Object? v) => NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(_num(v));
String _date(Object? v) {
  if (v == null || '$v'.isEmpty) return 'Sin fecha';
  try { return DateFormat('dd/MM/yyyy · HH:mm').format(DateTime.parse('$v').toLocal()); }
  catch (_) { return '$v'; }
}
String _day(Object? v) {
  if (v == null || '$v'.isEmpty) return 'Sin fecha';
  try { return DateFormat('dd/MM/yyyy').format(DateTime.parse('$v').toLocal()); }
  catch (_) { return '$v'; }
}

class EShokFixShell extends StatefulWidget {
  const EShokFixShell({super.key, required this.store});
  final LocalStore store;
  @override
  State<EShokFixShell> createState() => _EShokFixShellState();
}

class _EShokFixShellState extends State<EShokFixShell> {
  String _view = 'inicio';
  void _open(String view) => setState(() => _view = view);
  int get _selectedNav => switch (_view) {
    'inicio' => 0, 'ordenes' => 1, 'clientes' => 2, 'inventario' => 3, _ => 4,
  };
  String get _title => switch (_view) {
    'inicio' => 'Inicio', 'ordenes' => 'Órdenes de servicio', 'clientes' => 'Clientes',
    'inventario' => 'Inventario', 'mas' => 'Más módulos', 'pos' => 'Punto de venta',
    'caja' => 'Caja y cortes', 'garantias' => 'Garantías', 'reportes' => 'Reportes',
    'usuarios' => 'Usuarios y permisos', 'configuracion' => 'Configuración',
    'whatsapp' => 'Eventos WhatsApp', 'licencias' => 'Licenciamiento', 'compras' => 'Compras y proveedores',
    _ => 'eShokFix',
  };

  @override
  Widget build(BuildContext context) {
    Widget page = switch (_view) {
      'inicio' => DashboardPage(store: widget.store, open: _open),
      'ordenes' => OrdersPage(store: widget.store),
      'clientes' => ClientsPage(store: widget.store),
      'inventario' => InventoryPage(store: widget.store),
      'pos' => SalesPage(store: widget.store),
      'caja' => CashPage(store: widget.store),
      'garantias' => WarrantiesPage(store: widget.store),
      'reportes' => ReportsPage(store: widget.store),
      'usuarios' => UsersPage(store: widget.store),
      'configuracion' => SettingsPage(store: widget.store, open: _open),
      'whatsapp' => WhatsAppEventsPage(store: widget.store),
      'licencias' => const LicensePage(),
      'compras' => PurchasesPage(store: widget.store),
      _ => MorePage(open: _open),
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title),
          const Text('eShokFix  ·  OPERACIÓN DEL TALLER', style: TextStyle(fontSize: 9, letterSpacing: 1.25, color: Color(0xFF8C819A), fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Modo local sin servidor conectado',
            onPressed: () => _showInfo(context, 'Modo local', 'Los datos y operaciones de esta beta se guardan en el teléfono. La sincronización con PC y el licenciamiento remoto todavía no están conectados.'),
            icon: const Icon(Icons.cloud_off_outlined, color: eShokPurple),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNav,
        onDestinationSelected: (index) => _open(switch (index) {
          0 => 'inicio', 1 => 'ordenes', 2 => 'clientes', 3 => 'inventario', _ => 'mas',
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Órdenes'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Más'),
        ],
      ),
    );
  }
}

void _showInfo(BuildContext context, String title, String message) {
  showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
  ));
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 24)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: padding, child: child));
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: eShokInk)),
      if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF82788E)))],
    ])),
    if (trailing != null) trailing!,
  ]);
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(15), this.gradient});
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      gradient: gradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: eShokBorder),
      boxShadow: [BoxShadow(color: const Color(0xFF46345F).withValues(alpha: .035), blurRadius: 14, offset: const Offset(0, 5))],
    ),
    child: child,
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.icon, this.tint = eShokPurple, this.caption});
  final String title, value;
  final IconData icon;
  final Color tint;
  final String? caption;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: tint.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: tint, size: 19)), const Spacer(), Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 18)]),
      const SizedBox(height: 10),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: eShokInk)),
      const SizedBox(height: 2),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF766D81), fontWeight: FontWeight.w700)),
      if (caption != null) ...[const SizedBox(height: 5), Text(caption!, style: const TextStyle(fontSize: 9, color: Color(0xFF9A91A4)))],
    ]),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.store, required this.open});
  final LocalStore store;
  final ValueChanged<String> open;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, Object?>> _data;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => _data = widget.store.dashboard();
  @override
  Widget build(BuildContext context) => PageFrame(child: FutureBuilder<Map<String, Object?>>(
    future: _data,
    builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final d = snap.data!;
      final recent = (d['recent'] as List).cast<Map<String, Object?>>();
      return RefreshIndicator(onRefresh: () async => setState(_refresh), child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), children: [
          GlassCard(gradient: const LinearGradient(colors: [Color(0xFFF3ECFB), Color(0xFFFFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tu taller, bajo control', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: eShokInk)),
              const SizedBox(height: 5),
              const Text('Operación local lista para trabajar sin depender de Internet.', style: TextStyle(fontSize: 11, color: Color(0xFF756A85), height: 1.35)),
              const SizedBox(height: 13),
              FilledButton.icon(onPressed: () => widget.open('ordenes'), icon: const Icon(Icons.add, size: 18), label: const Text('Nueva orden')),
            ])),
            const SizedBox(width: 10),
            Container(width: 76, height: 76, decoration: BoxDecoration(color: eShokPurple.withValues(alpha: .10), shape: BoxShape.circle), child: const Icon(Icons.handyman_outlined, size: 38, color: eShokPurple)),
          ])),
          const SizedBox(height: 16),
          const SectionHeading('Resumen operativo', subtitle: 'Indicadores de la base local'),
          const SizedBox(height: 10),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.18, children: [
            MetricCard(title: 'Órdenes activas', value: '${d['active']}', icon: Icons.assignment_outlined),
            MetricCard(title: 'Listas para entregar', value: '${d['ready']}', icon: Icons.task_alt, tint: const Color(0xFF279B70)),
            MetricCard(title: 'Clientes registrados', value: '${d['clients']}', icon: Icons.people_outline, tint: const Color(0xFF5288CB)),
            MetricCard(title: 'Stock bajo', value: '${d['low_stock']}', icon: Icons.inventory_2_outlined, tint: const Color(0xFFD58B34)),
          ]),
          const SizedBox(height: 16),
          GlassCard(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ingresos registrados hoy', style: TextStyle(fontSize: 11, color: Color(0xFF847A90), fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(_money(d['income_today']), style: const TextStyle(fontSize: 22, color: eShokPurple, fontWeight: FontWeight.w800))])),
            Container(width: 1, height: 42, color: eShokBorder),
            Expanded(child: Padding(padding: const EdgeInsets.only(left: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ventas de hoy', style: TextStyle(fontSize: 11, color: Color(0xFF847A90), fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('${d['sales_today']}', style: const TextStyle(fontSize: 22, color: eShokInk, fontWeight: FontWeight.w800))]))),
          ])),
          const SizedBox(height: 16),
          Row(children: [const Expanded(child: SectionHeading('Órdenes recientes')), TextButton(onPressed: () => widget.open('ordenes'), child: const Text('Ver todas'))]),
          if (recent.isEmpty) const EmptyState(title: 'Aún no hay órdenes', message: 'Registra tu primer equipo para comenzar.'),
          ...recent.map((o) => OrderListTile(order: o, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(store: widget.store, orderId: o['id'] as int))))),
          const SizedBox(height: 12),
          GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.sync_problem_outlined, color: eShokPurple), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Sincronización pendiente', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${d['pending_local']} movimientos registrados localmente. La conexión con el servidor de PC aún no está activa.', style: const TextStyle(fontSize: 11, color: Color(0xFF81768D), height: 1.35))])),
          ])),
        ],
      ));
    },
  ));
}

class OrderListTile extends StatelessWidget {
  const OrderListTile({super.key, required this.order, required this.onTap});
  final Map<String, Object?> order;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = _str(order['status']);
    return Padding(padding: const EdgeInsets.only(top: 8), child: Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(
        padding: const EdgeInsets.all(13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: eShokBorder)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: eShokPurpleLight.withValues(alpha: .27), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.phone_android, color: eShokPurple)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_str(order['brand'], 'Equipo')} ${_str(order['model'])}'.trim(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: eShokInk), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3), Text('${_str(order['folio'])}  ·  ${_str(order['client_name'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF8A8095)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [StatusChip(status: status), const SizedBox(height: 5), Text(_money(order['total']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
        ]),
      )),
    ));
  }
}

Color _statusColor(String status) => switch (status) {
  'LISTO' => const Color(0xFF258A62),
  'ENTREGADO' => const Color(0xFF4774B5),
  'CANCELADO' => const Color(0xFFB15B65),
  'ESPERA_AUTORIZACION' || 'ESPERA_REFACCION' => const Color(0xFFC18439),
  'REPARACION' || 'PRUEBAS' => const Color(0xFF7655B3),
  _ => const Color(0xFF64748B),
};

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: .18))), child: Text(OrderWorkflow.label(status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c)));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 34), child: Column(children: [
    Container(width: 58, height: 58, decoration: BoxDecoration(color: eShokPurpleLight.withValues(alpha: .25), shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, color: eShokPurple, size: 27)),
    const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: eShokInk)),
    const SizedBox(height: 4), Text(message, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8095)), textAlign: TextAlign.center),
  ]));
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}
class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  String _status = '';
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => _future = widget.store.orders(query: _search.text, status: _status);
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _newOrder() async {
    final created = await showDialog<bool>(context: context, builder: (_) => NewOrderDialog(store: widget.store));
    if (created == true && mounted) setState(_refresh);
  }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Órdenes de servicio', subtitle: 'Recepción, diagnóstico, reparación y entrega', trailing: FilledButton.tonalIcon(onPressed: _newOrder, icon: const Icon(Icons.add, size: 18), label: const Text('Nueva'))),
    const SizedBox(height: 14),
    TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar folio, cliente, teléfono o modelo'), onChanged: (_) => setState(_refresh)),
    const SizedBox(height: 9),
    SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
      _filterChip('Todas', ''), ...OrderWorkflow.statuses.map((s) => _filterChip(OrderWorkflow.label(s), s)),
    ])),
    const SizedBox(height: 7),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      if (rows.isEmpty) return const EmptyState(title: 'No hay expedientes', message: 'Prueba otra búsqueda o registra una nueva orden.');
      return RefreshIndicator(onRefresh: () async => setState(_refresh), child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), itemCount: rows.length, itemBuilder: (_, i) {
        final row = rows[i];
        return OrderListTile(order: row, onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(store: widget.store, orderId: row['id'] as int))); if (mounted) setState(_refresh); });
      }));
    })),
  ]));
  Widget _filterChip(String label, String value) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => setState(() { _status = value; _refresh(); }), labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _status == value ? eShokPurple : const Color(0xFF766D81)), selectedColor: eShokPurpleLight.withValues(alpha: .35), backgroundColor: Colors.white, side: const BorderSide(color: eShokBorder)));
}

class NewOrderDialog extends StatefulWidget {
  const NewOrderDialog({super.key, required this.store});
  final LocalStore store;
  @override
  State<NewOrderDialog> createState() => _NewOrderDialogState();
}
class _NewOrderDialogState extends State<NewOrderDialog> {
  final _form = GlobalKey<FormState>();
  final _brand = TextEditingController(text: '');
  final _model = TextEditingController();
  final _failure = TextEditingController();
  final _condition = TextEditingController();
  final _accessories = TextEditingController(text: 'Equipo solamente');
  final _technician = TextEditingController(text: 'Técnico');
  final _imei = TextEditingController();
  final _serial = TextEditingController();
  final _labor = TextEditingController(text: '0');
  final _parts = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _deposit = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _warranty = TextEditingController(text: '30');
  List<Map<String, Object?>> _clients = [];
  int? _clientId;
  bool _saving = false;
  @override
  void initState() { super.initState(); _loadClients(); }
  Future<void> _loadClients() async {
    final rows = await widget.store.clients();
    final warrantyDays = await widget.store.setting('default_warranty_days', fallback: '30');
    if (mounted) setState(() {
      _clients = rows;
      _clientId ??= rows.isNotEmpty ? rows.first['id'] as int : null;
      _warranty.text = warrantyDays;
    });
  }
  @override
  void dispose() { for (final c in [_brand,_model,_failure,_condition,_accessories,_technician,_imei,_serial,_labor,_parts,_discount,_deposit,_notes,_warranty]) { c.dispose(); } super.dispose(); }
  double _v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _clientId == null) return;
    setState(() => _saving = true);
    try {
      await widget.store.createOrder(clientId: _clientId!, brand: _brand.text, model: _model.text, failure: _failure.text, condition: _condition.text, accessories: _accessories.text, technician: _technician.text, labor: _v(_labor), parts: _v(_parts), discount: _v(_discount), deposit: _v(_deposit), notes: _notes.text, imei: _imei.text, serial: _serial.text, warrantyDays: int.tryParse(_warranty.text) ?? 30);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e'))); }
    if (mounted) setState(() => _saving = false);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Recibir equipo'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_clients.isEmpty) ...[
        const Text('Primero registra un cliente para abrir el expediente.'),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async { final id = await showDialog<int>(context: context, builder: (_) => ClientFormDialog(store: widget.store)); if (id != null) { await _loadClients(); setState(() => _clientId = id); } }, icon: const Icon(Icons.person_add_alt_1), label: const Text('Crear cliente'))),
      ] else DropdownButtonFormField<int>(value: _clientId, decoration: const InputDecoration(labelText: 'Cliente'), items: _clients.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(_str(c['name']), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _clientId = v)),
      const SizedBox(height: 10), MediaQuery.sizeOf(context).width < 420
        ? Column(children: [_field(_brand, 'Marca', required: true), const SizedBox(height: 8), _field(_model, 'Modelo', required: true)])
        : Row(children: [Expanded(child: _field(_brand, 'Marca', required: true)), const SizedBox(width: 8), Expanded(child: _field(_model, 'Modelo', required: true))]),
      const SizedBox(height: 9), _field(_failure, 'Falla reportada', required: true, lines: 2),
      const SizedBox(height: 9), _field(_condition, 'Estado físico / observaciones', lines: 2),
      const SizedBox(height: 9), _field(_accessories, 'Accesorios recibidos'),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_imei, 'IMEI')), const SizedBox(width: 8), Expanded(child: _field(_serial, 'Serie'))]),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_labor, 'Mano de obra', number: true)), const SizedBox(width: 8), Expanded(child: _field(_parts, 'Refacciones manuales (sin inventario)', number: true))]),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_discount, 'Descuento', number: true)), const SizedBox(width: 8), Expanded(child: _field(_deposit, 'Anticipo', number: true))]),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_technician, 'Técnico')), const SizedBox(width: 8), SizedBox(width: 92, child: _field(_warranty, 'Garantía días', number: true))]),
      const SizedBox(height: 9), _field(_notes, 'Notas internas', lines: 2),
      if (_clientId != null) Align(alignment: Alignment.centerLeft, child: Text('El registro genera folio, historial y evento de recepción.', style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
    ])))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: _saving || _clientId == null ? null : _save, child: Text(_saving ? 'Guardando…' : 'Crear expediente'))],
  );
}

Widget _field(TextEditingController c, String label, {bool required = false, bool number = false, int lines = 1, ValueChanged<String>? onChanged}) => TextFormField(
  controller: c, maxLines: lines, onChanged: onChanged, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
  decoration: InputDecoration(labelText: label, isDense: true), validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
);

 
class CustomerAuthorizationDialog extends StatefulWidget {
  const CustomerAuthorizationDialog({super.key});
  @override
  State<CustomerAuthorizationDialog> createState() => _CustomerAuthorizationDialogState();
}

class _CustomerAuthorizationDialogState extends State<CustomerAuthorizationDialog> {
  final authorizedBy = TextEditingController();
  final note = TextEditingController();
  String method = 'PRESENCIAL';

  @override
  void dispose() {
    authorizedBy.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Autorización del cliente'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'Registra quién aprobó el diagnóstico y el presupuesto antes de iniciar la reparación o solicitar refacciones.',
        style: TextStyle(fontSize: 11, color: Color(0xFF81778D)),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: authorizedBy,
        decoration: const InputDecoration(labelText: 'Nombre de quien autoriza'),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: method,
        decoration: const InputDecoration(labelText: 'Medio de autorización'),
        items: const [
          DropdownMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
          DropdownMenuItem(value: 'LLAMADA', child: Text('Llamada telefónica')),
          DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
          DropdownMenuItem(value: 'OTRO', child: Text('Otro medio')),
        ],
        onChanged: (value) => setState(() => method = value ?? method),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Nota / alcance autorizado'),
      ),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          if (authorizedBy.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Indica quién autorizó el servicio.'),
            ));
            return;
          }
          Navigator.pop(context, {
            'authorizedBy': authorizedBy.text.trim(),
            'method': method,
            'note': note.text.trim(),
          });
        },
        child: const Text('Guardar autorización'),
      ),
    ],
  );
}


class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.store, required this.orderId});
  final LocalStore store;
  final int orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}
class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<Map<String, Object?>?> _data;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => _data = widget.store.order(widget.orderId);
  Future<void> _status(String status) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Cambiar a ${OrderWorkflow.label(status)}'), content: TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Nota del movimiento (opcional)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar'))]));
    if (ok != true) return;
    try { await widget.store.setOrderStatus(widget.orderId, status, note: note.text); if (mounted) setState(_refresh); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> _diagnosis(String current, String notes) async {
    final d = TextEditingController(text: current), n = TextEditingController(text: notes);
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Diagnóstico técnico'), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: d, maxLines: 4, decoration: const InputDecoration(labelText: 'Diagnóstico')), const SizedBox(height: 8), TextField(controller: n, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas internas'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))]));
    if (result == true) { await widget.store.updateDiagnosis(widget.orderId, d.text, n.text); if (mounted) setState(_refresh); }
  }
  Future<void> _addPart() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => OrderPartDialog(store: widget.store, orderId: widget.orderId),
    );
    if (saved == true && mounted) setState(_refresh);
  }

  Future<void> _authorize() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const CustomerAuthorizationDialog(),
    );
    if (result == null) return;
    try {
      await widget.store.authorizeOrder(
        widget.orderId,
        authorizedBy: result['authorizedBy'] ?? '',
        method: result['method'] ?? 'PRESENCIAL',
        note: result['note'] ?? '',
      );
      if (mounted) setState(_refresh);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _payment(double balance) async {
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final ref = TextEditingController();
    String method = 'EFECTIVO';
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text('Registrar pago'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importe')), const SizedBox(height: 8), DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'Método de pago'), items: const ['EFECTIVO','TRANSFERENCIA','TARJETA','OTRO'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setD(() => method = v ?? method)), const SizedBox(height: 8), TextField(controller: ref, decoration: const InputDecoration(labelText: 'Referencia / nota'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar'))])));
    if (result == true) { try { await widget.store.addOrderPayment(widget.orderId, double.parse(amount.text), method, reference: ref.text); if (mounted) setState(_refresh); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }
  }
  Future<void> _evidence() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 1600);
    if (image == null) return;
    final docs = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(p.join(docs.path, 'evidence'));
    await evidenceDir.create(recursive: true);
    final safeCopy = await File(image.path).copy(p.join(evidenceDir.path, 'order_${widget.orderId}_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    final caption = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Descripción de evidencia'), content: TextField(controller: caption, decoration: const InputDecoration(labelText: 'Ej. Estado al recibir, daño, reparación')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar foto'))]));
    if (result == true) { await widget.store.addEvidence(widget.orderId, safeCopy.path, caption.text); if (mounted) setState(_refresh); }
  }
  Future<void> _printTicket(Map<String, Object?> o) async {
    final shopName = await widget.store.setting('shop_name', fallback: 'eShokFix');
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(12), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(child: pw.Text(shopName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text('Comprobante de servicio', style: const pw.TextStyle(fontSize: 9))), pw.SizedBox(height: 10), pw.Divider(),
      pw.Text('Folio: ${o['folio']}'), pw.Text('Cliente: ${o['client_name']}'), pw.Text('Equipo: ${_str(o['brand'])} ${_str(o['model'])}'),
      pw.Text('IMEI/Serie: ${_str(o['imei']).isEmpty ? _str(o['serial'], 'No registrado') : _str(o['imei'])}'),
      pw.Text('Falla reportada: ${o['failure_description']}'), pw.Text('Diagnóstico: ${_str(o['diagnosis'], 'Pendiente')}'),
      pw.Divider(), pw.Text('Mano de obra: ${_money(o['labor'])}'), pw.Text('Refacciones: ${_money(o['parts_total'])}'),
      pw.Text('Descuento: ${_money(o['discount'])}'), pw.Text('TOTAL: ${_money(o['total'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('Pagado: ${_money(o['paid'])}'), pw.Text('Saldo: ${_money(_num(o['total']) - _num(o['paid']))}'),
      pw.Divider(), pw.Text('Garantía: ${o['warranty_days']} días a partir de la entrega.'),
      pw.SizedBox(height: 10), pw.Center(child: pw.Text('Gracias por confiar en nosotros', style: const pw.TextStyle(fontSize: 8))),
    ])));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'eShokFix-${o['folio']}.pdf');
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: eShokCanvas,
    appBar: AppBar(title: const Text('Expediente'), actions: [IconButton(onPressed: () => setState(_refresh), icon: const Icon(Icons.refresh)), const SizedBox(width: 4)]),
    body: FutureBuilder<Map<String, Object?>?>(future: _data, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final o = snap.data;
      if (o == null) return const EmptyState(title: 'Expediente no encontrado', message: 'El registro pudo haber sido eliminado.');
      final status = _str(o['status']);
      final balance = (_num(o['total']) - _num(o['paid'])).clamp(0, double.infinity).toDouble();
      return ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(gradient: const LinearGradient(colors: [Color(0xFFF3ECFB), Colors.white]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(_str(o['folio']), style: const TextStyle(color: eShokPurple, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .8))), StatusChip(status: status)]),
          const SizedBox(height: 12), Text('${_str(o['brand'])} ${_str(o['model'])}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: eShokInk)),
          const SizedBox(height: 4), Text(_str(o['client_name']), style: const TextStyle(color: Color(0xFF70677E), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), Text('Recibido: ${_date(o['received_at'])}', style: const TextStyle(fontSize: 11, color: Color(0xFF877D93))),
        ])),
        const SizedBox(height: 12),
        SectionHeading('Flujo de trabajo', subtitle: 'Las transiciones no válidas se bloquean'),
        const SizedBox(height: 8),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 7, runSpacing: 7, children: OrderWorkflow.transitions[status]!.map((next) {
            final authorizationPending = _str(o['authorization_status'], 'PENDING') != 'APPROVED';
            final needsAuthorization = next == 'ESPERA_REFACCION' || next == 'REPARACION';
            return ActionChip(
              label: Text(OrderWorkflow.label(next)),
              avatar: const Icon(Icons.arrow_forward, size: 15),
              onPressed: needsAuthorization && authorizationPending ? null : () => _status(next),
              backgroundColor: eShokPurpleLight.withValues(alpha: .28),
            );
          }).toList()),
          if (status == 'ESPERA_AUTORIZACION') ...[
            const SizedBox(height: 10),
            if (_str(o['authorization_status'], 'PENDING') == 'APPROVED')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('AUTORIZACIÓN REGISTRADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF258A62))),
                  const SizedBox(height: 4),
                  Text('${_str(o['authorized_by'])} · ${_str(o['authorization_method'])}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(_date(o['authorized_at']), style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))),
                  if (_str(o['authorization_note']).isNotEmpty) Text(_str(o['authorization_note']), style: const TextStyle(fontSize: 10)),
                ]),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _authorize,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Registrar autorización del cliente'),
                ),
              ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => _diagnosis(_str(o['diagnosis']), _str(o['notes'])), icon: const Icon(Icons.edit_note), label: const Text('Editar diagnóstico y notas')),
        ])),
        const SizedBox(height: 12),
        SectionHeading('Información del equipo'),
        const SizedBox(height: 8),
        GlassCard(child: Column(children: [
          _detail('Falla reportada', _str(o['failure_description'])), _detail('Diagnóstico', _str(o['diagnosis'], 'Pendiente')), _detail('IMEI', _str(o['imei'], 'No registrado')), _detail('Serie', _str(o['serial'], 'No registrada')), _detail('Color', _str(o['color'], 'No registrado')), _detail('Accesorios', _str(o['accessories'], 'No registrados')), _detail('Estado físico', _str(o['condition_note'], 'No registrado')), _detail('Técnico', _str(o['technician'], 'Sin asignar')),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: SectionHeading('Refacciones y materiales')),
          FilledButton.tonalIcon(
            onPressed: status == 'ENTREGADO' || status == 'CANCELADO' || _str(o['authorization_status'], 'PENDING') != 'APPROVED' ? null : _addPart,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Agregar'),
          ),
        ]),
        const SizedBox(height: 7),
        FutureBuilder<List<Map<String, Object?>>>(
          future: widget.store.orderParts(widget.orderId),
          builder: (context, partsSnap) {
            if (!partsSnap.hasData) return const LinearProgressIndicator();
            final rows = partsSnap.data!;
            if (rows.isEmpty) return const EmptyState(
              title: 'Sin refacciones asignadas',
              message: 'Las piezas agregadas aquí descuentan existencias y se suman al total de la orden.',
            );
            return GlassCard(child: Column(children: rows.map((part) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.build_circle_outlined, color: eShokPurple),
              title: Text(_str(part['description']), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_num(part['quantity'])} × ${_money(part['unit_price'])}'),
              trailing: Text(_money(part['line_total']), style: const TextStyle(fontWeight: FontWeight.w900)),
            )).toList()));
          },
        ),
        const SizedBox(height: 12),
        SectionHeading('Cobros y garantía'),
        const SizedBox(height: 8),
        GlassCard(child: Column(children: [
          _detail('Mano de obra', _money(o['labor'])), _detail('Refacciones', _money(o['parts_total'])), _detail('Descuento', _money(o['discount'])), _detail('Total', _money(o['total'])), _detail('Pagado', _money(o['paid'])),
          Row(children: [Expanded(child: Text('Saldo pendiente', style: const TextStyle(fontWeight: FontWeight.w800))), Text(_money(balance), style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? const Color(0xFFBA6D2B) : const Color(0xFF258A62)))]),
          const SizedBox(height: 10), Row(children: [Expanded(child: FilledButton.icon(onPressed: balance > 0 ? () => _payment(balance) : null, icon: const Icon(Icons.payments_outlined), label: const Text('Registrar pago'))), const SizedBox(width: 8), IconButton.filledTonal(onPressed: () => _printTicket(o), icon: const Icon(Icons.print_outlined), tooltip: 'Imprimir / PDF')]),
          Align(alignment: Alignment.centerLeft, child: Text('Garantía al entregar: ${o['warranty_days']} días', style: const TextStyle(fontSize: 10, color: Color(0xFF867C91)))),
        ])),
        const SizedBox(height: 12),
        const SectionHeading('Historial de pagos'),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, Object?>>>(
          future: widget.store.orderPayments(widget.orderId),
          builder: (context, paymentSnap) {
            if (!paymentSnap.hasData) return const LinearProgressIndicator();
            final rows = paymentSnap.data!;
            if (rows.isEmpty) return const EmptyState(
              title: 'Sin pagos registrados',
              message: 'Los anticipos y abonos aparecerán en este historial.',
            );
            return GlassCard(child: Column(children: rows.map((payment) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined, color: eShokPurple),
              title: Text(_money(payment['amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_str(payment['method'])} · ${_date(payment['created_at'])}'),
              trailing: Text(_str(payment['reference']), style: const TextStyle(fontSize: 9)),
            )).toList()));
          },
        ),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: SectionHeading('Evidencias')), FilledButton.tonalIcon(onPressed: _evidence, icon: const Icon(Icons.add_a_photo_outlined, size: 17), label: const Text('Tomar foto'))]),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, Object?>>>(future: widget.store.orderEvidence(widget.orderId), builder: (context, evidenceSnap) {
          final rows = evidenceSnap.data ?? [];
          if (rows.isEmpty) return const EmptyState(title: 'Sin evidencias', message: 'Las fotografías que tomes quedarán asociadas a este expediente.');
          return Column(children: rows.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(child: Row(children: [
            SizedBox(width: 72, height: 72, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_str(e['file_path'])), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF0ECF6), child: Icon(Icons.broken_image_outlined, color: eShokPurple))))),
            const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(e['caption'], 'Evidencia'), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(_date(e['created_at']), style: const TextStyle(fontSize: 10, color: Color(0xFF8A8095)))])),
          ])))).toList());
        }),
        const SizedBox(height: 12),
        SectionHeading('Historial del expediente'), const SizedBox(height: 8),
        FutureBuilder<List<Map<String, Object?>>>(future: widget.store.orderEvents(widget.orderId), builder: (context, eventSnap) => Column(children: (eventSnap.data ?? []).map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.radio_button_checked, color: eShokPurple, size: 18), title: Text(_str(e['description']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: Text('${_date(e['created_at'])}  ·  ${_str(e['from_status'])} → ${_str(e['to_status'])}', style: const TextStyle(fontSize: 9)))).toList())),
        const SizedBox(height: 25),
      ]);
    }),
  );
  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8B8296)))), Expanded(child: Text(value.isEmpty ? 'No registrado' : value, style: const TextStyle(fontSize: 11, color: eShokInk, fontWeight: FontWeight.w700)))]));
}

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}
class _ClientsPageState extends State<ClientsPage> {
  final _query = TextEditingController();
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => _future = widget.store.clients(query: _query.text);
  @override
  void dispose() { _query.dispose(); super.dispose(); }
  Future<void> _edit([Map<String, Object?>? item]) async { final result = await showDialog<int>(context: context, builder: (_) => ClientFormDialog(store: widget.store, client: item)); if (result != null && mounted) setState(_refresh); }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Clientes', subtitle: 'Expedientes, equipos y datos de contacto', trailing: FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1, size: 17), label: const Text('Nuevo'))),
    const SizedBox(height: 13), TextField(controller: _query, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar nombre o teléfono'), onChanged: (_) => setState(_refresh)),
    const SizedBox(height: 8), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final clients = snap.data!;
      if (clients.isEmpty) return const EmptyState(title: 'No hay clientes', message: 'Registra clientes para relacionarlos con los equipos y servicios.');
      return ListView.builder(itemCount: clients.length, itemBuilder: (context, i) {
        final c = clients[i];
        return Padding(padding: const EdgeInsets.only(top: 8), child: GlassCard(child: Row(children: [
          CircleAvatar(backgroundColor: eShokPurpleLight.withValues(alpha: .35), foregroundColor: eShokPurple, child: Text(_str(c['name'], '?').substring(0,1).toUpperCase())),
          const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(c['name']), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(_str(c['phone'], 'Sin teléfono'), style: const TextStyle(fontSize: 10, color: Color(0xFF857B91))), const SizedBox(height: 5), Text('${c['device_count']} equipos · ${c['order_count']} servicios', style: const TextStyle(fontSize: 9, color: eShokPurple, fontWeight: FontWeight.w700))])),
          PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _edit(c); if (v == 'delete') { try { await widget.store.deleteClient(c['id'] as int); if (mounted) setState(_refresh); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Eliminar'))]),
        ])));
      });
    })),
  ]));
}

class ClientFormDialog extends StatefulWidget {
  const ClientFormDialog({super.key, required this.store, this.client});
  final LocalStore store;
  final Map<String, Object?>? client;
  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}
class _ClientFormDialogState extends State<ClientFormDialog> {
  late final _name = TextEditingController(text: _str(widget.client?['name']));
  late final _phone = TextEditingController(text: _str(widget.client?['phone']));
  late final _wa = TextEditingController(text: _str(widget.client?['whatsapp']));
  late final _email = TextEditingController(text: _str(widget.client?['email']));
  late final _address = TextEditingController(text: _str(widget.client?['address']));
  late final _notes = TextEditingController(text: _str(widget.client?['notes']));
  final _form = GlobalKey<FormState>();
  @override
  void dispose() { for (final c in [_name,_phone,_wa,_email,_address,_notes]) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true, title: Text(widget.client == null ? 'Nuevo cliente' : 'Editar cliente'), content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    _field(_name, 'Nombre completo', required: true), const SizedBox(height: 8), _field(_phone, 'Teléfono'), const SizedBox(height: 8), _field(_wa, 'WhatsApp'), const SizedBox(height: 8), _field(_email, 'Correo'), const SizedBox(height: 8), _field(_address, 'Dirección'), const SizedBox(height: 8), _field(_notes, 'Notas', lines: 2),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!_form.currentState!.validate()) return; final id = await widget.store.saveClient(id: widget.client?['id'] as int?, name: _name.text, phone: _phone.text, whatsapp: _wa.text, email: _email.text, address: _address.text, notes: _notes.text); if (context.mounted) Navigator.pop(context, id); }, child: const Text('Guardar'))]);
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}
class _InventoryPageState extends State<InventoryPage> {
  final _query = TextEditingController();
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => _future = widget.store.inventory(query: _query.text);
  @override
  void dispose() { _query.dispose(); super.dispose(); }
  Future<void> _edit([Map<String, Object?>? item]) async { final r = await showDialog<bool>(context: context, builder: (_) => InventoryFormDialog(store: widget.store, item: item)); if (r == true && mounted) setState(_refresh); }
  Future<void> _adjust(Map<String, Object?> item) async { final r = await showDialog<bool>(context: context, builder: (_) => StockDialog(store: widget.store, item: item)); if (r == true && mounted) setState(_refresh); }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Inventario', subtitle: 'Catálogo, existencias y movimientos', trailing: FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 17), label: const Text('Artículo'))),
    const SizedBox(height: 13), TextField(controller: _query, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar SKU o descripción'), onChanged: (_) => setState(_refresh)),
    const SizedBox(height: 9), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      if (rows.isEmpty) return const EmptyState(title: 'Inventario vacío', message: 'Agrega productos, refacciones y accesorios para controlar existencias.');
      return ListView.builder(itemCount: rows.length, itemBuilder: (context, i) {
        final item = rows[i]; final low = _num(item['stock']) <= _num(item['min_stock']);
        return Padding(padding: const EdgeInsets.only(top: 8), child: GlassCard(child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: low ? const Color(0xFFFFF1E2) : eShokPurpleLight.withValues(alpha: .28), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.inventory_2_outlined, color: low ? const Color(0xFFCA7B2C) : eShokPurple)),
          const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(item['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 3), Text('${_str(item['sku'], 'Sin SKU')} · ${_str(item['category'])}', style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296))), const SizedBox(height: 4), Text('${_num(item['stock']).toStringAsFixed(0)} en existencia · ${_money(item['price'])}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: eShokInk))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (low) const Text('STOCK BAJO', style: TextStyle(fontSize: 8, color: Color(0xFFCA7B2C), fontWeight: FontWeight.w900)), TextButton(onPressed: () => _adjust(item), child: const Text('Movimiento', style: TextStyle(fontSize: 10))), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(item); if (v == 'adjust') _adjust(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar artículo')), PopupMenuItem(value: 'adjust', child: Text('Ajustar stock'))])]),
        ])));
      });
    })),
  ]));
}

class InventoryFormDialog extends StatefulWidget {
  const InventoryFormDialog({super.key, required this.store, this.item});
  final LocalStore store; final Map<String, Object?>? item;
  @override
  State<InventoryFormDialog> createState() => _InventoryFormDialogState();
}
class _InventoryFormDialogState extends State<InventoryFormDialog> {
  late final sku = TextEditingController(text: _str(widget.item?['sku']));
  late final name = TextEditingController(text: _str(widget.item?['name']));
  late final category = TextEditingController(text: _str(widget.item?['category'], 'General'));
  late final stock = TextEditingController(text: _str(widget.item?['stock'], '0'));
  late final minStock = TextEditingController(text: _str(widget.item?['min_stock'], '0'));
  late final cost = TextEditingController(text: _str(widget.item?['cost'], '0'));
  late final price = TextEditingController(text: _str(widget.item?['price'], '0'));
  late final location = TextEditingController(text: _str(widget.item?['location']));
  final form = GlobalKey<FormState>();
  @override
  void dispose() { for (final c in [sku,name,category,stock,minStock,cost,price,location]) { c.dispose(); } super.dispose(); }
  double val(TextEditingController c) => double.tryParse(c.text) ?? 0;
  @override
  Widget build(BuildContext context) => AlertDialog(scrollable: true, title: Text(widget.item == null ? 'Nuevo artículo' : 'Editar artículo'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    _field(name, 'Nombre', required: true), const SizedBox(height: 8), Row(children: [Expanded(child: _field(sku, 'SKU / código')), const SizedBox(width: 8), Expanded(child: _field(category, 'Categoría'))]), const SizedBox(height: 8), Row(children: [Expanded(child: _field(stock, 'Existencia', number: true)), const SizedBox(width: 8), Expanded(child: _field(minStock, 'Mínimo', number: true))]), const SizedBox(height: 8), Row(children: [Expanded(child: _field(cost, 'Costo', number: true)), const SizedBox(width: 8), Expanded(child: _field(price, 'Precio', number: true))]), const SizedBox(height: 8), _field(location, 'Ubicación'),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!form.currentState!.validate()) return; await widget.store.saveInventoryItem(id: widget.item?['id'] as int?, sku: sku.text, name: name.text, category: category.text, stock: val(stock), minStock: val(minStock), cost: val(cost), price: val(price), location: location.text); if (context.mounted) Navigator.pop(context, true); }, child: const Text('Guardar'))]);
}

class StockDialog extends StatefulWidget {
  const StockDialog({super.key, required this.store, required this.item});
  final LocalStore store; final Map<String, Object?> item;
  @override
  State<StockDialog> createState() => _StockDialogState();
}
class _StockDialogState extends State<StockDialog> {
  final qty = TextEditingController(); final reason = TextEditingController(); bool incoming = true;
  @override
  void dispose() { qty.dispose(); reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Movimiento de inventario'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text(_str(widget.item['name']), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('Existencia actual: ${_num(widget.item['stock'])}', style: const TextStyle(color: Color(0xFF857B91))), const SizedBox(height: 12), SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('Entrada'), icon: Icon(Icons.add)), ButtonSegment(value: false, label: Text('Salida'), icon: Icon(Icons.remove))], selected: {incoming}, onSelectionChanged: (s) => setState(() => incoming = s.first)), const SizedBox(height: 9), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad')), const SizedBox(height: 8), TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivo'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { final q = double.tryParse(qty.text) ?? 0; if (q <= 0 || reason.text.trim().isEmpty) return; try { await widget.store.adjustInventory(widget.item['id'] as int, incoming ? q : -q, reason.text); if (context.mounted) Navigator.pop(context, true); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('Aplicar'))]);
}

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.open});
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(children: [
    const SectionHeading('Más herramientas', subtitle: 'Módulos administrativos y operación comercial'), const SizedBox(height: 14),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.28, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
      _moduleTile(context, 'Punto de venta', 'Ventas y tickets', Icons.point_of_sale_outlined, 'pos', open),
      _moduleTile(context, 'Compras y proveedores', 'Entradas y cuentas por pagar', Icons.local_shipping_outlined, 'compras', open),
      _moduleTile(context, 'Caja y cortes', 'Entradas y salidas', Icons.account_balance_wallet_outlined, 'caja', open),
      _moduleTile(context, 'Garantías', 'Vigencia y expedientes', Icons.verified_user_outlined, 'garantias', open),
      _moduleTile(context, 'Reportes', 'Resumen del negocio', Icons.query_stats_outlined, 'reportes', open),
      _moduleTile(context, 'Usuarios', 'Roles y acceso', Icons.manage_accounts_outlined, 'usuarios', open),
      _moduleTile(context, 'Configuración', 'Taller y reglas', Icons.tune_outlined, 'configuracion', open),
      _moduleTile(context, 'WhatsApp', 'Eventos automáticos', Icons.chat_bubble_outline, 'whatsapp', open),
      _moduleTile(context, 'Licencias', 'Servidor de validación', Icons.vpn_key_outlined, 'licencias', open),
    ]),
    const SizedBox(height: 15),
    GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Estado de esta beta', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 9), _statusLine(Icons.check_circle, 'Datos locales SQLite', 'Activo'), _statusLine(Icons.check_circle, 'Clientes, órdenes e inventario', 'Operativos'), _statusLine(Icons.check_circle, 'POS, caja, garantías y reportes', 'Operación local'), _statusLine(Icons.pending_outlined, 'Sincronización con PC', 'Pendiente'), _statusLine(Icons.pending_outlined, 'Servidor de licencias', 'Pendiente'), _statusLine(Icons.pending_outlined, 'WhatsApp Cloud API', 'Pendiente de configuración')])),
  ]));
}
Widget _moduleTile(BuildContext context, String title, String sub, IconData icon, String view, ValueChanged<String> open) => InkWell(onTap: () => open(view), borderRadius: BorderRadius.circular(18), child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: eShokPurpleLight.withValues(alpha: .3), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: eShokPurple)), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text(sub, style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296)))])));
Widget _statusLine(IconData icon, String title, String state) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(icon, size: 16, color: icon == Icons.check_circle ? const Color(0xFF29966F) : const Color(0xFFB88945)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), Text(state, style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296)))]));


class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _future = widget.store.sales();

  Future<void> _newSale() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SaleDialog(store: widget.store),
    );
    if (ok == true && mounted) setState(_refresh);
  }

  Future<void> _openSale(Map<String, Object?> sale) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SaleDetailDialog(store: widget.store, sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(children: [
      SectionHeading(
        'Punto de venta',
        subtitle: 'Ventas de mostrador y tickets',
        trailing: FilledButton.tonalIcon(
          onPressed: _newSale,
          icon: const Icon(Icons.add_shopping_cart, size: 17),
          label: const Text('Nueva venta'),
        ),
      ),
      const SizedBox(height: 12),
      GlassCard(child: Row(children: [
        const Icon(Icons.receipt_long_outlined, color: eShokPurple, size: 25),
        const SizedBox(width: 10),
        const Expanded(child: Text(
          'Arma ventas con varios productos y servicios, descuenta inventario y registra el cobro en caja en una sola operación.',
          style: TextStyle(fontSize: 10, color: Color(0xFF786F83), height: 1.35),
        )),
      ])),
      const SizedBox(height: 10),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snap.data!;
            if (rows.isEmpty) return const EmptyState(
              title: 'Sin ventas',
              message: 'Registra una venta para comenzar el historial.',
            );
            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final sale = rows[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GlassCard(child: ListTile(
                    onTap: () => _openSale(sale),
                    leading: const Icon(Icons.receipt_outlined, color: eShokPurple),
                    title: Text(_str(sale['folio']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${_date(sale['created_at'])} · ${_str(sale['payment_method'])} · ${_str(sale['client_name'], 'Venta de mostrador')}',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF8A8095)),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money(sale['total']), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const Text('VER TICKET', style: TextStyle(fontSize: 8, color: eShokPurple, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )),
                );
              },
            );
          },
        ),
      ),
    ]),
  );
}

class _SaleLineDraft {
  _SaleLineDraft({this.itemId})
      : description = TextEditingController(),
        quantity = TextEditingController(text: '1'),
        unitPrice = TextEditingController(text: '0');

  int? itemId;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class SaleDialog extends StatefulWidget {
  const SaleDialog({super.key, required this.store});
  final LocalStore store;
  @override
  State<SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<SaleDialog> {
  List<Map<String, Object?>> _items = [];
  List<Map<String, Object?>> _clients = [];
  final List<_SaleLineDraft> _lines = [];
  final discount = TextEditingController(text: '0');
  final notes = TextEditingController();
  int? clientId;
  String method = 'EFECTIVO';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.store.inventory(),
      widget.store.clients(),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0];
      _clients = results[1];
      _lines.add(_SaleLineDraft());
      loading = false;
    });
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    discount.dispose();
    notes.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? -1;

  double get _subtotal => _lines.fold<double>(0, (sum, line) {
    final qty = double.tryParse(line.quantity.text.trim().replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(line.unitPrice.text.trim().replaceAll(',', '.')) ?? 0;
    return sum + (qty * price);
  });

  void _addLine() => setState(() => _lines.add(_SaleLineDraft()));

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  void _selectItem(_SaleLineDraft line, int? selectedId) {
    Map<String, Object?>? selected;
    for (final item in _items) {
      if (item['id'] == selectedId) {
        selected = item;
        break;
      }
    }
    final chosen = selected;
    setState(() {
      line.itemId = selectedId;
      if (chosen != null) {
        line.description.text = _str(chosen['name']);
        line.unitPrice.text = _num(chosen['price']).toStringAsFixed(2);
      }
    });
  }

  Future<void> _save() async {
    if (_lines.any((line) =>
        line.description.text.trim().isEmpty ||
        _value(line.quantity) <= 0 ||
        _value(line.unitPrice) < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completa la descripción, cantidad y precio de cada partida.'),
      ));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.createSaleCart(
        clientId: clientId,
        items: _lines.map((line) => <String, Object?>{
          'item_id': line.itemId,
          'description': line.description.text.trim(),
          'quantity': _value(line.quantity),
          'unit_price': _value(line.unitPrice),
        }).toList(),
        paymentMethod: method,
        discount: double.tryParse(discount.text.trim().replaceAll(',', '.')) ?? 0,
        notes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const AlertDialog(
      content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
    );

    final discountValue = double.tryParse(discount.text.trim().replaceAll(',', '.')) ?? 0;
    final total = PurchaseAccounting.total(_subtotal, discountValue);
    return AlertDialog(
      scrollable: true,
      title: const Text('Nueva venta'),
      content: SizedBox(width: 470, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int?>(
          initialValue: clientId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cliente (opcional)'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Venta de mostrador')),
            ..._clients.map((client) => DropdownMenuItem<int?>(
              value: client['id'] as int,
              child: Text(_str(client['name']), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (value) => setState(() => clientId = value),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Productos y servicios', style: TextStyle(fontWeight: FontWeight.w800))),
          TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Agregar'),
          ),
        ]),
        ..._lines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<int?>(
                  initialValue: line.itemId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Artículo ${index + 1}'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Servicio / venta libre')),
                    ..._items.map((item) => DropdownMenuItem<int?>(
                      value: item['id'] as int,
                      child: Text('${_str(item['name'])} · ${_num(item['stock']).toStringAsFixed(0)} disp.',
                        overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (value) => _selectItem(line, value),
                )),
                IconButton(
                  onPressed: _lines.length <= 1 ? null : () => _removeLine(index),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar partida',
                ),
              ]),
              const SizedBox(height: 6),
              _field(line.description, 'Descripción', required: true),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _field(line.quantity, 'Cantidad', required: true, number: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: _field(line.unitPrice, 'Precio unitario', required: true, number: true, onChanged: (_) => setState(() {}))),
              ]),
            ]),
          );
        }),
        const Divider(),
        _field(discount, 'Descuento global', number: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'Método de pago'),
          items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (value) => setState(() => method = value ?? method),
        ),
        const SizedBox(height: 8),
        _field(notes, 'Notas / referencia'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal: ${_money(_subtotal)}', style: const TextStyle(fontSize: 11)),
            Text('Total: ${_money(total)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: eShokPurple)),
          ]),
        ),
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: saving ? null : _save,
          child: Text(saving ? 'Procesando…' : 'Cobrar venta')),
      ],
    );
  }
}

class SaleDetailDialog extends StatefulWidget {
  const SaleDetailDialog({super.key, required this.store, required this.sale});
  final LocalStore store;
  final Map<String, Object?> sale;
  @override
  State<SaleDetailDialog> createState() => _SaleDetailDialogState();
}

class _SaleDetailDialogState extends State<SaleDetailDialog> {
  late Future<List<Map<String, Object?>>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.store.saleItems(widget.sale['id'] as int);
  }

  Future<void> _printTicket(List<Map<String, Object?>> items) async {
    final sale = widget.sale;
    final shopName = await widget.store.setting('shop_name', fallback: 'eShokFix');
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(12),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text(shopName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('Ticket de venta', style: const pw.TextStyle(fontSize: 9))),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Text('Folio: ${sale['folio']}'),
          pw.Text('Fecha: ${_date(sale['created_at'])}'),
          pw.Text('Cliente: ${_str(sale['client_name'], 'Venta de mostrador')}'),
          pw.Divider(),
          ...items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${item['description']}'),
              pw.Text('${_num(item['quantity'])} × ${_money(item['unit_price'])} = ${_money(item['line_total'])}',
                style: const pw.TextStyle(fontSize: 9)),
            ]),
          )),
          pw.Divider(),
          pw.Text('Subtotal: ${_money(sale['subtotal'])}'),
          pw.Text('Descuento: ${_money(sale['discount'])}'),
          pw.Text('TOTAL: ${_money(sale['total'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text('Pago: ${_str(sale['payment_method'])}'),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('Gracias por tu compra', style: const pw.TextStyle(fontSize: 8))),
        ],
      ),
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'eShokFix-${sale['folio']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Ticket ${_str(widget.sale['folio'])}'),
    content: SizedBox(width: 440, child: FutureBuilder<List<Map<String, Object?>>>(
      future: _items,
      builder: (context, snap) {
        if (snap.hasError) return Text('No se pudieron cargar las partidas: ${snap.error}');
        if (!snap.hasData) return const LinearProgressIndicator();
        final rows = snap.data!;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_str(widget.sale['client_name'], 'Venta de mostrador')} · ${_date(widget.sale['created_at'])}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))),
          const SizedBox(height: 8),
          ...rows.map((item) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_str(item['description'])),
            subtitle: Text('${_num(item['quantity'])} × ${_money(item['unit_price'])}'),
            trailing: Text(_money(item['line_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
          const Divider(),
          _reportLine('Subtotal', _money(widget.sale['subtotal'])),
          _reportLine('Descuento', _money(widget.sale['discount'])),
          _reportLine('Total', _money(widget.sale['total'])),
          _reportLine('Método de pago', _str(widget.sale['payment_method'])),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _printTicket(rows),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir / PDF'),
            ),
          ),
        ]);
      },
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
    ],
  );
}

class CashPage extends StatefulWidget { const CashPage({super.key, required this.store}); final LocalStore store; @override State<CashPage> createState() => _CashPageState(); }
class _CashPageState extends State<CashPage> {
  late Future<Map<String, double>> _summary;
  late Future<List<Map<String, Object?>>> _movements;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() { _summary = widget.store.cashSummary(); _movements = widget.store.cashMovements(); }
  Future<void> _movement() async { final ok = await showDialog<bool>(context: context, builder: (_) => CashMovementDialog(store: widget.store)); if (ok == true && mounted) setState(_refresh); }
  Future<void> _cut(double expected) async { final c = TextEditingController(text: expected.toStringAsFixed(2)); final note = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cerrar corte de caja'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Efectivo esperado: ${_money(expected)}'), const SizedBox(height: 8), TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Efectivo contado')), const SizedBox(height: 8), TextField(controller: note, decoration: const InputDecoration(labelText: 'Observaciones'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar corte'))])); if (ok == true) { try { await widget.store.closeCashCut(double.parse(c.text), note.text); if (mounted) setState(_refresh); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } }
  @override Widget build(BuildContext context) => PageFrame(child: FutureBuilder<Map<String, double>>(future: _summary, builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final s = snap.data!;
    return Column(children: [SectionHeading('Caja y cortes', subtitle: 'Movimientos desde el último corte', trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'movement') _movement(); if (v == 'cut') _cut(s['balance'] ?? 0); }, itemBuilder: (_) => const [PopupMenuItem(value: 'movement', child: Text('Nuevo movimiento')), PopupMenuItem(value: 'cut', child: Text('Cerrar corte'))], child: const Icon(Icons.more_vert))), const SizedBox(height: 12), GlassCard(gradient: const LinearGradient(colors: [Color(0xFFF1EBF9), Colors.white]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Efectivo esperado', style: TextStyle(fontSize: 11, color: Color(0xFF80768C), fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(_money(s['balance']), style: const TextStyle(fontSize: 30, color: eShokPurple, fontWeight: FontWeight.w900)), const SizedBox(height: 12), Row(children: [Expanded(child: _smallStat('Entradas efectivo', _money(s['income']), const Color(0xFF258A62))), Expanded(child: _smallStat('Salidas efectivo', _money(s['expense']), const Color(0xFFB65E69)))]), const SizedBox(height: 7), Align(alignment: Alignment.centerLeft, child: _smallStat('Saldo electrónico del periodo', _money(s['digital_balance']), const Color(0xFF4774B5))), const SizedBox(height: 11), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _movement, icon: const Icon(Icons.add), label: const Text('Movimiento'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: () => _cut(s['balance'] ?? 0), icon: const Icon(Icons.lock_clock), label: const Text('Cerrar corte')))] )])),
      const SizedBox(height: 15), const SectionHeading('Últimos movimientos'), const SizedBox(height: 7), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _movements, builder: (context, m) { if (!m.hasData) return const Center(child: CircularProgressIndicator()); final rows = m.data!; if (rows.isEmpty) return const EmptyState(title: 'Sin movimientos', message: 'Las entradas de ventas y pagos aparecerán aquí.'); return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final r = rows[i]; final inc = r['movement_type'] == 'IN'; return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: (inc ? const Color(0xFF29966F) : const Color(0xFFB65E69)).withValues(alpha: .12), child: Icon(inc ? Icons.south_west : Icons.north_east, color: inc ? const Color(0xFF29966F) : const Color(0xFFB65E69))), title: Text(_str(r['concept']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: Text('${_date(r['created_at'])} · ${_str(r['payment_method'], 'EFECTIVO')}', style: const TextStyle(fontSize: 9)), trailing: Text('${inc ? '+' : '-'}${_money(r['amount'])}', style: TextStyle(fontWeight: FontWeight.w900, color: inc ? const Color(0xFF258A62) : const Color(0xFFB65E69)))); }); }))]);
  }));
}
Widget _smallStat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF80768C))), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))]);

class CashMovementDialog extends StatefulWidget { const CashMovementDialog({super.key, required this.store}); final LocalStore store; @override State<CashMovementDialog> createState() => _CashMovementDialogState(); }
class _CashMovementDialogState extends State<CashMovementDialog> {
  final amount = TextEditingController();
  final concept = TextEditingController();
  bool income = true;
  String method = 'EFECTIVO';

  @override
  void dispose() {
    amount.dispose();
    concept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Movimiento de caja'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Entrada')),
          ButtonSegment(value: false, label: Text('Salida')),
        ],
        selected: {income},
        onSelectionChanged: (value) => setState(() => income = value.first),
      ),
      const SizedBox(height: 9),
      _field(amount, 'Importe', required: true, number: true),
      const SizedBox(height: 8),
      _field(concept, 'Concepto', required: true),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: method,
        decoration: const InputDecoration(labelText: 'Medio de pago'),
        items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
          .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: (value) => setState(() => method = value ?? method),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () async {
          try {
            await widget.store.addCashMovement(
              income: income,
              amount: double.parse(amount.text.replaceAll(',', '.')),
              concept: concept.text,
              paymentMethod: method,
            );
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

class WarrantiesPage extends StatefulWidget { const WarrantiesPage({super.key, required this.store}); final LocalStore store; @override State<WarrantiesPage> createState() => _WarrantiesPageState(); }
class _WarrantiesPageState extends State<WarrantiesPage> { late Future<List<Map<String, Object?>>> _future; @override void initState() { super.initState(); _future = widget.store.warranties(); } @override Widget build(BuildContext context) => PageFrame(child: Column(children: [const SectionHeading('Centro de garantías', subtitle: 'Las garantías se generan al registrar la entrega'), const SizedBox(height: 12), Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; if (rows.isEmpty) return const EmptyState(title: 'Todavía no hay garantías', message: 'Al entregar una orden se generará su garantía automáticamente.'); return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) { final w = rows[i]; final end = DateTime.tryParse(_str(w['ends_at'])); final valid = end != null && end.isAfter(DateTime.now()); return Padding(padding: const EdgeInsets.only(top: 8), child: GlassCard(child: Row(children: [Icon(valid ? Icons.verified_user_outlined : Icons.warning_amber_outlined, color: valid ? const Color(0xFF258A62) : const Color(0xFFB65E69), size: 28), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(w['folio']), style: const TextStyle(fontWeight: FontWeight.w800)), Text('${_str(w['client_name'])} · ${_str(w['brand'])} ${_str(w['model'])}', style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))), Text('Vence: ${_day(w['ends_at'])}', style: const TextStyle(fontSize: 10))])), Text(valid ? 'VIGENTE' : 'VENCIDA', style: TextStyle(fontSize: 9, color: valid ? const Color(0xFF258A62) : const Color(0xFFB65E69), fontWeight: FontWeight.w900))]))); }); }))])); }

class ReportsPage extends StatefulWidget { const ReportsPage({super.key, required this.store}); final LocalStore store; @override State<ReportsPage> createState() => _ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage> { late Future<Map<String, double>> _future; @override void initState() { super.initState(); _future = widget.store.reportTotals(); } @override Widget build(BuildContext context) => PageFrame(child: FutureBuilder<Map<String, double>>(future: _future, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final r = snap.data!; return ListView(children: [const SectionHeading('Reportes', subtitle: 'Resumen acumulado de la base local'), const SizedBox(height: 14), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.18, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [MetricCard(title: 'Órdenes', value: r['orders_count']!.toStringAsFixed(0), icon: Icons.assignment_outlined), MetricCard(title: 'Ventas POS', value: r['sales_count']!.toStringAsFixed(0), icon: Icons.point_of_sale_outlined, tint: const Color(0xFF4D8CBE)), MetricCard(title: 'Valor órdenes', value: _money(r['orders_total']), icon: Icons.build_outlined), MetricCard(title: 'Pagos a órdenes', value: _money(r['orders_paid']), icon: Icons.payments_outlined, tint: const Color(0xFF29966F))]), const SizedBox(height: 12), GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Indicadores financieros', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 12), _reportLine('Ventas registradas', _money(r['sales_total'])), _reportLine('Saldo de caja desde el último corte', _money(r['cash_balance'])), _reportLine('Pendiente por cobrar en servicios', _money(r['orders_total']! - r['orders_paid']!)), const SizedBox(height: 10), const Text('Este primer corte usa datos locales acumulados. Los filtros por periodo, exportación y conciliación con escritorio se incorporarán a la integración financiera.', style: TextStyle(fontSize: 10, color: Color(0xFF81778D), height: 1.4))]))]); })); }
Widget _reportLine(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF80768C)))), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: eShokInk))]));

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

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  bool _showSuppliers = false;
  late Future<List<Map<String, Object?>>> _purchases;
  late Future<List<Map<String, Object?>>> _suppliers;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _purchases = widget.store.purchases();
    _suppliers = widget.store.suppliers();
  }

  Future<void> _newSupplier([Map<String, Object?>? supplier]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SupplierDialog(store: widget.store, supplier: supplier),
    );
    if (saved == true && mounted) setState(_refresh);
  }

  Future<void> _newPurchase() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => PurchaseDialog(store: widget.store),
    );
    if (saved == true && mounted) setState(_refresh);
  }

  Future<void> _openPurchase(Map<String, Object?> purchase) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => PurchaseDetailDialog(store: widget.store, purchase: purchase),
    );
    if (updated == true && mounted) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(children: [
      SectionHeading(
        'Compras y proveedores',
        subtitle: _showSuppliers ? 'Directorio de proveedores' : 'Recepciones y cuentas por pagar',
        trailing: FilledButton.tonalIcon(
          onPressed: _showSuppliers ? () => _newSupplier() : _newPurchase,
          icon: Icon(_showSuppliers ? Icons.person_add_alt_1 : Icons.add_shopping_cart, size: 17),
          label: Text(_showSuppliers ? 'Nuevo proveedor' : 'Nueva compra'),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Compras'), icon: Icon(Icons.receipt_long_outlined)),
          ButtonSegment(value: true, label: Text('Proveedores'), icon: Icon(Icons.local_shipping_outlined)),
        ],
        selected: {_showSuppliers},
        onSelectionChanged: (value) => setState(() => _showSuppliers = value.first),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _showSuppliers
          ? FutureBuilder<List<Map<String, Object?>>>(
              future: _suppliers,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snap.data!;
                if (rows.isEmpty) return const EmptyState(
                  title: 'Sin proveedores',
                  message: 'Registra a tus proveedores para documentar las compras del taller.',
                );
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: GlassCard(child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: eShokPurpleLight,
                          child: Icon(Icons.local_shipping_outlined, color: eShokPurple),
                        ),
                        title: Text(_str(row['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text([
                          _str(row['phone']),
                          _str(row['email']),
                          if (_str(row['tax_id']).isNotEmpty) 'RFC ${_str(row['tax_id'])}',
                        ].where((v) => v.isNotEmpty).join(' · ')),
                        trailing: const Icon(Icons.edit_outlined, color: eShokPurple),
                        onTap: () => _newSupplier(row),
                      )),
                    );
                  },
                );
              },
            )
          : FutureBuilder<List<Map<String, Object?>>>(
              future: _purchases,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snap.data!;
                if (rows.isEmpty) return const EmptyState(
                  title: 'Sin compras registradas',
                  message: 'Registra una compra para aumentar existencias y controlar pagos al proveedor.',
                );
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    final balance = PurchaseAccounting.balance(
                      _num(row['total']), _num(row['paid']),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: GlassCard(child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEAF4EF),
                          child: Icon(Icons.inventory_2_outlined, color: Color(0xFF258A62)),
                        ),
                        title: Text(_str(row['folio']), style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${_str(row['supplier_name'])} · ${_date(row['created_at'])}\n${_str(row['payment_status'])} · Saldo ${_money(balance)}'),
                        isThreeLine: true,
                        trailing: Text(_money(row['total']), style: const TextStyle(fontWeight: FontWeight.w900)),
                        onTap: () => _openPurchase(row),
                      )),
                    );
                  },
                );
              },
            ),
      ),
    ]),
  );
}

class SupplierDialog extends StatefulWidget {
  const SupplierDialog({super.key, required this.store, this.supplier});
  final LocalStore store;
  final Map<String, Object?>? supplier;
  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
  late final name = TextEditingController(text: _str(widget.supplier?['name']));
  late final phone = TextEditingController(text: _str(widget.supplier?['phone']));
  late final whatsapp = TextEditingController(text: _str(widget.supplier?['whatsapp']));
  late final email = TextEditingController(text: _str(widget.supplier?['email']));
  late final taxId = TextEditingController(text: _str(widget.supplier?['tax_id']));
  late final address = TextEditingController(text: _str(widget.supplier?['address']));
  late final notes = TextEditingController(text: _str(widget.supplier?['notes']));

  @override
  void dispose() {
    for (final c in [name, phone, whatsapp, email, taxId, address, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.supplier == null ? 'Nuevo proveedor' : 'Editar proveedor'),
    content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Razón social / nombre')),
      const SizedBox(height: 8),
      TextField(controller: taxId, decoration: const InputDecoration(labelText: 'RFC')),
      const SizedBox(height: 8),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
      const SizedBox(height: 8),
      TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp')),
      const SizedBox(height: 8),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
      const SizedBox(height: 8),
      TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Domicilio')),
      const SizedBox(height: 8),
      TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () async {
          if (name.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre del proveedor es obligatorio.')));
            return;
          }
          try {
            await widget.store.saveSupplier(
              id: widget.supplier?['id'] as int?,
              name: name.text, phone: phone.text, whatsapp: whatsapp.text,
              email: email.text, taxId: taxId.text, address: address.text,
              notes: notes.text,
            );
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        },
        child: const Text('Guardar proveedor'),
      ),
    ],
  );
}

class _PurchaseLineDraft {
  _PurchaseLineDraft({required this.itemId, required double initialCost})
      : quantity = TextEditingController(text: '1'),
        unitCost = TextEditingController(text: initialCost.toStringAsFixed(2));

  int itemId;
  final TextEditingController quantity;
  final TextEditingController unitCost;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class PurchaseDialog extends StatefulWidget {
  const PurchaseDialog({super.key, required this.store});
  final LocalStore store;
  @override
  State<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<PurchaseDialog> {
  List<Map<String, Object?>> _suppliers = [];
  List<Map<String, Object?>> _items = [];
  final List<_PurchaseLineDraft> _lines = [];
  int? _supplierId;
  final discount = TextEditingController(text: '0');
  final paid = TextEditingController(text: '0');
  final notes = TextEditingController();
  String paymentMethod = 'EFECTIVO';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suppliers = await widget.store.suppliers();
    final items = await widget.store.inventory();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _items = items;
      _supplierId = suppliers.isEmpty ? null : suppliers.first['id'] as int;
      if (items.isNotEmpty) {
        _lines.add(_PurchaseLineDraft(
          itemId: items.first['id'] as int,
          initialCost: _num(items.first['cost']),
        ));
      }
      loading = false;
    });
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    discount.dispose();
    paid.dispose();
    notes.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? -1;

  double get _subtotal => _lines.fold<double>(0, (sum, line) {
    final qty = double.tryParse(line.quantity.text.trim().replaceAll(',', '.')) ?? 0;
    final cost = double.tryParse(line.unitCost.text.trim().replaceAll(',', '.')) ?? 0;
    return sum + PurchaseAccounting.lineTotal(qty, cost);
  });

  void _addLine() {
    if (_items.isEmpty) return;
    setState(() => _lines.add(_PurchaseLineDraft(
      itemId: _items.first['id'] as int,
      initialCost: _num(_items.first['cost']),
    )));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  void _changeItem(_PurchaseLineDraft line, int? itemId) {
    if (itemId == null) return;
    Map<String, Object?>? selected;
    for (final candidate in _items) {
      if (candidate['id'] == itemId) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) return;
    setState(() {
      line.itemId = itemId;
      line.unitCost.text = _num(selected!['cost']).toStringAsFixed(2);
    });
  }

  Future<void> _save() async {
    if (_supplierId == null || _items.isEmpty || _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Primero registra un proveedor y al menos un artículo de inventario.'),
      ));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.createPurchase(
        supplierId: _supplierId!,
        items: _lines.map((line) => <String, Object?>{
          'item_id': line.itemId,
          'quantity': _value(line.quantity),
          'unit_cost': _value(line.unitCost),
        }).toList(),
        discount: _value(discount),
        paid: _value(paid),
        paymentMethod: paymentMethod,
        notes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const AlertDialog(content: SizedBox(
      height: 90, child: Center(child: CircularProgressIndicator()),
    ));
    return AlertDialog(
      scrollable: true,
      title: const Text('Registrar compra'),
      content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          initialValue: _supplierId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Proveedor'),
          items: _suppliers.map((s) => DropdownMenuItem(
            value: s['id'] as int, child: Text(_str(s['name']), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _supplierId = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Artículos recibidos', style: TextStyle(fontWeight: FontWeight.w800))),
          TextButton.icon(onPressed: _items.isEmpty ? null : _addLine,
            icon: const Icon(Icons.add, size: 17), label: const Text('Agregar artículo')),
        ]),
        if (_items.isEmpty) const EmptyState(
          title: 'Inventario vacío',
          message: 'Crea primero los artículos que vas a recibir en Inventario.',
        ),
        ..._lines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: line.itemId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Artículo ${index + 1}'),
                  items: _items.map((item) => DropdownMenuItem(
                    value: item['id'] as int,
                    child: Text(_str(item['name']), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => _changeItem(line, value),
                )),
                IconButton(onPressed: _lines.length <= 1 ? null : () => _removeLine(index),
                  icon: const Icon(Icons.delete_outline), tooltip: 'Quitar partida'),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _field(line.quantity, 'Cantidad', required: true, number: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: _field(line.unitCost, 'Costo unitario', required: true, number: true, onChanged: (_) => setState(() {}))),
              ]),
            ]),
          );
        }),
        const Divider(),
        _field(discount, 'Descuento global', number: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        _field(paid, 'Pago inicial al proveedor', number: true),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          decoration: const InputDecoration(labelText: 'Método de pago'),
          items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => paymentMethod = v ?? paymentMethod),
        ),
        const SizedBox(height: 8),
        _field(notes, 'Notas / referencia'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal: ${_money(_subtotal)}', style: const TextStyle(fontSize: 11)),
            Text('Total estimado: ${_money(PurchaseAccounting.total(_subtotal, double.tryParse(discount.text) ?? 0))}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: eShokPurple)),
          ]),
        ),
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: saving || _lines.isEmpty || _supplierId == null ? null : _save,
          child: Text(saving ? 'Guardando…' : 'Registrar compra')),
      ],
    );
  }
}

class PurchaseDetailDialog extends StatefulWidget {
  const PurchaseDetailDialog({super.key, required this.store, required this.purchase});
  final LocalStore store;
  final Map<String, Object?> purchase;
  @override
  State<PurchaseDetailDialog> createState() => _PurchaseDetailDialogState();
}

class _PurchaseDetailDialogState extends State<PurchaseDetailDialog> {
  final amount = TextEditingController();
  String method = 'EFECTIVO';
  bool saving = false;
  late Future<List<Map<String, Object?>>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.store.purchaseItems(widget.purchase['id'] as int);
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _num(widget.purchase['total']);
    final paid = _num(widget.purchase['paid']);
    final balance = PurchaseAccounting.balance(total, paid);
    return AlertDialog(
      scrollable: true,
      title: Text(_str(widget.purchase['folio'])),
      content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Proveedor: ${_str(widget.purchase['supplier_name'])}'),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _items,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            return Column(children: snap.data!.map((line) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_str(line['description'])),
              subtitle: Text('${_num(line['quantity'])} × ${_money(line['unit_cost'])}'),
              trailing: Text(_money(line['line_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
            )).toList());
          },
        ),
        const Divider(),
        _reportLine('Subtotal', _money(widget.purchase['subtotal'])),
        _reportLine('Descuento', _money(widget.purchase['discount'])),
        _reportLine('Total', _money(total)),
        _reportLine('Pagado', _money(paid)),
        _reportLine('Saldo', _money(balance)),
        if (balance > 0.01) ...[
          const Divider(),
          const Text('Registrar abono', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Importe', hintText: balance.toStringAsFixed(2))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Método'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => method = v ?? method),
          ),
        ],
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cerrar')),
        if (balance > 0.01) FilledButton(
          onPressed: saving ? null : () async {
            final value = double.tryParse(amount.text.trim());
            if (value == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un importe válido.')));
              return;
            }
            setState(() => saving = true);
            try {
              await widget.store.recordPurchasePayment(widget.purchase['id'] as int, value, method);
              if (mounted) Navigator.pop(context, true);
            } catch (e) {
              if (mounted) {
                setState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          child: Text(saving ? 'Guardando…' : 'Registrar abono'),
        ),
      ],
    );
  }
} 

class OrderPartDialog extends StatefulWidget {
  const OrderPartDialog({super.key, required this.store, required this.orderId});
  final LocalStore store;
  final int orderId;
  @override
  State<OrderPartDialog> createState() => _OrderPartDialogState();
}

class _OrderPartDialogState extends State<OrderPartDialog> {
  List<Map<String, Object?>> _items = [];
  int? _itemId;
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController(text: '0');
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.store.inventory();
    if (!mounted) return;
    setState(() {
      _items = items.where((item) => _num(item['stock']) > 0).toList();
      if (_items.isNotEmpty) {
        _itemId = _items.first['id'] as int;
        price.text = _num(_items.first['price']).toStringAsFixed(2);
      }
      loading = false;
    });
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(quantity.text.trim());
    final unitPrice = double.tryParse(price.text.trim());
    if (_itemId == null || qty == null || unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona una refacción e indica cantidad y precio válidos.'),
      ));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.addOrderPart(widget.orderId, _itemId!, qty, unitPrice: unitPrice);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const AlertDialog(
      content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
    );
    return AlertDialog(
      title: const Text('Agregar refacción a la orden'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_items.isEmpty) const EmptyState(
          title: 'No hay existencias disponibles',
          message: 'Registra artículos y existencias antes de asignar refacciones a una orden.',
        ) else DropdownButtonFormField<int>(
          initialValue: _itemId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Artículo de inventario'),
          items: _items.map((item) => DropdownMenuItem(
            value: item['id'] as int,
            child: Text('${_str(item['name'])} · stock ${_num(item['stock']).toStringAsFixed(2)}',
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) {
            Map<String, Object?>? selected;
            for (final item in _items) {
              if (item['id'] == value) { selected = item; break; }
            }
            if (selected != null) setState(() {
              _itemId = value;
              price.text = _num(selected!['price']).toStringAsFixed(2);
            });
          },
        ),
        const SizedBox(height: 9),
        _field(quantity, 'Cantidad', required: true, number: true),
        const SizedBox(height: 8),
        _field(price, 'Precio unitario al cliente', required: true, number: true),
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: saving || _items.isEmpty ? null : _save,
          child: Text(saving ? 'Guardando…' : 'Agregar refacción')),
      ],
    );
  }
}
