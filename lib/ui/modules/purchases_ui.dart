part of '../app.dart';

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
                        subtitle: Text('${_str(row['supplier_name'])} · ${_date(row['created_at'])}\n${_str(row['status'])} · ${_str(row['payment_status'])} · Saldo ${_money(balance)}'),
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
  bool splitPayment = false;
  bool receiveImmediately = true;
  final splitAmount = TextEditingController(text: '0');
  String secondPaymentMethod = 'TARJETA';

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
    splitAmount.dispose();
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
    final paidValue = _value(paid);
    List<Map<String, Object?>>? breakdown;
    if (splitPayment && paidValue > 0) {
      final second = _value(splitAmount);
      final first = FinancialRules.money(paidValue - second);
      if (second <= 0 || first <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ambos medios de pago deben tener un importe mayor a cero y sumar el pago inicial.'),
        ));
        return;
      }
      breakdown = [
        {'method': paymentMethod, 'amount': first},
        {'method': secondPaymentMethod, 'amount': second},
      ];
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
        paid: paidValue,
        paymentMethod: paymentMethod,
        paymentBreakdown: breakdown,
        receiveImmediately: receiveImmediately,
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recibir mercancía ahora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: const Text('Desactivado: se registra como pedido y no aumenta inventario todavía.', style: TextStyle(fontSize: 10)),
          value: receiveImmediately,
          onChanged: (value) => setState(() => receiveImmediately = value),
        ),
        Row(children: [
          const Expanded(child: Text('Artículos del pedido', style: TextStyle(fontWeight: FontWeight.w800))),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dividir el pago inicial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: const Text('Usa dos medios para pagar al proveedor', style: TextStyle(fontSize: 10)),
          value: splitPayment,
          onChanged: (value) => setState(() {
            splitPayment = value;
            if (value) splitAmount.text = (double.tryParse(paid.text.replaceAll(',', '.')) ?? 0) / 2 == 0
              ? '0' : ((double.tryParse(paid.text.replaceAll(',', '.')) ?? 0) / 2).toStringAsFixed(2);
          }),
        ),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          decoration: const InputDecoration(labelText: 'Primer medio de pago'),
          items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => paymentMethod = v ?? paymentMethod),
        ),
        if (splitPayment) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(splitAmount, 'Importe segundo pago', number: true)),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: secondPaymentMethod,
              decoration: const InputDecoration(labelText: 'Segundo medio'),
              items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => secondPaymentMethod = v ?? secondPaymentMethod),
            )),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Primer pago: ${_money((double.tryParse(paid.text.replaceAll(',', '.')) ?? 0) - (double.tryParse(splitAmount.text.replaceAll(',', '.')) ?? 0))}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))),
          ),
        ],
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
  final secondAmount = TextEditingController();
  String secondMethod = 'TARJETA';
  bool splitPayment = false;
  Future<void> _receiveLine(Map<String, Object?> line) async {
    final pending = FinancialRules.remainingQuantity(
      _num(line['quantity']), _num(line['received_quantity']),
    );
    if (pending <= 0) return;
    final quantity = TextEditingController(text: pending.toStringAsFixed(2));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar recepción'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_str(line['description'])),
          const SizedBox(height: 8),
          Text('Pendiente: ${pending.toStringAsFixed(2)}'),
          TextField(controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad recibida')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (confirmed != true) { quantity.dispose(); return; }
    try {
      await widget.store.receivePurchaseItem(
        widget.purchase['id'] as int,
        line['id'] as int,
        double.parse(quantity.text.trim().replaceAll(',', '.')),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      quantity.dispose();
    }
  }
  String method = 'EFECTIVO';
  bool saving = false;
  late Future<List<Map<String, Object?>>> _items;
  late Future<List<Map<String, Object?>>> _payments;

  Future<void> _returnLine(Map<String, Object?> line) async {
    final remaining = FinancialRules.remainingQuantity(
      _num(line['received_quantity']), _num(line['returned_quantity']),
    );
    if (remaining <= 0) return;
    final qty = TextEditingController(text: remaining.toStringAsFixed(2));
    final reason = TextEditingController();
    String refundMethod = 'EFECTIVO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Devolver al proveedor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_str(line['description'])),
          const SizedBox(height: 8),
          TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Cantidad (máximo ${remaining.toStringAsFixed(2)})')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: refundMethod,
            decoration: const InputDecoration(labelText: 'Medio de reembolso (si hay saldo a favor)'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialog(() => refundMethod = v ?? refundMethod),
          ),
          const SizedBox(height: 8),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivo')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar devolución')),
        ],
      )),
    );
    if (confirmed != true) { qty.dispose(); reason.dispose(); return; }
    try {
      await widget.store.returnPurchaseItem(
        purchaseId: widget.purchase['id'] as int,
        purchaseItemId: line['id'] as int,
        quantity: double.parse(qty.text.trim().replaceAll(',', '.')),
        refundMethod: refundMethod,
        reason: reason.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      qty.dispose();
      reason.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _items = widget.store.purchaseItems(widget.purchase['id'] as int);
    _payments = widget.store.purchasePayments(widget.purchase['id'] as int);
  }

  @override
  void dispose() {
    amount.dispose();
    secondAmount.dispose();
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
              subtitle: Text('Pedido ${_num(line['quantity'])} · Recibido ${_num(line['received_quantity'])} · Devuelto ${_num(line['returned_quantity'])}'),
              trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_money(line['line_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
                if (_num(line['received_quantity']) < _num(line['quantity']))
                  IconButton(
                    tooltip: 'Registrar recepción',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _receiveLine(line),
                    icon: const Icon(Icons.move_to_inbox_outlined, color: eShokPurple),
                  ),
                IconButton(
                  tooltip: 'Devolver al proveedor',
                  visualDensity: VisualDensity.compact,
                  onPressed: _num(line['returned_quantity']) >= _num(line['received_quantity']) ? null : () => _returnLine(line),
                  icon: const Icon(Icons.assignment_return_outlined, color: eShokPurple),
                ),
              ]),
            )).toList());
          },
        ),
        const Divider(),
        _reportLine('Subtotal', _money(widget.purchase['subtotal'])),
        _reportLine('Descuento', _money(widget.purchase['discount'])),
        _reportLine('Total', _money(total)),
        _reportLine('Pagado', _money(paid)),
        _reportLine('Saldo', _money(balance)),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _payments,
          builder: (context, paymentSnap) {
            if (!paymentSnap.hasData || paymentSnap.data!.isEmpty) return const SizedBox.shrink();
            return Column(children: [
              const SizedBox(height: 6),
              const Align(alignment: Alignment.centerLeft, child: Text('Historial de pagos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
              ...paymentSnap.data!.map((payment) => _reportLine(
                '${_str(payment['method'])} · ${_date(payment['created_at'])}',
                _money(payment['amount']),
              )),
            ]);
          },
        ),
        if (balance > 0.01) ...[
          const Divider(),
          const Text('Registrar abono', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Importe', hintText: balance.toStringAsFixed(2))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Primer medio'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => method = v ?? method),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dividir este abono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Registrar dos medios de pago', style: TextStyle(fontSize: 10)),
            value: splitPayment,
            onChanged: (value) => setState(() {
              splitPayment = value;
              if (value) {
                final total = double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;
                secondAmount.text = (total / 2).toStringAsFixed(2);
              }
            }),
          ),
          if (splitPayment) ...[
            TextField(
              controller: secondAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importe segundo medio'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: secondMethod,
              decoration: const InputDecoration(labelText: 'Segundo medio'),
              items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => secondMethod = v ?? secondMethod),
            ),
          ],
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
              List<Map<String, Object?>>? breakdown;
              if (splitPayment) {
                final second = double.tryParse(secondAmount.text.trim().replaceAll(',', '.'));
                if (second == null || !second.isFinite || second <= 0 ||
                    value - second <= 0) {
                  throw ArgumentError('Ambos medios deben tener importes mayores a cero y sumar el abono.');
                }
                breakdown = [
                  {'method': method, 'amount': FinancialRules.money(value - second)},
                  {'method': secondMethod, 'amount': FinancialRules.money(second)},
                ];
              }
              await widget.store.recordPurchasePayment(
                widget.purchase['id'] as int,
                value,
                method,
                paymentBreakdown: breakdown,
              );
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
