part of '../app.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.store});
  final LocalStore store;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late Future<List<Map<String, Object?>>> _sales;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _sales = widget.store.sales();

  Future<void> _newSale() async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SaleCartPage(store: widget.store)),
    );
    if (completed == true && mounted) setState(_refresh);
  }

  Future<void> _priceChecker() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    try {
      final item = await widget.store.inventoryItemByCode(code);
      if (!mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No existe un producto con el código $code.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checador de precios'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _str(item['name']),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                _money(item['price']),
                style: const TextStyle(
                  fontSize: 32,
                  color: eShokPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo consultar el producto: $error')),
        );
      }
    }
  }

  Future<void> _openSale(Map<String, Object?> sale) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => SaleDetailDialog(store: widget.store, sale: sale),
    );
    if (updated == true && mounted) setState(_refresh);
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(15),
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFFF0E8FA), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: eShokPurpleLight.withValues(alpha: .30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: eShokPurple, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: eShokInk)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9B91A5)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    child: ListView(
      children: [
        const SectionHeading(
          'Punto de venta',
          subtitle: 'Ventas rápidas y herramientas de mostrador',
        ),
        const SizedBox(height: 12),
        _actionCard(
          title: 'Nueva venta',
          subtitle: 'Buscar productos, escanear y cobrar',
          icon: Icons.point_of_sale_outlined,
          onTap: _newSale,
          primary: true,
        ),
        const SizedBox(height: 9),
        _actionCard(
          title: 'Checador de precios',
          subtitle: 'Escanea el código y consulta nombre y precio',
          icon: Icons.price_check_outlined,
          onTap: _priceChecker,
        ),
        const SizedBox(height: 17),
        const SectionHeading('Ventas recientes', subtitle: 'Tickets y operaciones registradas'),
        const SizedBox(height: 7),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _sales,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EmptyState(
                title: 'No se pudo cargar el historial',
                message: '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return const EmptyState(
                title: 'Todavía no hay ventas',
                message: 'Las ventas que registres aparecerán aquí.',
              );
            }
            return Column(
              children: rows.map((sale) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassCard(
                  child: ListTile(
                    onTap: () => _openSale(sale),
                    leading: const Icon(Icons.receipt_long_outlined, color: eShokPurple),
                    title: Text(_str(sale['folio']),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${_date(sale['created_at'])} · ${_str(sale['client_name'], 'Venta general')}',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF8A8095)),
                    ),
                    trailing: Text(
                      _money(sale['total']),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _SaleCartLine {
  _SaleCartLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.itemId,
  });

  final int? itemId;
  final String description;
  double quantity;
  final double unitPrice;

  double get total => FinancialRules.money(quantity * unitPrice);

  Map<String, Object?> toMap() => {
    'item_id': itemId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

class SaleCartPage extends StatefulWidget {
  const SaleCartPage({super.key, required this.store});
  final LocalStore store;

  @override
  State<SaleCartPage> createState() => _SaleCartPageState();
}

class _SaleCartPageState extends State<SaleCartPage> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _discount = TextEditingController(text: '0');
  List<Map<String, Object?>> _products = [];
  List<Map<String, Object?>> _clients = [];
  final List<_SaleCartLine> _cart = [];
  int? _clientId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.store.inventory(),
        widget.store.clients(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = values[0]
            .where((item) => (item['is_demo'] as num?)?.toInt() != 1)
            .toList();
        _clients = values[1]
            .where((client) => (client['is_demo'] as num?)?.toInt() != 1)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el catálogo: $error')),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _discount.dispose();
    super.dispose();
  }

  String get _normalizedQuery => _search.text.trim().toLowerCase();

  List<Map<String, Object?>> get _filteredProducts {
    final query = _normalizedQuery;
    if (query.isEmpty) return const [];
    return _products.where((item) {
      final name = _str(item['name']).toLowerCase();
      final sku = _str(item['sku']).toLowerCase();
      final barcode = _str(item['barcode']).toLowerCase();
      return name.contains(query) || sku.contains(query) || barcode.contains(query);
    }).take(30).toList();
  }

  double get _subtotal => FinancialRules.money(
    _cart.fold<double>(0, (sum, line) => sum + line.total),
  );

  double get _discountValue =>
      double.tryParse(_discount.text.trim().replaceAll(',', '.')) ?? 0;

  double get _total => PurchaseAccounting.total(_subtotal, _discountValue);

  void _addProduct(Map<String, Object?> product) {
    final id = product['id'] as int;
    final index = _cart.indexWhere((line) => line.itemId == id);
    setState(() {
      if (index >= 0) {
        _cart[index].quantity += 1;
      } else {
        _cart.add(_SaleCartLine(
          itemId: id,
          description: _str(product['name']),
          quantity: 1,
          unitPrice: _num(product['price']),
        ));
      }
    });
    _search.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _scanAndAdd() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final product = await widget.store.inventoryItemByCode(code);
      if (!mounted) return;
      if (product == null || (product['is_demo'] as num?)?.toInt() == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se encontró un producto real con el código $code.')),
        );
        return;
      }
      _addProduct(product);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo leer el producto: $error')),
        );
      }
    }
  }

  Future<void> _addService() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Descripción del servicio'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
      if (description.text.trim().isEmpty || value == null || !value.isFinite || value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica una descripción y un precio válido.')),
        );
      } else {
        setState(() {
          _cart.add(_SaleCartLine(
            description: description.text.trim(),
            quantity: 1,
            unitPrice: value,
          ));
        });
      }
    }
    description.dispose();
    amount.dispose();
  }

  Future<void> _continueToPayment() async {
    if (_cart.isEmpty) return;
    if (!_discountValue.isFinite || _discountValue < 0 || _discountValue > _subtotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El descuento no puede ser mayor que el subtotal.')),
      );
      return;
    }
    final receipt = await Navigator.push<_SaleReceipt>(
      context,
      MaterialPageRoute(
        builder: (_) => SaleCheckoutPage(
          store: widget.store,
          items: _cart.map((line) => line.toMap()).toList(),
          clientId: _clientId,
          discount: _discountValue,
          total: _total,
        ),
      ),
    );
    if (receipt == null || !mounted) return;
    setState(() {
      _cart.clear();
      _clientId = null;
      _discount.text = '0';
      _search.clear();
    });
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _SaleSuccessPage(receipt: receipt)),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final products = _filteredProducts;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Venta general / mostrador'),
                      ),
                      ..._clients.map((client) => DropdownMenuItem<int?>(
                        value: client['id'] as int,
                        child: Text(_str(client['name']), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (value) => setState(() => _clientId = value),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar producto, SKU o código',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar',
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 52,
                        child: FilledButton.tonalIcon(
                          onPressed: _scanAndAdd,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_search.text.trim().isNotEmpty)
              SizedBox(
                height: 190,
                child: products.isEmpty
                    ? const Center(
                        child: Text('No hay productos que coincidan con esa búsqueda.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _addProduct(product),
                            title: Text(_str(product['name']),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              '${_str(product['sku'], 'Sin SKU')} · ${_num(product['stock']).toStringAsFixed(0)} disponibles',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF81778D)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_money(product['price']),
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(width: 5),
                                const Icon(Icons.add_circle, color: eShokPurple),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _cart.isEmpty
                  ? const EmptyState(
                      title: 'Carrito vacío',
                      message: 'Busca un artículo, escanea su código o agrega un servicio.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Productos de la venta',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                            TextButton.icon(
                              onPressed: _addService,
                              icon: const Icon(Icons.add, size: 17),
                              label: const Text('Servicio'),
                            ),
                          ],
                        ),
                        ..._cart.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(line.description,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 3),
                                        Text('${_money(line.unitPrice)} c/u · ${_money(line.total)}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF81778D))),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Disminuir cantidad',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() {
                                      if (line.quantity > 1) {
                                        line.quantity -= 1;
                                      } else {
                                        _cart.removeAt(index);
                                      }
                                    }),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(line.quantity.toStringAsFixed(0),
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                  IconButton(
                                    tooltip: 'Aumentar cantidad',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => line.quantity += 1),
                                    icon: const Icon(Icons.add_circle_outline, color: eShokPurple),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _discount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Descuento global',
                            prefixText: r'$ ',
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: eShokBorder)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Total de la venta',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      Text(_money(_total),
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: eShokPurple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _cart.isEmpty ? null : _continueToPayment,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continuar al cobro'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleReceipt {
  const _SaleReceipt({
    required this.saleId,
    required this.folio,
    required this.total,
    required this.change,
    required this.paymentSummary,
    required this.cashPayment,
  });

  final int saleId;
  final String folio;
  final double total;
  final double change;
  final String paymentSummary;
  final bool cashPayment;
}

class SaleCheckoutPage extends StatefulWidget {
  const SaleCheckoutPage({
    super.key,
    required this.store,
    required this.items,
    required this.clientId,
    required this.discount,
    required this.total,
  });

  final LocalStore store;
  final List<Map<String, Object?>> items;
  final int? clientId;
  final double discount;
  final double total;

  @override
  State<SaleCheckoutPage> createState() => _SaleCheckoutPageState();
}

class _SaleCheckoutPageState extends State<SaleCheckoutPage> {
  final TextEditingController _received = TextEditingController();
  final TextEditingController _exchangeRate = TextEditingController();
  final TextEditingController _transferReference = TextEditingController();
  String _method = 'EFECTIVO';
  String _cashCurrency = 'MXN';
  bool _saveRateAsDefault = false;
  bool _acceptUsdCash = false;
  bool _saving = false;
  String _defaultRate = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultRate();
  }

  Future<void> _loadDefaultRate() async {
    try {
      final values = await Future.wait([
        widget.store.setting('pos.usd_exchange_rate'),
        widget.store.setting('pos.accept_usd_cash', fallback: '0'),
      ]);
      if (!mounted) return;
      setState(() {
        _defaultRate = values[0];
        _acceptUsdCash = values[1] == '1';
        if (_defaultRate.isNotEmpty) _exchangeRate.text = _defaultRate;
        if (!_acceptUsdCash) _cashCurrency = 'MXN';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _acceptUsdCash = false;
        _cashCurrency = 'MXN';
      });
    }
  }

  @override
  void dispose() {
    _received.dispose();
    _exchangeRate.dispose();
    _transferReference.dispose();
    super.dispose();
  }

  double _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  double get _rate => _number(_exchangeRate.text);
  double get _receivedAmount => _number(_received.text);
  double get _receivedInPesos {
    if (_isUsdCash && _rate <= 0) return 0;
    return PosCheckoutRules.receivedInMxn(
      amount: _receivedAmount,
      currency: _isCash ? _cashCurrency : 'MXN',
      exchangeRate: _isUsdCash ? _rate : 1,
    );
  }

  double get _change => PosCheckoutRules.changeDue(
    saleTotal: widget.total,
    receivedInMxn: _receivedInPesos,
  );
  bool get _isCash => _method == 'EFECTIVO';
  bool get _isUsdCash => _isCash && _cashCurrency == 'USD';
  bool get _canSaveRate => AuthService.can(
    widget.store.authenticatedUser?.role ?? '',
    'settings.manage',
  );

  String get _paymentSummary {
    if (_isUsdCash) {
      return 'Efectivo USD · TC ${_rate.toStringAsFixed(2)}';
    }
    return switch (_method) {
      'EFECTIVO' => 'Efectivo MXN',
      'TRANSFERENCIA' => 'Transferencia',
      'TARJETA' => 'Tarjeta',
      _ => _method,
    };
  }

  Future<void> _complete({required bool printTicket}) async {
    if (_saving) return;
    if (_isCash) {
      if (_isUsdCash && (!_rate.isFinite || _rate <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica un tipo de cambio válido para recibir dólares.')),
        );
        return;
      }
      if (_receivedAmount <= 0 || !PosCheckoutRules.isSufficient(saleTotal: widget.total, receivedInMxn: _receivedInPesos)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El efectivo recibido no cubre el total de la venta.')),
        );
        return;
      }
    }
    if (_method == 'TRANSFERENCIA' && _transferReference.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica la referencia de la transferencia.')),
      );
      return;
    }

    setState(() => _saving = true);
    final dbMethod = _method;
    String reference = '';
    String note = '';
    if (_isUsdCash) {
      reference = 'USD ${_receivedAmount.toStringAsFixed(2)} · TC ${_rate.toStringAsFixed(2)}';
      note = 'Recibido USD ${_receivedAmount.toStringAsFixed(2)} · Tipo de cambio ${_rate.toStringAsFixed(2)} · Recibido equivalente ${_money(_receivedInPesos)} · Cambio ${_money(_change)}';
    } else if (_isCash) {
      reference = 'Efectivo recibido ${_money(_receivedAmount)} · Cambio ${_money(_change)}';
      note = reference;
    } else if (_method == 'TRANSFERENCIA') {
      reference = _transferReference.text.trim();
      note = 'Referencia de transferencia: ${_transferReference.text.trim()}';
    }

    try {
      if (_isUsdCash && _saveRateAsDefault && _canSaveRate) {
        await widget.store.saveSetting(
          'pos.usd_exchange_rate',
          _rate.toStringAsFixed(4),
        );
      }
      final saleId = await widget.store.createSaleCart(
        clientId: widget.clientId,
        items: widget.items,
        paymentMethod: dbMethod,
        paymentBreakdown: [
          {'method': dbMethod, 'amount': widget.total},
        ],
        discount: widget.discount,
        notes: note,
        paymentReference: reference,
      );

      final sales = await widget.store.sales();
      final sale = sales.firstWhere((row) => row['id'] == saleId);
      if (printTicket) {
        final saleItems = await widget.store.saleItems(saleId);
        try {
          await _printPosTicket(widget.store, sale, saleItems);
        } catch (printError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('La venta quedó cobrada, pero no se pudo imprimir: $printError')),
            );
          }
        }
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _SaleReceipt(
          saleId: saleId,
          folio: _str(sale['folio']),
          total: widget.total,
          change: _isCash ? _change : 0,
          paymentSummary: _paymentSummary,
          cashPayment: _isCash,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar el cobro: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortfall = _isCash
        ? FinancialRules.money((widget.total - _receivedInPesos).clamp(0.0, double.infinity).toDouble())
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar venta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total a cobrar',
                    style: TextStyle(fontSize: 12, color: Color(0xFF81778D))),
                  const SizedBox(height: 3),
                  Text(_money(widget.total),
                    style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: eShokPurple)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeading('Forma de pago'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'EFECTIVO', label: Text('Efectivo'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'TRANSFERENCIA', label: Text('Transferencia'), icon: Icon(Icons.account_balance_outlined)),
                ButtonSegment(value: 'TARJETA', label: Text('Tarjeta'), icon: Icon(Icons.credit_card_outlined)),
              ],
              selected: {_method},
              onSelectionChanged: (value) => setState(() {
                _method = value.first;
                _received.clear();
                _transferReference.clear();
              }),
            ),
            if (_isCash) ...[
              const SizedBox(height: 14),
              const Text('Moneda recibida',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'MXN', label: Text('Pesos MXN')),
                  if (_acceptUsdCash)
                    const ButtonSegment(value: 'USD', label: Text('Dólares USD')),
                ],
                selected: {_acceptUsdCash ? _cashCurrency : 'MXN'},
                onSelectionChanged: (value) => setState(() {
                  _cashCurrency = value.first;
                  _received.clear();
                }),
              ),
              const SizedBox(height: 10),
              if (_isUsdCash) ...[
                TextField(
                  controller: _exchangeRate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cambio predeterminado (MXN por USD)',
                    prefixText: r'$ ',
                  ),
                ),
                if (_defaultRate.isEmpty && _canSaveRate)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _saveRateAsDefault,
                    onChanged: (value) => setState(() => _saveRateAsDefault = value ?? false),
                    title: const Text('Guardar como tipo de cambio predeterminado',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                if (_defaultRate.isNotEmpty && _canSaveRate && _rate.toStringAsFixed(4) != _defaultRate)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _saveRateAsDefault,
                    onChanged: (value) => setState(() => _saveRateAsDefault = value ?? false),
                    title: const Text('Actualizar tipo de cambio predeterminado',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
              TextField(
                controller: _received,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _isUsdCash ? 'Dólares recibidos' : 'Efectivo recibido',
                  prefixText: _isUsdCash ? r'US$ ' : r'$ ',
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF1EBF9), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isUsdCash ? 'Equivalente en pesos' : 'Cambio a entregar',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF81778D))),
                    const SizedBox(height: 3),
                    Text(
                      _isUsdCash ? _money(_receivedInPesos) : _money(_change),
                      style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: eShokPurple),
                    ),
                    if (_isUsdCash) ...[
                      const SizedBox(height: 4),
                      Text('Cambio en MXN: ${_money(_change)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                    if (shortfall > 0)
                      Text('Faltan ${_money(shortfall)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB65E69), fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
            if (_method == 'TRANSFERENCIA') ...[
              const SizedBox(height: 14),
              TextField(
                controller: _transferReference,
                decoration: const InputDecoration(
                  labelText: 'Referencia de transferencia',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _reportLine('Artículos', widget.items.length.toString()),
            _reportLine('Total', _money(widget.total)),
            _reportLine('Medio de pago', _paymentSummary),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _complete(printTicket: false),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Cobrar sin imprimir ticket'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _complete(printTicket: true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Cobrar e imprimir ticket'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaleSuccessPage extends StatelessWidget {
  const _SaleSuccessPage({super.key, required this.receipt});
  final _SaleReceipt receipt;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Venta completada')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F5EE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF279B70), size: 44),
              ),
              const SizedBox(height: 16),
              const Text('¡Cobro registrado!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: eShokInk)),
              const SizedBox(height: 5),
              Text('Folio ${receipt.folio}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF81778D))),
              const SizedBox(height: 26),
              GlassCard(
                padding: const EdgeInsets.all(19),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF1EBF9), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  children: [
                    const Text('TOTAL COBRADO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF81778D))),
                    const SizedBox(height: 4),
                    Text(_money(receipt.total),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: eShokPurple)),
                    const Divider(height: 24),
                    if (receipt.cashPayment) ...[
                      const Text('CAMBIO A ENTREGAR',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF81778D))),
                      const SizedBox(height: 4),
                      Text(_money(receipt.change),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF279B70))),
                    ] else
                      Text(receipt.paymentSummary,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: eShokInk)),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Terminar'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_finished) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _finished = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Escanear código de barras'),
      actions: [
        IconButton(
          tooltip: 'Encender o apagar linterna',
          onPressed: () => _controller.toggleTorch(),
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
        IconButton(
          tooltip: 'Cambiar cámara',
          onPressed: () => _controller.switchCamera(),
          icon: const Icon(Icons.cameraswitch_outlined),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 290,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 34,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Coloca el código dentro del recuadro. La lectura se realiza automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _printPosTicket(
  LocalStore store,
  Map<String, Object?> sale,
  List<Map<String, Object?>> items,
) async {
  final shopName = await store.setting('shop_name', fallback: 'eShokFix');
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    margin: const pw.EdgeInsets.all(12),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(shopName,
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('Ticket de venta',
            style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.Text('Folio: ${sale['folio']}'),
        pw.Text('Fecha: ${_date(sale['created_at'])}'),
        pw.Text('Cliente: ${_str(sale['client_name'], 'Venta general')}'),
        pw.Divider(),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${item['description']}'),
              pw.Text(
                '${_num(item['quantity'])} × ${_money(item['unit_price'])} = ${_money(item['line_total'])}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        )),
        pw.Divider(),
        pw.Text('Subtotal: ${_money(sale['subtotal'])}'),
        pw.Text('Descuento: ${_money(sale['discount'])}'),
        pw.Text('TOTAL: ${_money(sale['total'])}',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.Text('Pago: ${_str(sale['payment_method'])}'),
        if (_str(sale['notes']).isNotEmpty)
          pw.Text('Detalle: ${_str(sale['notes'])}',
            style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('Gracias por tu compra',
            style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    ),
  ));
  await Printing.layoutPdf(
    onLayout: (_) async => doc.save(),
    name: 'eShokFix-${sale['folio']}.pdf',
  );
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
          pw.Center(child: pw.Text(shopName, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
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
          pw.Text('TOTAL: ${_money(sale['total'])}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
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
