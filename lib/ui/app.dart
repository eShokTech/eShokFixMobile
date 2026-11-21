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
import '../data/auth_service.dart';
import '../data/database_backup_service.dart';
import 'package:flutter/services.dart';
import '../domain/workflow.dart';
import '../domain/financial_rules.dart';
import '../domain/pricing_rules.dart';
import 'theme.dart';
import 'brand_logo.dart';

part 'modules/orders_ui.dart';
part 'modules/clients_inventory_ui.dart';
part 'modules/sales_ui.dart';
part 'modules/finance_ui.dart';
part 'modules/admin_ui.dart';
part 'modules/purchases_ui.dart';
part 'modules/orders_part_ui.dart';
part 'modules/search_notifications_ui.dart';


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
  const EShokFixShell({super.key, required this.store, required this.authUser, required this.onLogout});
  final LocalStore store;
  final AuthUser authUser;
  final VoidCallback onLogout;
  @override
  State<EShokFixShell> createState() => _EShokFixShellState();
}

class _EShokFixShellState extends State<EShokFixShell> {
  String _view = 'inicio';
  final TextEditingController _globalSearchController = TextEditingController();
  String _globalSearchQuery = '';
  late Future<int> _notificationCountFuture;

  @override
  void initState() {
    super.initState();
    _notificationCountFuture = _loadNotificationCount();
  }

  Future<int> _loadNotificationCount() async {
    try {
      await widget.store.refreshOperationalNotifications();
      return await widget.store.unreadNotificationCount();
    } catch (_) {
      return 0;
    }
  }

  void _refreshNotificationCount() {
    if (!mounted) return;
    setState(() => _notificationCountFuture = _loadNotificationCount());
  }

  void _onGlobalSearchChanged(String value) {
    if (!_canOpen('busqueda')) {
      _open('busqueda');
      return;
    }
    setState(() {
      _globalSearchQuery = value;
      _view = 'busqueda';
    });
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }
  bool _canOpen(String view) {
    final permission = switch (view) {
      'inicio' => 'dashboard.view',
      'ordenes' => 'orders.view',
      'clientes' => 'clients.view',
      'inventario' => 'inventory.view',
      'pos' || 'caja' => 'sales.view',
      'cortes' => 'cash.view',
      'compras' => 'purchases.view',
      'garantias' => 'warranties.view',
      'reportes' => 'reports.view',
      'usuarios' => 'users.manage',
      'configuracion' => 'settings.view',
      'whatsapp' || 'licencias' => 'settings.read',
      'busqueda' || 'notificaciones' => 'dashboard.view',
      _ => 'dashboard.view',
    };
    return AuthService.can(widget.authUser.role, permission);
  }

  void _open(String view) {
    if (!_canOpen(view)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu rol no tiene permiso para abrir este módulo.')),
      );
      return;
    }
    setState(() => _view = view);
  }
  int get _selectedNav => switch (_view) {
    'inicio' => 0, 'ordenes' => 1, 'clientes' => 2, 'caja' || 'pos' => 3, _ => 4,
  };


  @override
  Widget build(BuildContext context) {
    Widget page = switch (_view) {
      'inicio' => DashboardPage(store: widget.store, open: _open),
      'ordenes' => OrdersPage(store: widget.store),
      'clientes' => ClientsPage(store: widget.store),
      'inventario' => InventoryPage(store: widget.store),
      'pos' || 'caja' => SalesPage(store: widget.store),
      'cortes' => CashPage(store: widget.store),
      'garantias' => WarrantiesPage(store: widget.store),
      'reportes' => ReportsPage(store: widget.store),
      'usuarios' => UsersPage(store: widget.store, currentUser: widget.authUser),
      'configuracion' => SettingsPage(store: widget.store, open: _open),
      'whatsapp' => WhatsAppEventsPage(store: widget.store),
      'licencias' => const LicensePage(),
      'compras' => PurchasesPage(store: widget.store),
      'busqueda' => GlobalSearchPage(store: widget.store, open: _open, query: _globalSearchQuery),
      'notificaciones' => NotificationsPage(
        store: widget.store,
        open: _open,
        onChanged: _refreshNotificationCount,
      ),
      _ => MorePage(open: _open, role: widget.authUser.role),
    };
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: PopupMenuButton<String>(
            tooltip: 'Cuenta de usuario',
            onSelected: (value) {
              if (value == 'switch' || value == 'logout') widget.onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(widget.authUser.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'switch',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.switch_account),
                  title: Text('Cambiar de usuario'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: eShokPurpleLight.withValues(alpha: .35),
              child: const Icon(Icons.person_outline, color: eShokPurple, size: 22),
            ),
          ),
        ),
        titleSpacing: 6,
        title: SizedBox(
          height: 42,
          child: TextField(
            controller: _globalSearchController,
            textInputAction: TextInputAction.search,
            onTap: () {
              if (_view != 'busqueda') _open('busqueda');
            },
            onChanged: _onGlobalSearchChanged,
            onSubmitted: (_) => _open('busqueda'),
            decoration: InputDecoration(
              hintText: 'Buscar en el taller',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _globalSearchController.text.isEmpty ? null : IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  _globalSearchController.clear();
                  _onGlobalSearchChanged('');
                },
                icon: const Icon(Icons.close, size: 18),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: eShokBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: eShokBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: eShokPurple, width: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          FutureBuilder<int>(
            future: _notificationCountFuture,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: count > 0 ? '$count notificaciones pendientes' : 'Notificaciones',
                onPressed: () => _open('notificaciones'),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_outlined, color: eShokPurple),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNav,
        onDestinationSelected: (index) => _open(switch (index) {
          0 => 'inicio', 1 => 'ordenes', 2 => 'clientes', 3 => 'caja', _ => 'mas',
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Órdenes'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Caja'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Más'),
        ],
      ),
    );
  }
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
            const SizedBox(width: 112, height: 82, child: BrandLogo(fit: BoxFit.contain)),
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

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.open, required this.role});
  final ValueChanged<String> open;
  final String role;

  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(children: [
    const SectionHeading('Más módulos', subtitle: 'Herramientas de uso ocasional y administración'),
    const SizedBox(height: 14),
    GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.28,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        if (AuthService.can(role, 'cash.view'))
          _moduleTile(context, 'Cortes de caja', 'Movimientos, efectivo y arqueos', Icons.lock_clock_outlined, 'cortes', open),
        if (AuthService.can(role, 'inventory.view'))
          _moduleTile(context, 'Inventario', 'Productos y existencias', Icons.inventory_2_outlined, 'inventario', open),
        if (AuthService.can(role, 'purchases.view'))
          _moduleTile(context, 'Compras y proveedores', 'Entradas y cuentas por pagar', Icons.local_shipping_outlined, 'compras', open),
        if (AuthService.can(role, 'warranties.view'))
          _moduleTile(context, 'Garantías', 'Vigencia y expedientes', Icons.verified_user_outlined, 'garantias', open),
        if (AuthService.can(role, 'reports.view'))
          _moduleTile(context, 'Reportes', 'Resumen del negocio', Icons.query_stats_outlined, 'reportes', open),
        if (AuthService.can(role, 'settings.view'))
          _moduleTile(context, 'Configuración', 'Taller, usuarios y sistema', Icons.tune_outlined, 'configuracion', open),
      ],
    ),
    const SizedBox(height: 15),
    GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Estado de esta beta', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      _statusLine(Icons.check_circle, 'Datos locales SQLite', 'Activo'),
      _statusLine(Icons.check_circle, 'Clientes, órdenes e inventario', 'Operativos'),
      _statusLine(Icons.check_circle, 'POS, caja, garantías y reportes', 'Operación local'),
      _statusLine(Icons.pending_outlined, 'Servidor propio de sincronización', 'Pendiente'),
      _statusLine(Icons.pending_outlined, 'Servidor de licencias', 'Pendiente'),
      _statusLine(Icons.pending_outlined, 'WhatsApp Cloud API', 'Pendiente de configuración'),
    ])),
  ]));
}
Widget _moduleTile(BuildContext context, String title, String sub, IconData icon, String view, ValueChanged<String> open) => InkWell(
  onTap: () => open(view),
  borderRadius: BorderRadius.circular(18),
  child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: eShokPurpleLight.withValues(alpha: .3), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: eShokPurple)),
    const Spacer(),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    const SizedBox(height: 3),
    Text(sub, style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296))),
  ])),
);
Widget _statusLine(IconData icon, String title, String state) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Row(children: [
    Icon(icon, size: 16, color: icon == Icons.check_circle ? const Color(0xFF29966F) : const Color(0xFFB88945)),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
    Text(state, style: const TextStyle(fontSize: 9, color: Color(0xFF8B8296))),
  ]),
);


