part of '../local_store.dart';

extension LocalStoreFinanceAdminOperations on LocalStore {
  Future<Map<String, double>> cashSummary() async {
    requirePermission('cash.view');
    
    

    const period = "created_at > COALESCE((SELECT MAX(closed_at) FROM cash_cuts),'0000-01-01')";
    final cashRows = await db.rawQuery('''SELECT
      COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE -amount END),0) balance,
      COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE 0 END),0) income,
      COALESCE(SUM(CASE WHEN movement_type='OUT' THEN amount ELSE 0 END),0) expense
      FROM cash_movements WHERE $period AND payment_method='EFECTIVO' ''');
    final electronicRows = await db.rawQuery('''SELECT
      COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE -amount END),0) balance,
      COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE 0 END),0) income,
      COALESCE(SUM(CASE WHEN movement_type='OUT' THEN amount ELSE 0 END),0) expense
      FROM cash_movements WHERE $period AND payment_method!='EFECTIVO' ''');
    return {
      'balance': (cashRows.first['balance'] as num).toDouble(),
      'income': (cashRows.first['income'] as num).toDouble(),
      'expense': (cashRows.first['expense'] as num).toDouble(),
      'digital_balance': (electronicRows.first['balance'] as num).toDouble(),
      'digital_income': (electronicRows.first['income'] as num).toDouble(),
      'digital_expense': (electronicRows.first['expense'] as num).toDouble(),
    };
  }

  Future<void> addCashMovement({ 
    required bool income,
    required double amount,
    required String concept,
    String reference = '',
    String paymentMethod = 'EFECTIVO',
  }) async {
    requirePermission('cash.manage');
    

    if (!amount.isFinite || amount <= 0) throw ArgumentError('El importe debe ser mayor a cero y válido.');
    if (concept.trim().isEmpty) throw ArgumentError('El concepto es obligatorio.');
    final normalizedMethod = paymentMethod.trim().toUpperCase();
    if (!FinancialRules.paymentMethods.contains(normalizedMethod)) throw ArgumentError('Medio de pago no válido.');
    final normalizedAmount = FinancialRules.money(amount);
    final now = _now();
    final id = await db.insert('cash_movements', {
      'movement_type': income ? 'IN' : 'OUT',
      'amount': normalizedAmount,
      'concept': concept.trim(),
      'reference': reference.trim(),
      'payment_method': normalizedMethod,
      'created_at': now,
    });
    await _audit('cash_movement', id, income ? 'IN' : 'OUT', '$normalizedAmount · ${concept.trim()} · $normalizedMethod');
    await _outbox('cash_movement', id, 'CREATE', {
      'amount': normalizedAmount, 'type': income ? 'IN' : 'OUT',
      'concept': concept.trim(), 'payment_method': normalizedMethod,
    });
  }

  Future<void> closeCashCut(double counted, String notes) async {
    requirePermission('cash.manage');
    
    

    if (!counted.isFinite || counted < 0) throw ArgumentError('El efectivo contado debe ser un importe válido no negativo.');
    final now = _now();
    await db.transaction((tx) async {
      final latest = await tx.rawQuery("SELECT MAX(closed_at) closed_at FROM cash_cuts");
      final lastClosed = latest.first['closed_at'] as String? ?? '0000-01-01';
      final rows = await tx.rawQuery('''SELECT
        COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE -amount END),0) balance
        FROM cash_movements
        WHERE created_at > ? AND payment_method='EFECTIVO' ''', [lastClosed]);
      final expected = (rows.first['balance'] as num).toDouble();
      final difference = counted - expected;
      final id = await tx.insert('cash_cuts', {
        'opened_at': lastClosed, 'closed_at': now,
        'expected': expected, 'counted': counted,
        'difference': difference, 'notes': notes.trim(),
      });
      await tx.insert('audit_log', {
        'entity': 'cash_cut', 'entity_id': id, 'action': 'CLOSE',
        'detail': 'Esperado $expected · contado $counted', 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'cash_cut', 'entity_id': id, 'operation': 'CREATE',
        'payload': jsonEncode({'expected': expected, 'counted': counted, 'difference': difference}),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> cashMovements() { return db.query('cash_movements', orderBy: 'id DESC', limit: 100); }
    requirePermission('cash.view');
  Future<List<Map<String, Object?>>> cashCuts() { return db.query('cash_cuts', orderBy: 'id DESC', limit: 30); }
    requirePermission('cash.view');
  Future<List<Map<String, Object?>>> warranties() { return db.rawQuery('''SELECT w.*, o.folio, c.name client_name, d.brand, d.model FROM warranties w
    requirePermission('warranties.view');
    JOIN service_orders o ON o.id=w.order_id JOIN clients c ON c.id=o.client_id LEFT JOIN devices d ON d.id=o.device_id ORDER BY w.id DESC'''); }

  Future<Map<String, double>> reportTotals() async {
    requirePermission('reports.view');
    
    
    
    
    



    final orders = await db.rawQuery("SELECT COALESCE(SUM(total),0) total, COALESCE(SUM(paid),0) paid, COUNT(*) count FROM service_orders WHERE status!='CANCELADO'");
    final sales = await db.rawQuery("SELECT COALESCE(SUM(total - COALESCE(refunded_total,0)),0) total, SUM(CASE WHEN status!='VOID' THEN 1 ELSE 0 END) count FROM sales");
    final cash = await cashSummary();
    return {'orders_total': (orders.first['total'] as num).toDouble(), 'orders_paid': (orders.first['paid'] as num).toDouble(), 'orders_count': (orders.first['count'] as num).toDouble(), 'sales_total': (sales.first['total'] as num).toDouble(), 'sales_count': (sales.first['count'] as num).toDouble(), 'cash_balance': cash['balance'] ?? 0, 'digital_balance': cash['digital_balance'] ?? 0};
  }

  Future<String> setting(String key, {String fallback = ''}) async {
    requirePermission('settings.read');
    
    

    final rows = await db.query('settings', columns: ['value'], where: 'key=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }
  Future<void> saveSetting(String key, String value) async {
    requirePermission('settings.manage');
    
    

    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> whatsappEvents() { return db.rawQuery('''SELECT w.*, o.folio, c.name client_name FROM whatsapp_events w JOIN service_orders o ON o.id=w.order_id JOIN clients c ON c.id=o.client_id ORDER BY w.id DESC'''); }
    requirePermission('users.manage');

  Future<Map<String, int>> demoDataCounts() async {
    requirePermission('settings.manage');
    
    
    


    final clientsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM clients WHERE is_demo=1'),
    ) ?? 0;
    final ordersCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM service_orders WHERE is_demo=1'),
    ) ?? 0;
    final itemsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM inventory_items WHERE is_demo=1'),
    ) ?? 0;
    return {'clients': clientsCount, 'orders': ordersCount, 'items': itemsCount};
  }

  Future<void> removeDemoData() async {
    requirePermission('settings.manage');
    
    

    await db.transaction((tx) async {
      final demoOrders = await tx.query(
        'service_orders', columns: ['id'], where: 'is_demo=1',
      );
      for (final row in demoOrders) {
        final orderId = row['id'] as int;
        final evidence = await tx.query(
          'evidences', columns: ['id'], where: 'order_id=?', whereArgs: [orderId],
        );
        for (final item in evidence) {
          await tx.delete('sync_outbox', where: 'entity=? AND entity_id=?',
            whereArgs: ['evidence', item['id']]);
        }
        await tx.delete('warranties', where: 'order_id=?', whereArgs: [orderId]);
        await tx.delete('whatsapp_events', where: 'order_id=?', whereArgs: [orderId]);
        await tx.delete('payments', where: 'order_id=?', whereArgs: [orderId]);
        await tx.delete('evidences', where: 'order_id=?', whereArgs: [orderId]);
        await tx.delete('order_events', where: 'order_id=?', whereArgs: [orderId]);
        await tx.delete('cash_movements', where: 'related_order_id=?', whereArgs: [orderId]);
        await tx.delete('sync_outbox', where: 'entity_id=? AND entity IN (?,?,?)',
          whereArgs: [orderId, 'service_order', 'payment', 'order_part']);
        await tx.delete('audit_log', where: 'entity=? AND entity_id=?',
          whereArgs: ['service_order', orderId]);
      }
      await tx.delete('service_orders', where: 'is_demo=1');

      final demoClients = await tx.query(
        'clients', columns: ['id'], where: 'is_demo=1',
      );
      for (final row in demoClients) {
        final clientId = row['id'] as int;
        final realOrders = Sqflite.firstIntValue(await tx.rawQuery(
          'SELECT COUNT(*) FROM service_orders WHERE client_id=?',
          [clientId],
        )) ?? 0;
        final relatedSales = Sqflite.firstIntValue(await tx.rawQuery(
          'SELECT COUNT(*) FROM sales WHERE client_id=?',
          [clientId],
        )) ?? 0;
        if (realOrders > 0 || relatedSales > 0) {
          await tx.update('clients', {'is_demo': 0}, where: 'id=?', whereArgs: [clientId]);
        } else {
          await tx.delete('devices', where: 'client_id=?', whereArgs: [clientId]);
          await tx.delete('sync_outbox', where: 'entity=? AND entity_id=?',
            whereArgs: ['client', clientId]);
          await tx.delete('audit_log', where: 'entity=? AND entity_id=?',
            whereArgs: ['client', clientId]);
          await tx.delete('clients', where: 'id=?', whereArgs: [clientId]);
        }
      }

      final demoItems = await tx.query(
        'inventory_items', columns: ['id'], where: 'is_demo=1',
      );
      for (final row in demoItems) {
        final itemId = row['id'] as int;
        final sold = Sqflite.firstIntValue(await tx.rawQuery(
          'SELECT COUNT(*) FROM sale_items WHERE item_id=?', [itemId],
        )) ?? 0;
        final purchased = Sqflite.firstIntValue(await tx.rawQuery(
          'SELECT COUNT(*) FROM purchase_items WHERE item_id=?', [itemId],
        )) ?? 0;
        final usedInOrders = Sqflite.firstIntValue(await tx.rawQuery(
          'SELECT COUNT(*) FROM order_parts WHERE item_id=?', [itemId],
        )) ?? 0;
        if (sold > 0 || purchased > 0 || usedInOrders > 0) {
          await tx.update('inventory_items', {'is_demo': 0},
            where: 'id=?', whereArgs: [itemId]);
        } else {
          await tx.delete('inventory_movements', where: 'item_id=?', whereArgs: [itemId]);
          await tx.delete('sync_outbox', where: 'entity=? AND entity_id=?',
            whereArgs: ['inventory_item', itemId]);
          await tx.delete('inventory_items', where: 'id=?', whereArgs: [itemId]);
        }
      }
      await tx.insert('settings', {
        'key': 'demo_mode', 'value': '0',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('audit_log', {
        'entity': 'system', 'entity_id': null,
        'action': 'DEMO_DATA_CLEANUP',
        'detail': 'Se retiraron registros de demostración sin afectar registros reales.',
        'created_at': _now(),
      });
    });
  }


}
