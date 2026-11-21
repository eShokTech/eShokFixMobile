part of '../app.dart';

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
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => SaleDetailDialog(store: widget.store, sale: sale),
    );
    if (updated == true && mounted) setState(_refresh);
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
  _SaleLineDraft()
      : itemId = null,
        description = TextEditingController(),
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
  bool splitPayment = false;
  final splitAmount = TextEditingController(text: '0');
  String secondPaymentMethod = 'TARJETA';

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
    splitAmount.dispose();
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
    final discountValue = double.tryParse(discount.text.trim().replaceAll(',', '.')) ?? 0;
    final totalToCollect = PurchaseAccounting.total(_subtotal, discountValue);
    List<Map<String, Object?>>? breakdown;
    if (splitPayment) {
      final second = _value(splitAmount);
      final first = FinancialRules.money(totalToCollect - second);
      if (second <= 0 || first <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ambos medios de pago deben tener un importe mayor a cero y sumar el total.'),
        ));
        return;
      }
      breakdown = [
        {'method': method, 'amount': first},
        {'method': secondPaymentMethod, 'amount': second},
      ];
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
        paymentBreakdown: breakdown,
        discount: discountValue,
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dividir el pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: const Text('Permite cobrar una parte en cada medio', style: TextStyle(fontSize: 10)),
          value: splitPayment,
          onChanged: (value) => setState(() {
            splitPayment = value;
            if (value) splitAmount.text = (total / 2).toStringAsFixed(2);
          }),
        ),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'Primer medio de pago'),
          items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
            .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (value) => setState(() => method = value ?? method),
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
              onChanged: (value) => setState(() => secondPaymentMethod = value ?? secondPaymentMethod),
            )),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Primer pago: ${_money(total - (double.tryParse(splitAmount.text.replaceAll(',', '.')) ?? 0))}',
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
  late Future<List<Map<String, Object?>>> _payments;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.store.saleItems(widget.sale['id'] as int);
    _payments = widget.store.salePayments(widget.sale['id'] as int);
  }

  Future<void> _returnLine(Map<String, Object?> line) async {
    final remaining = FinancialRules.remainingQuantity(
      _num(line['quantity']), _num(line['returned_quantity']),
    );
    if (remaining <= 0) return;
    final qty = TextEditingController(text: remaining.toStringAsFixed(2));
    final reason = TextEditingController();
    String method = 'EFECTIVO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Devolver partida'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_str(line['description'])),
          const SizedBox(height: 8),
          TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Cantidad por devolver (máximo ${remaining.toStringAsFixed(2)})')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Medio de reembolso'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialog(() => method = v ?? method),
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
    if (confirmed != true) return;
    try {
      await widget.store.returnSaleItem(
        saleId: widget.sale['id'] as int,
        saleItemId: line['id'] as int,
        quantity: double.parse(qty.text.trim().replaceAll(',', '.')),
        refundMethod: method,
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

  Future<void> _cancelSale() async {
    final reason = TextEditingController();
    String method = 'EFECTIVO';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Cancelar y reembolsar venta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Se devolverán las existencias pendientes y se registrará la salida del reembolso en caja. Esta operación no se puede deshacer.'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Medio de reembolso'),
            items: const ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO']
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialog(() => method = v ?? method),
          ),
          const SizedBox(height: 8),
          TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo obligatorio')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Conservar venta')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB65E69)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar venta'),
          ),
        ],
      )),
    );
    if (confirmed != true) { reason.dispose(); return; }
    try {
      await widget.store.cancelSale(
        widget.sale['id'] as int, refundMethod: method, reason: reason.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      reason.dispose();
    }
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
            subtitle: Text('${_num(item['quantity'])} × ${_money(item['unit_price'])} · Devuelto ${_num(item['returned_quantity'])}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_money(item['line_total']), style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Devolver partida',
                onPressed: widget.sale['status'] == 'VOID' || _num(item['returned_quantity']) >= _num(item['quantity'])
                  ? null : () => _returnLine(item),
                icon: const Icon(Icons.assignment_return_outlined, color: eShokPurple),
              ),
            ]),
          )),
          const Divider(),
          _reportLine('Subtotal', _money(widget.sale['subtotal'])),
          _reportLine('Descuento', _money(widget.sale['discount'])),
          _reportLine('Total', _money(widget.sale['total'])),
          _reportLine('Método de pago', _str(widget.sale['payment_method'])),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _payments,
            builder: (context, paymentSnap) {
              if (!paymentSnap.hasData || paymentSnap.data!.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('Desglose del cobro', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                ...paymentSnap.data!.map((payment) => _reportLine(
                  _str(payment['method']), _money(payment['amount']),
                )),
              ]);
            },
          ),
          _reportLine('Estado', _str(widget.sale['status'], 'COMPLETED')),
          _reportLine('Reembolsado', _money(widget.sale['refunded_total'])),
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
      if (widget.sale['status'] != 'VOID')
        TextButton(
          onPressed: saving ? null : _cancelSale,
          child: const Text('Cancelar y reembolsar'),
        ),
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
    ],
  );
}
