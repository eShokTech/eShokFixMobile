part of '../local_store.dart';

extension LocalStoreSalesOperations on LocalStore {
  Future<List<Map<String, Object?>>> sales() { requirePermission('sales.view'); return db.rawQuery('''SELECT s.*, c.name client_name FROM sales s LEFT JOIN clients c ON c.id=s.client_id ORDER BY s.id DESC LIMIT 100'''); }
  Future<List<Map<String, Object?>>> salePayments(int saleId) { requirePermission('sales.view'); return db.query(
    'sale_payments', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id'); }
  Future<List<Map<String, Object?>>> saleReturns(int saleId) { requirePermission('sales.view'); return db.query(
    'sale_returns', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id DESC'); }
  Future<List<Map<String, Object?>>> purchasePayments(int purchaseId) { requirePermission('purchases.view'); return db.query(
    'purchase_payments', where: 'purchase_id=?', whereArgs: [purchaseId], orderBy: 'id'); }
  Future<List<Map<String, Object?>>> purchaseReturns(int purchaseId) { requirePermission('purchases.view'); return db.query(
    'purchase_returns', where: 'purchase_id=?', whereArgs: [purchaseId], orderBy: 'id DESC'); }
  Future<void> createSale({int? itemId, required String description, required double quantity, required double unitPrice, required String paymentMethod, double discount = 0, String notes = ''}) async {
    requirePermission('sales.manage');
    requirePermission('purchases.view');
    requirePermission('sales.view');
    requirePermission('sales.view');
    await createSaleCart(
      items: [{
        'item_id': itemId, 'description': description,
        'quantity': quantity, 'unit_price': unitPrice,
      }],
      paymentMethod: paymentMethod,
      discount: discount,
      notes: notes,
    );
  }

  Future<List<Map<String, Object?>>> saleItems(int saleId) { requirePermission('sales.view'); return db.query('sale_items', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id'); }

  Future<int> createSaleCart({
    int? clientId,
    required List<Map<String, Object?>> items,
    required String paymentMethod,
    double discount = 0,
    List<Map<String, Object?>>? paymentBreakdown,
    String notes = '',
  }) async {
    requirePermission('sales.manage');
    requirePermission('sales.view');
    if (items.isEmpty) throw ArgumentError('Agrega al menos un producto o servicio.');
    if (!discount.isFinite || discount < 0) throw ArgumentError('El descuento debe ser un importe válido no negativo.');

    final prepared = <Map<String, Object?>>[];
    var subtotal = 0.0;
    for (final line in items) {
      final itemId = line['item_id'];
      final description = (line['description'] ?? '').toString().trim();
      final quantityValue = line['quantity'];
      final priceValue = line['unit_price'];
      if (description.isEmpty || quantityValue is! num || priceValue is! num) {
        throw ArgumentError('Cada partida necesita descripción, cantidad y precio válidos.');
      }
      final quantity = quantityValue.toDouble();
      final unitPrice = priceValue.toDouble();
      if (!quantity.isFinite || !unitPrice.isFinite || quantity <= 0 || unitPrice < 0 || (itemId != null && itemId is! int)) {
        throw ArgumentError('Revisa la cantidad, precio y artículo de cada partida.');
      }
      final lineTotal = FinancialRules.money(quantity * unitPrice);
      subtotal += lineTotal;
      prepared.add({
        'item_id': itemId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_total': lineTotal,
      });
    }
    subtotal = FinancialRules.money(subtotal);
    final normalizedDiscount = FinancialRules.money(discount);
    if (normalizedDiscount > subtotal) throw ArgumentError('El descuento no puede superar el subtotal.');
    final total = FinancialRules.money((subtotal - normalizedDiscount).clamp(0.0, double.infinity).toDouble());
    final tender = FinancialRules.normalizePayments(
      total: total, fallbackMethod: paymentMethod, payments: paymentBreakdown,
    );
    final storedMethod = tender.length > 1 ? 'MIXTO'
        : (tender.isEmpty ? paymentMethod : tender.first['method'] as String);
    final now = _now();

    return db.transaction((tx) async {
      if (clientId != null) {
        final client = await tx.query('clients', columns: ['id'],
          where: 'id=?', whereArgs: [clientId], limit: 1);
        if (client.isEmpty) throw StateError('El cliente seleccionado ya no existe.');
      }

      for (final line in prepared) {
        final itemId = line['item_id'];
        if (itemId == null) continue;
        final item = await tx.query('inventory_items',
          columns: ['stock', 'name'],
          where: 'id=?', whereArgs: [itemId], limit: 1);
        if (item.isEmpty) throw StateError('Uno de los artículos ya no existe en inventario.');
        final stock = (item.first['stock'] as num).toDouble();
        final quantity = line['quantity'] as double;
        if (stock < quantity) {
          throw StateError('Existencia insuficiente para ${line['description']}. Disponible: $stock.');
        }
        await tx.update('inventory_items', {
          'stock': stock - quantity, 'updated_at': now,
        }, where: 'id=?', whereArgs: [itemId]);
        await tx.insert('inventory_movements', {
          'item_id': itemId, 'movement_type': 'OUT',
          'quantity': quantity, 'reason': 'Venta POS',
          'created_at': now,
        });
      }

      final saleId = await tx.insert('sales', {
        'folio': 'PENDING-${DateTime.now().microsecondsSinceEpoch}',
        'client_id': clientId,
        'subtotal': subtotal,
        'discount': normalizedDiscount,
        'total': total,
        'payment_method': storedMethod,
        'amount_paid': total,
        'status': 'COMPLETED',
        'refunded_total': 0,
        'notes': notes.trim(),
        'created_at': now,
      });
      final folio = _moneyFolio('PV', saleId);
      await tx.update('sales', {'folio': folio}, where: 'id=?', whereArgs: [saleId]);

      for (final line in prepared) {
        await tx.insert('sale_items', {
          'sale_id': saleId,
          'item_id': line['item_id'],
          'description': line['description'],
          'quantity': line['quantity'],
          'unit_price': line['unit_price'],
          'line_total': line['line_total'],
        });
      }
      for (final part in tender) {
        final method = part['method'] as String;
        final amount = part['amount'] as double;
        await tx.insert('sale_payments', {
          'sale_id': saleId, 'method': method, 'amount': amount,
          'reference': '', 'created_at': now,
        });
        await tx.insert('cash_movements', {
          'movement_type': 'IN', 'amount': amount,
          'concept': 'Venta POS $folio', 'reference': method,
          'created_at': now, 'related_sale_id': saleId,
          'payment_method': method,
        });
      }
      await tx.insert('audit_log', {
        'entity': 'sale', 'entity_id': saleId,
        'action': 'CREATE', 'detail': '$folio · $total',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'sale', 'entity_id': saleId,
        'operation': 'CREATE',
        'payload': jsonEncode({
          'folio': folio, 'client_id': clientId, 'subtotal': subtotal,
          'discount': normalizedDiscount, 'total': total, 'method': storedMethod,
          'payment_breakdown': tender, 'items': prepared,
        }),
        'created_at': now,
      });
      return saleId;
    });
  }

  Future<void> returnSaleItem({
    required int saleId,
    required int saleItemId,
    required double quantity,
    required String refundMethod,
    required String reason,
  }) async {
    requirePermission('sales.manage');
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('La cantidad a devolver debe ser mayor a cero.');
    if (reason.trim().isEmpty) throw ArgumentError('Indica el motivo de la devolución.');
    final method = refundMethod.trim().toUpperCase();
    if (!FinancialRules.paymentMethods.contains(method)) throw ArgumentError('Selecciona un medio de reembolso válido.');
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.rawQuery('''SELECT si.*, s.status sale_status,
          s.subtotal sale_subtotal, s.total sale_total, s.refunded_total,
          i.stock item_stock
        FROM sale_items si JOIN sales s ON s.id=si.sale_id
        LEFT JOIN inventory_items i ON i.id=si.item_id
        WHERE si.id=? AND si.sale_id=?''', [saleItemId, saleId]);
      if (rows.isEmpty) throw StateError('No se encontró la partida de la venta.');
      final row = rows.first;
      if (row['sale_status'] == 'VOID') throw StateError('La venta ya fue cancelada.');
      final sold = (row['quantity'] as num).toDouble();
      final returned = (row['returned_quantity'] as num).toDouble();
      final remaining = FinancialRules.remainingQuantity(sold, returned);
      if (quantity > remaining + 0.000001) throw StateError('La cantidad supera lo que queda por devolver.');
      final alreadyRefunded = (row['refunded_total'] as num).toDouble();
      final saleTotal = (row['sale_total'] as num).toDouble();
      final otherOpenLines = Sqflite.firstIntValue(await tx.rawQuery('''
        SELECT COUNT(*) FROM sale_items
        WHERE sale_id=? AND id!=? AND returned_quantity < quantity - 0.000001
      ''', [saleId, saleItemId])) ?? 0;
      final closesLastLine = quantity >= remaining - 0.000001 && otherOpenLines == 0;
      final calculatedAmount = FinancialRules.saleLineRefund(
        quantity: quantity,
        unitPrice: (row['unit_price'] as num).toDouble(),
        saleSubtotal: (row['sale_subtotal'] as num).toDouble(),
        saleTotal: saleTotal,
      );
      final amount = closesLastLine
          ? FinancialRules.money(saleTotal - alreadyRefunded)
          : calculatedAmount;
      if (alreadyRefunded + amount > saleTotal + 0.01) throw StateError('El reembolso superaría el total cobrado.');
      final returnId = await tx.insert('sale_returns', {
        'sale_id': saleId, 'amount': amount, 'refund_method': method,
        'reason': reason.trim(), 'created_at': now,
      });
      await tx.insert('sale_return_items', {
        'return_id': returnId, 'sale_item_id': saleItemId,
        'quantity': quantity, 'amount': amount,
      });
      final itemId = row['item_id'];
      if (itemId is int) {
        final stock = (row['item_stock'] as num?)?.toDouble();
        if (stock == null) throw StateError('El artículo asociado ya no existe.');
        await tx.update('inventory_items', {'stock': stock + quantity, 'updated_at': now},
          where: 'id=?', whereArgs: [itemId]);
        await tx.insert('inventory_movements', {
          'item_id': itemId, 'movement_type': 'IN', 'quantity': quantity,
          'reason': 'Devolución de venta $saleId', 'created_at': now,
        });
      }
      await tx.update('sale_items', {'returned_quantity': returned + quantity},
        where: 'id=?', whereArgs: [saleItemId]);
      final outstandingLines = Sqflite.firstIntValue(await tx.rawQuery('''
        SELECT COUNT(*) FROM sale_items
        WHERE sale_id=? AND returned_quantity < quantity - 0.000001
      ''', [saleId])) ?? 0;
      await tx.update('sales', {
        'refunded_total': (alreadyRefunded + amount).clamp(0.0, saleTotal).toDouble(),
        'status': outstandingLines == 0 ? 'VOID' : 'PARTIAL_RETURN',
      }, where: 'id=?', whereArgs: [saleId]);
      if (amount > 0) {
        await tx.insert('cash_movements', {
          'movement_type': 'OUT', 'amount': amount, 'concept': 'Devolución de venta $saleId',
          'reference': method, 'payment_method': method, 'created_at': now,
          'related_sale_id': saleId,
        });
      }
      await tx.insert('audit_log', {
        'entity': 'sale', 'entity_id': saleId, 'action': 'RETURN_ITEM',
        'detail': '$quantity · $amount · $method · ${reason.trim()}', 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'sale_return', 'entity_id': returnId, 'operation': 'CREATE',
        'payload': jsonEncode({'sale_id': saleId, 'sale_item_id': saleItemId,
          'quantity': quantity, 'amount': amount, 'method': method, 'reason': reason.trim()}),
        'created_at': now,
      });
    });
  }

  Future<void> cancelSale(int saleId, {
    required String refundMethod, required String reason,
  }) async {
    requirePermission('sales.manage');
    if (reason.trim().isEmpty) throw ArgumentError('Indica el motivo de cancelación.');
    final method = refundMethod.trim().toUpperCase();
    if (!FinancialRules.paymentMethods.contains(method)) throw ArgumentError('Selecciona un medio de reembolso válido.');
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query('sales',
        columns: ['folio', 'subtotal', 'total', 'refunded_total', 'status'],
        where: 'id=?', whereArgs: [saleId], limit: 1);
      if (rows.isEmpty) throw StateError('Venta no encontrada.');
      final sale = rows.first;
      if (sale['status'] == 'VOID') throw StateError('La venta ya está cancelada.');
      final total = (sale['total'] as num).toDouble();
      final refunded = (sale['refunded_total'] as num).toDouble();
      final refund = FinancialRules.money(total - refunded);
      if (refund <= 0) throw StateError('La venta no tiene saldo por reembolsar.');
      final lines = await tx.query('sale_items', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id');
      final returnId = await tx.insert('sale_returns', {
        'sale_id': saleId, 'amount': refund, 'refund_method': method,
        'reason': reason.trim(), 'created_at': now,
      });
      var allocatedRefund = 0.0;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final quantity = (line['quantity'] as num).toDouble();
        final returned = (line['returned_quantity'] as num).toDouble();
        final remaining = FinancialRules.remainingQuantity(quantity, returned);
        if (remaining <= 0) continue;
        final lineRefund = FinancialRules.saleLineRefund(
          quantity: remaining,
          unitPrice: (line['unit_price'] as num).toDouble(),
          saleSubtotal: (rows.first['subtotal'] as num).toDouble(),
          saleTotal: total,
        );
        final isLastRemainingLine = !lines.skip(index + 1).any((candidate) =>
          FinancialRules.remainingQuantity(
            (candidate['quantity'] as num).toDouble(),
            (candidate['returned_quantity'] as num).toDouble(),
          ) > 0);
        final allocatedLineRefund = isLastRemainingLine
          ? FinancialRules.money(refund - allocatedRefund)
          : lineRefund;
        allocatedRefund += allocatedLineRefund;
        await tx.insert('sale_return_items', {
          'return_id': returnId, 'sale_item_id': line['id'],
          'quantity': remaining, 'amount': allocatedLineRefund,
        });
        final itemId = line['item_id'];
        if (itemId is int) {
          final itemRows = await tx.query('inventory_items', columns: ['stock'],
            where: 'id=?', whereArgs: [itemId], limit: 1);
          if (itemRows.isEmpty) throw StateError('Un artículo vendido ya no existe en inventario.');
          final stock = (itemRows.first['stock'] as num).toDouble();
          await tx.update('inventory_items', {'stock': stock + remaining, 'updated_at': now},
            where: 'id=?', whereArgs: [itemId]);
          await tx.insert('inventory_movements', {
            'item_id': itemId, 'movement_type': 'IN', 'quantity': remaining,
            'reason': 'Cancelación de venta ${sale['folio']}', 'created_at': now,
          });
        }
        await tx.update('sale_items', {'returned_quantity': quantity},
          where: 'id=?', whereArgs: [line['id']]);
      }
      await tx.update('sales', {'refunded_total': total, 'status': 'VOID'},
        where: 'id=?', whereArgs: [saleId]);
      await tx.insert('cash_movements', {
        'movement_type': 'OUT', 'amount': refund,
        'concept': 'Reembolso de venta ${sale['folio']}',
        'reference': method, 'payment_method': method,
        'created_at': now, 'related_sale_id': saleId,
      });
      await tx.insert('audit_log', {
        'entity': 'sale', 'entity_id': saleId, 'action': 'CANCEL',
        'detail': '$refund · $method · ${reason.trim()}', 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'sale', 'entity_id': saleId, 'operation': 'CANCEL',
        'payload': jsonEncode({'refund': refund, 'method': method, 'reason': reason.trim()}),
        'created_at': now,
      });
    });
  }


}
