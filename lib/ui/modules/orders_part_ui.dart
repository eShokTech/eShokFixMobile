part of '../app.dart';

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
    if (loading) {
      return const AlertDialog(
      content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
    );
    }
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
            if (selected != null) {
              setState(() {
              _itemId = value;
              price.text = _num(selected!['price']).toStringAsFixed(2);
            });
            }
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
