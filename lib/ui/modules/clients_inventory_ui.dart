part of '../app.dart';

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
  bool _can(String permission) => AuthService.can(widget.store.authenticatedUser?.role ?? '', permission);
  @override
  void dispose() { _query.dispose(); super.dispose(); }
  Future<void> _edit([Map<String, Object?>? item]) async { final result = await showDialog<int>(context: context, builder: (_) => ClientFormDialog(store: widget.store, client: item)); if (result != null && mounted) setState(_refresh); }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Clientes', subtitle: 'Expedientes, equipos y datos de contacto', trailing: _can('clients.manage') ? FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1, size: 17), label: const Text('Nuevo')) : null),
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
          if (_can('clients.manage') || _can('clients.delete')) PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _edit(c); if (v == 'delete') { try { await widget.store.deleteClient(c['id'] as int); if (mounted) setState(_refresh); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } }, itemBuilder: (_) => [if (_can('clients.manage')) const PopupMenuItem(value: 'edit', child: Text('Editar')), if (_can('clients.delete')) const PopupMenuItem(value: 'delete', child: Text('Eliminar'))]),
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
  bool _canManage() => AuthService.can(widget.store.authenticatedUser?.role ?? '', 'inventory.manage');
  @override
  void dispose() { _query.dispose(); super.dispose(); }
  Future<void> _edit([Map<String, Object?>? item]) async { final r = await showDialog<bool>(context: context, builder: (_) => InventoryFormDialog(store: widget.store, item: item)); if (r == true && mounted) setState(_refresh); }
  Future<void> _adjust(Map<String, Object?> item) async { final r = await showDialog<bool>(context: context, builder: (_) => StockDialog(store: widget.store, item: item)); if (r == true && mounted) setState(_refresh); }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Inventario', subtitle: 'Catálogo, existencias y movimientos', trailing: _canManage() ? FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 17), label: const Text('Artículo')) : null),
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
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (low) const Text('STOCK BAJO', style: TextStyle(fontSize: 8, color: Color(0xFFCA7B2C), fontWeight: FontWeight.w900)), if (_canManage()) TextButton(onPressed: () => _adjust(item), child: const Text('Movimiento', style: TextStyle(fontSize: 10))), if (_canManage()) PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(item); if (v == 'adjust') _adjust(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar artículo')), PopupMenuItem(value: 'adjust', child: Text('Ajustar stock'))])]),
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
    _field(name, 'Nombre', required: true), const SizedBox(height: 8), Row(children: [Expanded(child: _field(sku, 'SKU / código')), const SizedBox(width: 8), Expanded(child: _field(category, 'Categoría'))]), const SizedBox(height: 8), Row(children: [Expanded(child: widget.item == null ? _field(stock, 'Existencia inicial', number: true) : InputDecorator(decoration: const InputDecoration(labelText: 'Existencia actual'), child: Text(_str(widget.item?['stock'], '0')))), const SizedBox(width: 8), Expanded(child: _field(minStock, 'Mínimo', number: true))]),
    if (widget.item != null) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 4), child: Text('Para modificar existencias, registra un movimiento de inventario. Así se conserva el historial.', style: TextStyle(fontSize: 10, color: Color(0xFF81778D))))), const SizedBox(height: 8), Row(children: [Expanded(child: _field(cost, 'Costo', number: true)), const SizedBox(width: 8), Expanded(child: _field(price, 'Precio', number: true))]), const SizedBox(height: 8), _field(location, 'Ubicación'),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () async { if (!form.currentState!.validate()) return; await widget.store.saveInventoryItem(id: widget.item?['id'] as int?, sku: sku.text, name: name.text, category: category.text, stock: widget.item == null ? val(stock) : _num(widget.item?['stock']), minStock: val(minStock), cost: val(cost), price: val(price), location: location.text); if (context.mounted) Navigator.pop(context, true); }, child: const Text('Guardar'))]);
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
