part of '../app.dart';

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
  bool _can(String permission) => AuthService.can(widget.store.authenticatedUser?.role ?? '', permission);
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _newOrder() async {
    final created = await showDialog<bool>(context: context, builder: (_) => NewOrderDialog(store: widget.store));
    if (created == true && mounted) setState(_refresh);
  }
  @override
  Widget build(BuildContext context) => PageFrame(child: Column(children: [
    SectionHeading('Órdenes de servicio', subtitle: 'Recepción, diagnóstico, reparación y entrega', trailing: _can('orders.manage') ? FilledButton.tonalIcon(onPressed: _newOrder, icon: const Icon(Icons.add, size: 18), label: const Text('Nueva')) : null),
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
  bool _can(String permission) => AuthService.can(widget.store.authenticatedUser?.role ?? '', permission);
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
  String _depositMethod = 'EFECTIVO';
  bool _saving = false;
  @override
  void initState() { super.initState(); _loadClients(); }
  Future<void> _loadClients() async {
    final rows = await widget.store.clients();
    final warrantyDays = await widget.store.setting('default_warranty_days', fallback: '30');
    if (mounted) {
      setState(() {
      _clients = rows;
      _clientId ??= rows.isNotEmpty ? rows.first['id'] as int : null;
      _warranty.text = warrantyDays;
    });
    }
  }
  @override
  void dispose() { for (final c in [_brand,_model,_failure,_condition,_accessories,_technician,_imei,_serial,_labor,_parts,_discount,_deposit,_notes,_warranty]) { c.dispose(); } super.dispose(); }
  double _v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _clientId == null) return;
    setState(() => _saving = true);
    try {
      await widget.store.createOrder(clientId: _clientId!, brand: _brand.text, model: _model.text, failure: _failure.text, condition: _condition.text, accessories: _accessories.text, technician: _technician.text, labor: _v(_labor), parts: _v(_parts), discount: _v(_discount), deposit: _v(_deposit), depositMethod: _depositMethod, notes: _notes.text, imei: _imei.text, serial: _serial.text, warrantyDays: int.tryParse(_warranty.text) ?? 30);
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
      ] else DropdownButtonFormField<int>(initialValue: _clientId, decoration: const InputDecoration(labelText: 'Cliente'), items: _clients.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(_str(c['name']), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _clientId = v)),
      const SizedBox(height: 10), MediaQuery.sizeOf(context).width < 420
        ? Column(children: [_field(_brand, 'Marca', required: true), const SizedBox(height: 8), _field(_model, 'Modelo', required: true)])
        : Row(children: [Expanded(child: _field(_brand, 'Marca', required: true)), const SizedBox(width: 8), Expanded(child: _field(_model, 'Modelo', required: true))]),
      const SizedBox(height: 9), _field(_failure, 'Falla reportada', required: true, lines: 2),
      const SizedBox(height: 9), _field(_condition, 'Estado físico / observaciones', lines: 2),
      const SizedBox(height: 9), _field(_accessories, 'Accesorios recibidos'),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_imei, 'IMEI')), const SizedBox(width: 8), Expanded(child: _field(_serial, 'Serie'))]),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_labor, 'Mano de obra', number: true)), const SizedBox(width: 8), Expanded(child: _field(_parts, 'Refacciones manuales (sin inventario)', number: true))]),
      const SizedBox(height: 9), Row(children: [Expanded(child: _field(_discount, 'Descuento', number: true)), if (_can('orders.pay')) const SizedBox(width: 8), if (_can('orders.pay')) Expanded(child: _field(_deposit, 'Anticipo', number: true))]),
      if (_can('orders.pay')) ...[const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: _depositMethod, decoration: const InputDecoration(labelText: 'Medio del anticipo'), items: const ['EFECTIVO','TRANSFERENCIA','TARJETA','OTRO'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _depositMethod = v ?? _depositMethod))],
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
  bool _can(String permission) => AuthService.can(widget.store.authenticatedUser?.role ?? '', permission);
  Future<void> _cancelOrder() async {
    final reason = TextEditingController();
    String method = 'EFECTIVO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Cancelar orden'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Se reembolsará el importe neto cobrado y se registrará la salida en caja. Las refacciones ya consumidas no regresan al inventario. La acción no se puede deshacer.'),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Medio del reembolso'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialog(() => method = v ?? method),
          ),
          const SizedBox(height: 8),
          TextField(controller: reason, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Motivo obligatorio')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Conservar orden')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB65E69)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar y reembolsar'),
          ),
        ],
      )),
    );
    if (confirmed != true) { reason.dispose(); return; }
    try {
      await widget.store.cancelOrder(
        widget.orderId, refundMethod: method, reason: reason.text,
      );
      if (mounted) setState(_refresh);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      reason.dispose();
    }
  }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      }
    }
  }

  Future<void> _payment(double balance) async {
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final secondAmount = TextEditingController(text: (balance / 2).toStringAsFixed(2));
    final ref = TextEditingController();
    String method = 'EFECTIVO';
    String secondMethod = 'TARJETA';
    bool split = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Registrar pago'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importe del pago'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Primer medio de pago'),
              items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setD(() => method = v ?? method),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dividir este pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              subtitle: const Text('Registrar dos medios de pago en el mismo abono', style: TextStyle(fontSize: 10)),
              value: split,
              onChanged: (value) => setD(() {
                split = value;
                if (value) {
                  final total = double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;
                  secondAmount.text = (total / 2).toStringAsFixed(2);
                }
              }),
            ),
            if (split) ...[
              TextField(
                controller: secondAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe del segundo medio'),
                onChanged: (_) => setD(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: secondMethod,
                decoration: const InputDecoration(labelText: 'Segundo medio de pago'),
                items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setD(() => secondMethod = v ?? secondMethod),
              ),
              Builder(builder: (context) {
                final total = double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;
                final second = double.tryParse(secondAmount.text.trim().replaceAll(',', '.')) ?? 0;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Primer medio: ${(total - second).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF81778D)),
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: ref,
              decoration: const InputDecoration(labelText: 'Referencia / nota'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final paymentAmount = double.parse(amount.text.trim().replaceAll(',', '.'));
        List<Map<String, Object?>>? breakdown;
        if (split) {
          final second = double.parse(secondAmount.text.trim().replaceAll(',', '.'));
          final first = paymentAmount - second;
          if (!first.isFinite || !second.isFinite || first <= 0 || second <= 0) {
            throw ArgumentError('Ambos medios deben tener un importe mayor a cero y sumar el abono.');
          }
          breakdown = [
            {'method': method, 'amount': first},
            {'method': secondMethod, 'amount': second},
          ];
        }
        await widget.store.addOrderPayment(
          widget.orderId,
          paymentAmount,
          method,
          reference: ref.text,
          paymentBreakdown: breakdown,
        );
        if (mounted) setState(_refresh);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
        }
      }
    }
    amount.dispose();
    secondAmount.dispose();
    ref.dispose();
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
      pw.Center(child: pw.Text(shopName, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text('Comprobante de servicio', style: const pw.TextStyle(fontSize: 9))), pw.SizedBox(height: 10), pw.Divider(),
      pw.Text('Folio: ${o['folio']}'), pw.Text('Cliente: ${o['client_name']}'), pw.Text('Equipo: ${_str(o['brand'])} ${_str(o['model'])}'),
      pw.Text('IMEI/Serie: ${_str(o['imei']).isEmpty ? _str(o['serial'], 'No registrado') : _str(o['imei'])}'),
      pw.Text('Falla reportada: ${o['failure_description']}'), pw.Text('Diagnóstico: ${_str(o['diagnosis'], 'Pendiente')}'),
      pw.Divider(), pw.Text('Mano de obra: ${_money(o['labor'])}'), pw.Text('Refacciones: ${_money(o['parts_total'])}'),
      pw.Text('Descuento: ${_money(o['discount'])}'), pw.Text('TOTAL: ${_money(o['total'])}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
        const SectionHeading('Flujo de trabajo', subtitle: 'Las transiciones no válidas se bloquean'),
        const SizedBox(height: 8),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_can('orders.manage')) Wrap(spacing: 7, runSpacing: 7, children: OrderWorkflow.transitions[status]!.where((next) => next != 'CANCELADO').map((next) {
            final authorizationPending = _str(o['authorization_status'], 'PENDING') != 'APPROVED';
            final needsAuthorization = next == 'ESPERA_REFACCION' || next == 'REPARACION';
            return ActionChip(
              label: Text(OrderWorkflow.label(next)),
              avatar: const Icon(Icons.arrow_forward, size: 15),
              onPressed: needsAuthorization && authorizationPending ? null : () => _status(next),
              backgroundColor: eShokPurpleLight.withValues(alpha: .28),
            );
          }).toList()),
          if (status == 'ESPERA_AUTORIZACION' && _can('orders.authorize')) ...[
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
          if (_can('orders.cancel') && status != 'ENTREGADO' && status != 'CANCELADO')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFB65E69)),
                label: const Text('Cancelar orden y registrar reembolso'),
              ),
            ),
          const SizedBox(height: 8),
          if (_can('orders.manage')) OutlinedButton.icon(onPressed: () => _diagnosis(_str(o['diagnosis']), _str(o['notes'])), icon: const Icon(Icons.edit_note), label: const Text('Editar diagnóstico y notas')),
        ])),
        const SizedBox(height: 12),
        const SectionHeading('Información del equipo'),
        const SizedBox(height: 8),
        GlassCard(child: Column(children: [
          _detail('Falla reportada', _str(o['failure_description'])), _detail('Diagnóstico', _str(o['diagnosis'], 'Pendiente')), _detail('IMEI', _str(o['imei'], 'No registrado')), _detail('Serie', _str(o['serial'], 'No registrada')), _detail('Color', _str(o['color'], 'No registrado')), _detail('Accesorios', _str(o['accessories'], 'No registrados')), _detail('Estado físico', _str(o['condition_note'], 'No registrado')), _detail('Técnico', _str(o['technician'], 'Sin asignar')),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: SectionHeading('Refacciones y materiales')),
          if (_can('orders.manage')) FilledButton.tonalIcon(
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
            if (rows.isEmpty) {
              return const EmptyState(
              title: 'Sin refacciones asignadas',
              message: 'Las piezas agregadas aquí descuentan existencias y se suman al total de la orden.',
            );
            }
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
        const SectionHeading('Cobros y garantía'),
        const SizedBox(height: 8),
        GlassCard(child: Column(children: [
          _detail('Mano de obra', _money(o['labor'])), _detail('Refacciones', _money(o['parts_total'])), _detail('Descuento', _money(o['discount'])), _detail('Total', _money(o['total'])), _detail('Pagado', _money(o['paid'])),
          Row(children: [const Expanded(child: Text('Saldo pendiente', style: TextStyle(fontWeight: FontWeight.w800))), Text(_money(balance), style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? const Color(0xFFBA6D2B) : const Color(0xFF258A62)))]),
          const SizedBox(height: 10), Row(children: [if (_can('orders.pay')) Expanded(child: FilledButton.icon(onPressed: balance > 0 ? () => _payment(balance) : null, icon: const Icon(Icons.payments_outlined), label: const Text('Registrar pago'))), if (_can('orders.pay')) const SizedBox(width: 8), IconButton.filledTonal(onPressed: () => _printTicket(o), icon: const Icon(Icons.print_outlined), tooltip: 'Imprimir / PDF')]),
          Align(alignment: Alignment.centerLeft, child: Text('Garantía al entregar: ${o['warranty_days']} días', style: const TextStyle(fontSize: 10, color: Color(0xFF867C91)))),
        ])),
        const SizedBox(height: 12),
        const SectionHeading('Historial de pagos y reembolsos'),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, Object?>>>(
          future: widget.store.orderPayments(widget.orderId),
          builder: (context, paymentSnap) {
            if (!paymentSnap.hasData) return const LinearProgressIndicator();
            final rows = paymentSnap.data!;
            if (rows.isEmpty) {
              return const EmptyState(
              title: 'Sin pagos registrados',
              message: 'Los anticipos y abonos aparecerán en este historial.',
            );
            }
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
        const SizedBox(height: 7),
        FutureBuilder<List<Map<String, Object?>>>(
          future: widget.store.orderRefunds(widget.orderId),
          builder: (context, refundSnap) {
            if (!refundSnap.hasData || refundSnap.data!.isEmpty) return const SizedBox.shrink();
            return GlassCard(child: Column(children: refundSnap.data!.map((refund) => ListTile(
              dense: true,
              leading: const Icon(Icons.assignment_return_outlined, color: Color(0xFFB65E69)),
              title: Text('Reembolso ${_money(refund['amount'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_str(refund['method'])} · ${_date(refund['created_at'])}\n${_str(refund['reason'])}'),
              isThreeLine: true,
            )).toList()));
          },
        ),
        const SizedBox(height: 12),
        Row(children: [const Expanded(child: SectionHeading('Evidencias')), if (_can('orders.manage')) FilledButton.tonalIcon(onPressed: _evidence, icon: const Icon(Icons.add_a_photo_outlined, size: 17), label: const Text('Tomar foto'))]),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, Object?>>>(future: widget.store.orderEvidence(widget.orderId), builder: (context, evidenceSnap) {
          final rows = evidenceSnap.data ?? [];
          if (rows.isEmpty) return const EmptyState(title: 'Sin evidencias', message: 'Las fotografías que tomes quedarán asociadas a este expediente.');
          return Column(children: rows.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassCard(child: Row(children: [
            SizedBox(width: 72, height: 72, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_str(e['file_path'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF0ECF6), child: Icon(Icons.broken_image_outlined, color: eShokPurple))))),
            const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_str(e['caption'], 'Evidencia'), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(_date(e['created_at']), style: const TextStyle(fontSize: 10, color: Color(0xFF8A8095)))])),
          ])))).toList());
        }),
        const SizedBox(height: 12),
        const SectionHeading('Historial del expediente'), const SizedBox(height: 8),
        FutureBuilder<List<Map<String, Object?>>>(future: widget.store.orderEvents(widget.orderId), builder: (context, eventSnap) => Column(children: (eventSnap.data ?? []).map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.radio_button_checked, color: eShokPurple, size: 18), title: Text(_str(e['description']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: Text('${_date(e['created_at'])}  ·  ${_str(e['from_status'])} → ${_str(e['to_status'])}', style: const TextStyle(fontSize: 9)))).toList())),
        const SizedBox(height: 25),
      ]);
    }),
  );
  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8B8296)))), Expanded(child: Text(value.isEmpty ? 'No registrado' : value, style: const TextStyle(fontSize: 11, color: eShokInk, fontWeight: FontWeight.w700)))]));
}
