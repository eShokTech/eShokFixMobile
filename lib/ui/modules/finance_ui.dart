part of '../app.dart';

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
class _ReportsPageState extends State<ReportsPage> { late Future<Map<String, double>> _future; @override void initState() { super.initState(); _future = widget.store.reportTotals(); } @override Widget build(BuildContext context) => PageFrame(child: FutureBuilder<Map<String, double>>(future: _future, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final r = snap.data!; return ListView(children: [const SectionHeading('Reportes', subtitle: 'Resumen acumulado de la base local'), const SizedBox(height: 14), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.18, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [MetricCard(title: 'Órdenes', value: r['orders_count']!.toStringAsFixed(0), icon: Icons.assignment_outlined), MetricCard(title: 'Ventas POS', value: r['sales_count']!.toStringAsFixed(0), icon: Icons.point_of_sale_outlined, tint: const Color(0xFF4D8CBE)), MetricCard(title: 'Valor órdenes', value: _money(r['orders_total']), icon: Icons.build_outlined), MetricCard(title: 'Pagos a órdenes', value: _money(r['orders_paid']), icon: Icons.payments_outlined, tint: const Color(0xFF29966F))]), const SizedBox(height: 12), GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Indicadores financieros', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 12), _reportLine('Ventas registradas', _money(r['sales_total'])), _reportLine('Saldo de caja desde el último corte', _money(r['cash_balance'])),
_reportLine('Saldo electrónico desde el último corte', _money(r['digital_balance'])), _reportLine('Pendiente por cobrar en servicios', _money(r['orders_total']! - r['orders_paid']!)), const SizedBox(height: 10), const Text('Este primer corte usa datos locales acumulados. Los filtros por periodo, exportación y conciliación con escritorio se incorporarán a la integración financiera.', style: TextStyle(fontSize: 10, color: Color(0xFF81778D), height: 1.4))]))]); })); }
Widget _reportLine(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF80768C)))), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: eShokInk))]));
