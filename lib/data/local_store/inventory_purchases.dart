part of '../local_store.dart';

extension LocalStoreInventoryPurchaseOperations on LocalStore {
  Future<List<Map<String, Object?>>> inventory({String query = ''}) {
    final q = '%${query.trim()}%';
    return db.rawQuery('SELECT * FROM inventory_items WHERE name LIKE ? OR COALESCE(sku,\'\') LIKE ? ORDER BY name COLLATE NOCASE', [q, q]);
  }

  Future<int> saveInventoryItem({int? id, String sku = '', required String name, String category = 'General', double stock = 0, double minStock = 0, double cost = 0, double price = 0, String location = ''}) async {
    requirePermission('inventory.manage');
    requirePermission('inventory.view');


    if (name.trim().isEmpty) throw ArgumentError('El nombre del artículo es obligatorio.');
    if (![stock, minStock, cost, price].every((value) => value.isFinite) ||
        stock < 0 || minStock < 0 || cost < 0 || price < 0) {
      throw ArgumentError('Existencia, mínimo, costo y precio deben ser valores válidos no negativos.');
    }
    final now = _now();
    final data = {
      'sku': sku.trim().isEmpty ? null : sku.trim(),
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'min_stock': minStock,
      'cost': FinancialRules.money(cost),
      'price': FinancialRules.money(price),
      'location': location.trim(),
      'updated_at': now,
    };
    return db.transaction((tx) async {
      late final int itemId;
      final creating = id == null;
      if (creating) {
        itemId = await tx.insert('inventory_items', {
          ...data,
          'stock': stock,
        });
        if (stock > 0) {
          await _recordInventoryMovement(
            tx, itemId, stock, 'IN', 'Existencia inicial', now,
          );
        }
      } else {
        final exists = await tx.query(
          'inventory_items',
          columns: ['id'],
          where: 'id=?',
          whereArgs: [id],
          limit: 1,
        );
        if (exists.isEmpty) throw StateError('Artículo de inventario no encontrado.');
        itemId = id;
        await tx.update('inventory_items', data, where: 'id=?', whereArgs: [id]);
      }
      await tx.insert('audit_log', {
        'entity': 'inventory_item',
        'entity_id': itemId,
        'action': creating ? 'CREATE' : 'UPDATE',
        'detail': name.trim(),
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'inventory_item',
        'entity_id': itemId,
        'operation': creating ? 'CREATE' : 'UPDATE',
        'payload': jsonEncode({
          ...data,
          if (creating) 'stock': stock,
        }),
        'created_at': now,
      });
      return itemId;
    });
  }

  Future<void> adjustInventory(int itemId, double quantity, String reason) async {
    requirePermission('inventory.manage');

    if (!quantity.isFinite) throw ArgumentError('La cantidad debe ser un número válido.');
    if (quantity == 0) return;
    if (reason.trim().isEmpty) throw ArgumentError('Indica el motivo del movimiento.');
    await db.transaction((tx) async {
      final rows = await tx.query('inventory_items', columns: ['stock'], where: 'id=?', whereArgs: [itemId], limit: 1);
      if (rows.isEmpty) throw StateError('Artículo no encontrado.');
      final stock = (rows.first['stock'] as num).toDouble();
      if (stock + quantity < 0) throw StateError('No hay existencia suficiente.');
      await tx.update('inventory_items', {'stock': stock + quantity, 'updated_at': _now()}, where: 'id=?', whereArgs: [itemId]);
      final now = _now();
      await tx.insert('inventory_movements', {'item_id': itemId, 'movement_type': quantity > 0 ? 'IN' : 'OUT', 'quantity': quantity.abs(), 'reason': reason, 'created_at': now});
      await tx.insert('audit_log', {'entity': 'inventory_item', 'entity_id': itemId, 'action': 'STOCK_ADJUST', 'detail': '$quantity · $reason', 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'inventory_item', 'entity_id': itemId, 'operation': 'STOCK_ADJUST', 'payload': jsonEncode({'quantity': quantity, 'reason': reason}), 'created_at': now});
    });
  }

  Future<List<Map<String, Object?>>> suppliers({String query = ''}) {
    final q = '%${query.trim()}%';
    return db.query('suppliers',
      where: "name LIKE ? OR COALESCE(phone,'') LIKE ? OR COALESCE(tax_id,'') LIKE ?",
      whereArgs: [q, q, q], orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveSupplier({
    int? id,
    required String name,
    String phone = '',
    String whatsapp = '',
    String email = '',
    String taxId = '',
    String address = '',
    String notes = '',
  }) async {
    requirePermission('purchases.manage');
    requirePermission('purchases.view');


    if (name.trim().isEmpty) throw ArgumentError('El nombre del proveedor es obligatorio.');
    final now = _now();
    final data = {
      'name': name.trim(), 'phone': phone.trim(), 'whatsapp': whatsapp.trim(),
      'email': email.trim(), 'tax_id': taxId.trim(), 'address': address.trim(),
      'notes': notes.trim(), 'updated_at': now,
    };
    return db.transaction((tx) async {
      late final int supplierId;
      if (id == null) {
        supplierId = await tx.insert('suppliers', {...data, 'created_at': now});
      } else {
        final exists = await tx.query('suppliers', columns: ['id'],
          where: 'id=?', whereArgs: [id], limit: 1);
        if (exists.isEmpty) throw StateError('Proveedor no encontrado.');
        supplierId = id;
        await tx.update('suppliers', data, where: 'id=?', whereArgs: [id]);
      }
      await tx.insert('audit_log', {
        'entity': 'supplier', 'entity_id': supplierId,
        'action': id == null ? 'CREATE' : 'UPDATE',
        'detail': name.trim(), 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'supplier', 'entity_id': supplierId,
        'operation': id == null ? 'CREATE' : 'UPDATE',
        'payload': jsonEncode(data), 'created_at': now,
      });
      return supplierId;
    });
  }

  Future<List<Map<String, Object?>>> purchases({String query = ''}) async {
    requirePermission('purchases.view');

    final q = '%${query.trim()}%';
    return db.rawQuery('''SELECT p.*, s.name supplier_name,
      (SELECT COUNT(*) FROM purchase_items pi WHERE pi.purchase_id=p.id) item_count
      FROM purchases p JOIN suppliers s ON s.id=p.supplier_id
      WHERE p.folio LIKE ? OR s.name LIKE ?
      ORDER BY p.id DESC''', [q, q]);
  }

  Future<List<Map<String, Object?>>> purchaseItems(int purchaseId) { requirePermission('purchases.view'); return db.rawQuery('''SELECT pi.*, i.sku FROM purchase_items pi
      JOIN inventory_items i ON i.id=pi.item_id
      WHERE pi.purchase_id=? ORDER BY pi.id''', [purchaseId]); }

  Future<int> createPurchase({
    required int supplierId,
    required List<Map<String, Object?>> items,
    double discount = 0,
    double paid = 0,
    String paymentMethod = 'EFECTIVO',
    List<Map<String, Object?>>? paymentBreakdown,
    bool receiveImmediately = true,
    String notes = '',
  }) async {
    requirePermission('purchases.manage');
    requirePermission('purchases.view');


    if (items.isEmpty) throw ArgumentError('Agrega al menos un artículo a la compra.');
    if (![discount, paid].every((value) => value.isFinite) || discount < 0 || paid < 0) {
      throw ArgumentError('Descuento y pago deben ser importes válidos no negativos.');
    }
    final prepared = <Map<String, Object?>>[];
    var subtotal = 0.0;
    for (final line in items) {
      final itemId = line['item_id'];
      final quantityValue = line['quantity'];
      final costValue = line['unit_cost'];
      if (itemId is! int || quantityValue is! num || costValue is! num) {
        throw ArgumentError('Cada partida necesita artículo, cantidad y costo válidos.');
      }
      final quantity = quantityValue.toDouble();
      final unitCost = costValue.toDouble();
      if (!quantity.isFinite || !unitCost.isFinite || quantity <= 0 || unitCost < 0) {
        throw ArgumentError('La cantidad debe ser mayor a cero y el costo debe ser un importe válido no negativo.');
      }
      final lineTotal = FinancialRules.money(PurchaseAccounting.lineTotal(quantity, unitCost));
      subtotal += lineTotal;
      prepared.add({
        'item_id': itemId,
        'quantity': quantity,
        'unit_cost': unitCost,
        'line_total': lineTotal,
      });
    }
    subtotal = FinancialRules.money(subtotal);
    final normalizedDiscount = FinancialRules.money(discount);
    final normalizedPaid = FinancialRules.money(paid);
    if (normalizedDiscount > subtotal) throw ArgumentError('El descuento no puede superar el subtotal.');
    final total = FinancialRules.money(PurchaseAccounting.total(subtotal, normalizedDiscount));
    if (normalizedPaid > total) throw ArgumentError('El pago inicial no puede superar el total de la compra.');
    final tender = FinancialRules.normalizePayments(
      total: normalizedPaid, fallbackMethod: paymentMethod, payments: paymentBreakdown,
    );
    final storedMethod = tender.length > 1 ? 'MIXTO'
        : (tender.isEmpty ? paymentMethod : tender.first['method'] as String);
    final now = _now();

    return db.transaction((tx) async {
      final supplier = await tx.query('suppliers', columns: ['id'],
        where: 'id=?', whereArgs: [supplierId], limit: 1);
      if (supplier.isEmpty) throw StateError('El proveedor seleccionado ya no existe.');
      for (final line in prepared) {
        final stockItem = await tx.query('inventory_items',
          columns: ['id', 'name', 'stock'],
          where: 'id=?', whereArgs: [line['item_id']], limit: 1);
        if (stockItem.isEmpty) throw StateError('Uno de los artículos ya no existe en inventario.');
      }
      final purchaseId = await tx.insert('purchases', {
        'folio': 'PENDING-${DateTime.now().microsecondsSinceEpoch}',
        'supplier_id': supplierId,
        'subtotal': subtotal,
        'discount': normalizedDiscount,
        'total': total,
        'paid': normalizedPaid,
        'payment_status': PurchaseAccounting.paymentStatus(total, normalizedPaid),
        'payment_method': storedMethod,
        'status': receiveImmediately ? 'RECEIVED' : 'ORDERED',
        'notes': notes.trim(),
        'received_at': now,
        'created_at': now,
      });
      final folio = _moneyFolio('CP', purchaseId);
      await tx.update('purchases', {'folio': folio},
        where: 'id=?', whereArgs: [purchaseId]);

      for (final line in prepared) {
        final itemId = line['item_id'] as int;
        final current = await tx.query('inventory_items',
          columns: ['stock', 'name'],
          where: 'id=?', whereArgs: [itemId], limit: 1);
        final oldStock = (current.first['stock'] as num).toDouble();
        final quantity = line['quantity'] as double;
        final unitCost = line['unit_cost'] as double;
        final newStock = oldStock + quantity;
        if (receiveImmediately) {
          await tx.update('inventory_items', {
            'stock': newStock, 'cost': unitCost, 'updated_at': now,
          }, where: 'id=?', whereArgs: [itemId]);
        }
        await tx.insert('purchase_items', {
          'purchase_id': purchaseId, 'item_id': itemId,
          'description': current.first['name'],
          'quantity': quantity,
          'received_quantity': receiveImmediately ? quantity : 0,
          'unit_cost': unitCost,
          'line_total': line['line_total'],
        });
        if (receiveImmediately) {
          await tx.insert('inventory_movements', {
            'item_id': itemId, 'movement_type': 'IN',
            'quantity': quantity, 'reason': 'Compra $folio',
            'created_at': now,
          });
        }
      }
      for (final part in tender) {
        final method = part['method'] as String;
        final amount = part['amount'] as double;
        await tx.insert('purchase_payments', {
          'purchase_id': purchaseId, 'method': method,
          'amount': amount, 'reference': '', 'created_at': now,
        });
        await tx.insert('cash_movements', {
          'movement_type': 'OUT', 'amount': amount,
          'concept': 'Pago de compra $folio', 'reference': method,
          'payment_method': method, 'created_at': now,
        });
      }
      await tx.insert('audit_log', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'action': 'CREATE', 'detail': '$folio · $total',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'operation': 'CREATE',
        'payload': jsonEncode({
          'folio': folio, 'supplier_id': supplierId,
          'subtotal': subtotal, 'discount': normalizedDiscount,
          'total': total, 'paid': normalizedPaid, 'status': receiveImmediately ? 'RECEIVED' : 'ORDERED',
          'payment_breakdown': tender, 'items': prepared,
        }),
        'created_at': now,
      });
      return purchaseId;
    });
  }

  Future<void> recordPurchasePayment(
    int purchaseId,
    double amount,
    String method, {
    String reference = '',
    List<Map<String, Object?>>? paymentBreakdown,
  }) async {
    requirePermission('purchases.manage');

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('El pago debe ser mayor a cero y válido.');
    }
    final normalizedAmount = FinancialRules.money(amount);
    final tender = FinancialRules.normalizePayments(
      total: normalizedAmount,
      fallbackMethod: method,
      payments: paymentBreakdown,
    );
    final normalizedMethod = tender.length > 1
        ? 'MIXTO'
        : tender.first['method'] as String;
    final now = _now();

    await db.transaction((tx) async {
      final rows = await tx.query(
        'purchases',
        columns: ['folio', 'total', 'paid'],
        where: 'id=?',
        whereArgs: [purchaseId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Compra no encontrada.');
      final total = (rows.first['total'] as num).toDouble();
      final paid = (rows.first['paid'] as num).toDouble();
      if (normalizedAmount > PurchaseAccounting.balance(total, paid) + 0.000001) {
        throw StateError('El pago supera el saldo pendiente de la compra.');
      }

      final newPaid = FinancialRules.money(paid + normalizedAmount);
      await tx.update('purchases', {
        'paid': newPaid,
        'payment_status': PurchaseAccounting.paymentStatus(total, newPaid),
        'payment_method': normalizedMethod,
      }, where: 'id=?', whereArgs: [purchaseId]);

      for (final part in tender) {
        final partMethod = part['method'] as String;
        final partAmount = part['amount'] as double;
        await tx.insert('purchase_payments', {
          'purchase_id': purchaseId,
          'method': partMethod,
          'amount': partAmount,
          'reference': reference.trim(),
          'created_at': now,
        });
        await tx.insert('cash_movements', {
          'movement_type': 'OUT',
          'amount': partAmount,
          'concept': 'Abono a compra ${rows.first['folio']}',
          'reference': reference.trim().isEmpty ? partMethod : reference.trim(),
          'payment_method': partMethod,
          'created_at': now,
        });
      }

      await tx.insert('audit_log', {
        'entity': 'purchase',
        'entity_id': purchaseId,
        'action': 'PAYMENT',
        'detail': '$normalizedAmount · $normalizedMethod',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'purchase',
        'entity_id': purchaseId,
        'operation': 'PAYMENT',
        'payload': jsonEncode({
          'amount': normalizedAmount,
          'method': normalizedMethod,
          'breakdown': tender,
          'reference': reference.trim(),
        }),
        'created_at': now,
      });
    });
  }


}
