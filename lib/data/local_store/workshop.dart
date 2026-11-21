part of '../local_store.dart';

extension LocalStoreWorkshopOperations on LocalStore {
  Future<Map<String, Object?>> dashboard() async {
    final active = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM service_orders WHERE status NOT IN ('ENTREGADO','CANCELADO')")) ?? 0;
    final ready = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM service_orders WHERE status='LISTO'")) ?? 0;
    final clients = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM clients')) ?? 0;
    final lowStock = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM inventory_items WHERE stock <= min_stock')) ?? 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final sales = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sales WHERE substr(created_at,1,10)=?', [today])) ?? 0;
    final income = await db.rawQuery("SELECT COALESCE(SUM(amount),0) total FROM cash_movements WHERE movement_type='IN' AND substr(created_at,1,10)=?", [today]);
    final recent = await db.rawQuery('''SELECT o.*, c.name client_name, d.brand, d.model
      FROM service_orders o JOIN clients c ON c.id=o.client_id
      LEFT JOIN devices d ON d.id=o.device_id ORDER BY o.id DESC LIMIT 6''');
    final pending = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM sync_outbox WHERE sync_state='LOCAL_ONLY'")) ?? 0;
    return {'active': active, 'ready': ready, 'clients': clients, 'low_stock': lowStock,
      'sales_today': sales, 'income_today': (income.first['total'] as num?)?.toDouble() ?? 0.0,
      'recent': recent, 'pending_local': pending};
  }

  Future<List<Map<String, Object?>>> clients({String query = ''}) async {
    final q = '%${query.trim()}%';
    return db.rawQuery('''SELECT c.*, (SELECT COUNT(*) FROM devices d WHERE d.client_id=c.id) device_count,
      (SELECT COUNT(*) FROM service_orders o WHERE o.client_id=c.id) order_count
      FROM clients c WHERE c.name LIKE ? OR COALESCE(c.phone,'') LIKE ? OR COALESCE(c.whatsapp,'') LIKE ?
      ORDER BY c.name COLLATE NOCASE''', [q, q, q]);
  }

  Future<int> saveClient({int? id, required String name, String phone = '', String whatsapp = '', String email = '', String address = '', String notes = ''}) async {
    if (name.trim().isEmpty) throw ArgumentError('El nombre del cliente es obligatorio.');
    final now = _now();
    final data = {'name': name.trim(), 'phone': phone.trim(), 'whatsapp': whatsapp.trim(), 'email': email.trim(), 'address': address.trim(), 'notes': notes.trim(), 'updated_at': now};
    int clientId;
    if (id == null) {
      clientId = await db.insert('clients', {...data, 'created_at': now});
      await _audit('client', clientId, 'CREATE', name);
    } else {
      await db.update('clients', data, where: 'id=?', whereArgs: [id]);
      clientId = id;
      await _audit('client', id, 'UPDATE', name);
    }
    await _outbox('client', clientId, id == null ? 'CREATE' : 'UPDATE', data);
    return clientId;
  }

  Future<void> deleteClient(int id) async {
    await db.transaction((tx) async {
      final client = await tx.query('clients', columns: ['id', 'name'],
        where: 'id=?', whereArgs: [id], limit: 1);
      if (client.isEmpty) throw StateError('Cliente no encontrado.');
      final orderCount = Sqflite.firstIntValue(await tx.rawQuery(
        'SELECT COUNT(*) FROM service_orders WHERE client_id=?', [id],
      )) ?? 0;
      if (orderCount > 0) throw StateError('Este cliente tiene expedientes. No se puede eliminar; conserva su historial.');
      final salesCount = Sqflite.firstIntValue(await tx.rawQuery(
        'SELECT COUNT(*) FROM sales WHERE client_id=?', [id],
      )) ?? 0;
      if (salesCount > 0) throw StateError('Este cliente tiene ventas vinculadas. Conserva su historial.');
      await tx.delete('devices', where: 'client_id=?', whereArgs: [id]);
      await tx.delete('clients', where: 'id=?', whereArgs: [id]);
      await tx.insert('audit_log', {
        'entity': 'client', 'entity_id': id, 'action': 'DELETE',
        'detail': 'Cliente eliminado · ${client.first['name']}', 'created_at': _now(),
      });
      await tx.insert('sync_outbox', {
        'entity': 'client', 'entity_id': id, 'operation': 'DELETE',
        'payload': jsonEncode({'id': id}), 'created_at': _now(),
      });
    });
  }

  Future<List<Map<String, Object?>>> clientDevices(int clientId) => db.query('devices', where: 'client_id=?', whereArgs: [clientId], orderBy: 'id DESC');

  Future<List<Map<String, Object?>>> orders({String query = '', String status = ''}) async {
    final filters = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      filters.add('(o.folio LIKE ? OR c.name LIKE ? OR COALESCE(c.phone,\'\') LIKE ? OR COALESCE(d.model,\'\') LIKE ?)');
      final q = '%${query.trim()}%'; args.addAll([q, q, q, q]);
    }
    if (status.isNotEmpty) { filters.add('o.status=?'); args.add(status); }
    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    return db.rawQuery('''SELECT o.*, c.name client_name, c.phone client_phone, d.brand, d.model, d.imei
      FROM service_orders o JOIN clients c ON c.id=o.client_id LEFT JOIN devices d ON d.id=o.device_id
      $where ORDER BY o.id DESC''', args);
  }

  Future<Map<String, Object?>?> order(int id) async {
    final rows = await db.rawQuery('''SELECT o.*, c.name client_name, c.phone client_phone, c.whatsapp,
      d.brand, d.model, d.color, d.imei, d.serial, d.accessories, d.condition_note
      FROM service_orders o JOIN clients c ON c.id=o.client_id LEFT JOIN devices d ON d.id=o.device_id WHERE o.id=?''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> createOrder({
    required int clientId,
    required String brand,
    required String model,
    required String failure,
    required String condition,
    required String accessories,
    required String technician,
    double labor = 0,
    double parts = 0,
    double discount = 0,
    double deposit = 0,
    String depositMethod = 'EFECTIVO',
    String notes = '',
    String imei = '',
    String serial = '',
    int warrantyDays = 30,
  }) async {
    final inputs = [labor, parts, discount, deposit];
    if (inputs.any((value) => !value.isFinite) ||
        inputs.any((value) => value < 0) || warrantyDays < 0) {
      throw ArgumentError('Los importes y días de garantía deben ser valores válidos no negativos.');
    }
    if (brand.trim().isEmpty || model.trim().isEmpty || failure.trim().isEmpty) {
      throw ArgumentError('Marca, modelo y falla reportada son obligatorios.');
    }
    final laborAmount = FinancialRules.money(labor);
    final partsAmount = FinancialRules.money(parts);
    final discountAmount = FinancialRules.money(discount);
    final depositAmount = FinancialRules.money(deposit);
    final subtotal = FinancialRules.money(laborAmount + partsAmount);
    if (discountAmount > subtotal) {
      throw ArgumentError('El descuento no puede superar el subtotal del servicio.');
    }
    final computedTotal = FinancialRules.money(subtotal - discountAmount);
    if (depositAmount > computedTotal) {
      throw ArgumentError('El anticipo no puede superar el total del servicio.');
    }
    final depositTender = FinancialRules.normalizePayments(
      total: depositAmount,
      fallbackMethod: depositMethod,
    );
    final storedDepositMethod = depositTender.length > 1
        ? 'MIXTO'
        : (depositTender.isEmpty ? depositMethod : depositTender.first['method'] as String);
    final clientExists = await db.query(
      'clients', columns: ['id'], where: 'id=?', whereArgs: [clientId], limit: 1,
    );
    if (clientExists.isEmpty) throw StateError('El cliente seleccionado ya no existe.');
    final now = _now();
    return db.transaction((tx) async {
      final deviceId = await tx.insert('devices', {
        'client_id': clientId, 'brand': brand.trim(), 'model': model.trim(),
        'color': '', 'imei': imei.trim(), 'serial': serial.trim(),
        'accessories': accessories.trim(), 'condition_note': condition.trim(),
        'notes': '', 'created_at': now,
      });
      final orderId = await tx.insert('service_orders', {
        'folio': 'PENDING-${DateTime.now().microsecondsSinceEpoch}',
        'client_id': clientId, 'device_id': deviceId, 'status': 'RECIBIDO',
        'failure_description': failure.trim(), 'diagnosis': '',
        'technician': technician.trim(), 'received_at': now,
        'estimated_delivery_at': null, 'delivered_at': null,
        'labor': laborAmount, 'parts_total': partsAmount, 'discount': discountAmount,
        'total': computedTotal, 'paid': 0, 'deposit': 0,
        'warranty_days': warrantyDays, 'notes': notes.trim(),
      });
      final folio = _moneyFolio('EF', orderId);
      await tx.update('service_orders', {'folio': folio}, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('order_events', {
        'order_id': orderId, 'from_status': null, 'to_status': 'RECIBIDO',
        'description': 'Equipo recibido y registrado', 'created_at': now,
      });
      await tx.insert('whatsapp_events', {
        'order_id': orderId, 'event_type': 'RECEIVED',
        'message': 'Recibimos tu equipo. Folio $folio.', 'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'service_order', 'entity_id': orderId,
        'action': 'CREATE', 'detail': folio, 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'service_order', 'entity_id': orderId, 'operation': 'CREATE',
        'payload': jsonEncode({'folio': folio, 'client_id': clientId}),
        'created_at': now,
      });
      if (depositAmount > 0) {
        for (final part in depositTender) {
          final method = part['method'] as String;
          final amount = part['amount'] as double;
          await tx.insert('payments', {
            'order_id': orderId, 'amount': amount, 'method': method,
            'reference': '', 'notes': 'Anticipo de recepción', 'created_at': now,
          });
          await tx.insert('cash_movements', {
            'movement_type': 'IN', 'amount': amount,
            'concept': 'Anticipo $folio', 'reference': folio,
            'created_at': now, 'related_order_id': orderId,
            'payment_method': method,
          });
        }
        await tx.update('service_orders', {
          'paid': depositAmount, 'deposit': depositAmount,
        }, where: 'id=?', whereArgs: [orderId]);
        await tx.insert('audit_log', {
          'entity': 'payment', 'entity_id': orderId, 'action': 'DEPOSIT',
          'detail': '$depositAmount · $storedDepositMethod', 'created_at': now,
        });
        await tx.insert('sync_outbox', {
          'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE',
          'payload': jsonEncode({
            'amount': depositAmount, 'method': storedDepositMethod, 'folio': folio,
            'breakdown': depositTender,
          }),
          'created_at': now,
        });
      }
      return orderId;
    });
  }

  Future<List<Map<String, Object?>>> orderParts(int orderId) =>
      db.query('order_parts', where: 'order_id=?', whereArgs: [orderId], orderBy: 'id DESC');

  Future<void> addOrderPart(
    int orderId,
    int itemId,
    double quantity, {
    double? unitPrice,
  }) async {
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('La cantidad debe ser mayor a cero y válida.');
    final now = _now();
    await db.transaction((tx) async {
      final orderRows = await tx.query(
        'service_orders',
        columns: ['folio', 'status', 'labor', 'parts_total', 'discount', 'paid', 'authorization_status'],
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw StateError('Orden no encontrada.');
      final orderRow = orderRows.first;
      final status = orderRow['status'] as String;
      if (orderRow['authorization_status'] != 'APPROVED') {
        throw StateError('Primero registra la autorización del cliente.');
      }
      if (status == 'ENTREGADO' || status == 'CANCELADO') {
        throw StateError('No se pueden agregar refacciones a una orden cerrada.');
      }

      final inventoryRows = await tx.query(
        'inventory_items',
        columns: ['name', 'stock', 'cost', 'price'],
        where: 'id=?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (inventoryRows.isEmpty) throw StateError('Artículo de inventario no encontrado.');
      final inventoryItem = inventoryRows.first;
      final stock = (inventoryItem['stock'] as num).toDouble();
      if (stock + 0.000001 < quantity) throw StateError('Existencia insuficiente para esta refacción.');

      final cost = (inventoryItem['cost'] as num).toDouble();
      final price = unitPrice ?? (inventoryItem['price'] as num).toDouble();
      if (!price.isFinite || price < 0) throw ArgumentError('El precio de venta debe ser válido y no negativo.');
      final normalizedPrice = FinancialRules.money(price);
      final lineTotal = FinancialRules.money(OrderPartAccounting.lineTotal(quantity, normalizedPrice));
      final newPartsTotal = (orderRow['parts_total'] as num).toDouble() + lineTotal;
      final labor = (orderRow['labor'] as num).toDouble();
      final discount = (orderRow['discount'] as num).toDouble();
      final newTotal = OrderPartAccounting.orderTotal(
        labor: labor, parts: newPartsTotal, discount: discount,
      );
      final alreadyPaid = (orderRow['paid'] as num).toDouble();
      if (newTotal + 0.01 < alreadyPaid) {
        throw StateError('El nuevo total no puede quedar por debajo de lo que ya se cobró.');
      }

      await tx.insert('order_parts', {
        'order_id': orderId,
        'item_id': itemId,
        'description': inventoryItem['name'],
        'quantity': quantity,
        'unit_cost': cost,
        'unit_price': normalizedPrice,
        'line_total': lineTotal,
        'created_at': now,
      });
      await tx.update('inventory_items', {
        'stock': stock - quantity, 'updated_at': now,
      }, where: 'id=?', whereArgs: [itemId]);
      await tx.insert('inventory_movements', {
        'item_id': itemId, 'movement_type': 'OUT',
        'quantity': quantity,
        'reason': 'Refacción en orden ${orderRow['folio']}',
        'related_order_id': orderId, 'created_at': now,
      });
      await tx.update('service_orders', {
        'parts_total': FinancialRules.money(newPartsTotal), 'total': FinancialRules.money(newTotal),
      }, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('audit_log', {
        'entity': 'service_order', 'entity_id': orderId,
        'action': 'PART_ADDED',
        'detail': '${inventoryItem['name']} · $quantity · $lineTotal',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'order_part', 'entity_id': orderId,
        'operation': 'CREATE',
        'payload': jsonEncode({
          'order_id': orderId, 'item_id': itemId,
          'quantity': quantity, 'unit_cost': cost,
          'unit_price': normalizedPrice, 'line_total': lineTotal,
        }),
        'created_at': now,
      });
    });
  }

  Future<void> authorizeOrder(
    int id, {
    required String authorizedBy,
    required String method,
    String note = '',
  }) async {
    if (authorizedBy.trim().isEmpty) {
      throw ArgumentError('Registra quién autorizó el servicio.');
    }
    const methods = {'PRESENCIAL', 'LLAMADA', 'WHATSAPP', 'OTRO'};
    final normalizedMethod = method.trim().toUpperCase();
    if (!methods.contains(normalizedMethod)) {
      throw ArgumentError('Selecciona un medio de autorización válido.');
    }
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query(
        'service_orders',
        columns: ['folio', 'status'],
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Orden no encontrada.');
      if (rows.first['status'] != 'ESPERA_AUTORIZACION') {
        throw StateError('La orden debe estar en espera de autorización para registrar el consentimiento.');
      }
      await tx.update('service_orders', {
        'authorization_status': 'APPROVED',
        'authorized_at': now,
        'authorized_by': authorizedBy.trim(),
        'authorization_method': normalizedMethod,
        'authorization_note': note.trim(),
      }, where: 'id=?', whereArgs: [id]);
      await tx.insert('order_events', {
        'order_id': id,
        'from_status': 'ESPERA_AUTORIZACION',
        'to_status': 'ESPERA_AUTORIZACION',
        'description': 'Autorización del cliente registrada · ${authorizedBy.trim()} · $normalizedMethod',
        'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'service_order',
        'entity_id': id,
        'action': 'CUSTOMER_AUTHORIZED',
        'detail': '${authorizedBy.trim()} · $normalizedMethod · ${note.trim()}',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'service_order',
        'entity_id': id,
        'operation': 'CUSTOMER_AUTHORIZED',
        'payload': jsonEncode({
          'authorized_by': authorizedBy.trim(),
          'method': normalizedMethod,
          'note': note.trim(),
          'authorized_at': now,
        }),
        'created_at': now,
      });
    });
  }

  Future<void> updateDiagnosis(int id, String diagnosis, String notes) async {
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query('service_orders',
        columns: ['status'], where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Orden no encontrada.');
      if (const {'ENTREGADO', 'CANCELADO'}.contains(rows.first['status'])) {
        throw StateError('No se puede modificar el diagnóstico de una orden cerrada.');
      }
      await tx.update('service_orders', {
        'diagnosis': diagnosis.trim(), 'notes': notes.trim(),
      }, where: 'id=?', whereArgs: [id]);
      await tx.insert('order_events', {
        'order_id': id, 'from_status': null, 'to_status': null,
        'description': 'Diagnóstico o notas actualizadas', 'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'service_order', 'entity_id': id,
        'action': 'DIAGNOSIS_UPDATE', 'detail': diagnosis.trim(),
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'service_order', 'entity_id': id,
        'operation': 'DIAGNOSIS_UPDATE',
        'payload': jsonEncode({'diagnosis': diagnosis.trim(), 'notes': notes.trim()}),
        'created_at': now,
      });
    });
  }

  Future<void> setOrderStatus(int id, String next, {String note = ''}) async {
    if (next == 'CANCELADO') {
      throw StateError('Usa la acción Cancelar orden para registrar motivo y reembolso.');
    }
    final current = await order(id);
    if (current == null) throw StateError('No se encontró el expediente.');
    final old = current['status'] as String;
    if (!OrderWorkflow.canTransition(old, next)) throw StateError('No se permite pasar de ${OrderWorkflow.label(old)} a ${OrderWorkflow.label(next)}.');
    if (old == next) return;
    if (const {'ESPERA_REFACCION', 'REPARACION'}.contains(next) &&
        current['authorization_status'] != 'APPROVED') {
      throw StateError('Primero registra la autorización del cliente.');
    }
    final now = _now();
    await db.transaction((tx) async {
      await tx.update('service_orders', {
        'status': next,
        if (next == 'ENTREGADO') 'delivered_at': now,
        if (next == 'ESPERA_AUTORIZACION') 'authorization_status': 'PENDING',
        if (next == 'ESPERA_AUTORIZACION') 'authorized_at': null,
        if (next == 'ESPERA_AUTORIZACION') 'authorized_by': '',
        if (next == 'ESPERA_AUTORIZACION') 'authorization_method': '',
        if (next == 'ESPERA_AUTORIZACION') 'authorization_note': '',
      }, where: 'id=?', whereArgs: [id]);
      await tx.insert('order_events', {'order_id': id, 'from_status': old, 'to_status': next, 'description': note.trim().isEmpty ? 'Estado actualizado' : note.trim(), 'created_at': now});
      if (next == 'LISTO') {
        await tx.insert('whatsapp_events', {'order_id': id, 'event_type': 'READY', 'message': 'Tu equipo está listo para recoger. Folio ${current['folio']}.', 'created_at': now});
      }
      if (next == 'ENTREGADO') {
        final days = (current['warranty_days'] as int?) ?? 30;
        final end = DateTime.parse(now).add(Duration(days: days)).toIso8601String();
        await tx.insert('warranties', {'order_id': id, 'starts_at': now, 'ends_at': end, 'days': days, 'terms': 'Garantía conforme a las condiciones registradas en el expediente.', 'status': 'VIGENTE'}, conflictAlgorithm: ConflictAlgorithm.ignore);
        await tx.insert('whatsapp_events', {'order_id': id, 'event_type': 'DELIVERED', 'message': 'Gracias por tu compra. Adjuntamos el comprobante y condiciones de garantía del folio ${current['folio']}.', 'created_at': now});
      }
      await tx.insert('audit_log', {'entity': 'service_order', 'entity_id': id, 'action': 'STATUS_CHANGE', 'detail': '$old → $next', 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'service_order', 'entity_id': id, 'operation': 'STATUS_CHANGE', 'payload': jsonEncode({'from': old, 'to': next, 'note': note}), 'created_at': now});
    });
  }

  Future<List<Map<String, Object?>>> orderPayments(int orderId) =>
      db.query('payments', where: 'order_id=?', whereArgs: [orderId], orderBy: 'id DESC');

  Future<List<Map<String, Object?>>> orderRefunds(int orderId) =>
      db.query('order_refunds', where: 'order_id=?', whereArgs: [orderId], orderBy: 'id DESC');

  Future<void> cancelOrder(
    int orderId, {
    required String refundMethod,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('Indica el motivo de cancelación.');
    final method = refundMethod.trim().toUpperCase();
    if (!FinancialRules.paymentMethods.contains(method)) {
      throw ArgumentError('Selecciona un medio de reembolso válido.');
    }
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query('service_orders',
        columns: ['folio', 'status', 'paid', 'refunded_total'],
        where: 'id=?', whereArgs: [orderId], limit: 1);
      if (rows.isEmpty) throw StateError('Orden no encontrada.');
      final row = rows.first;
      final status = row['status'] as String;
      if (status == 'CANCELADO') throw StateError('La orden ya está cancelada.');
      if (status == 'ENTREGADO') {
        throw StateError('Una orden entregada no se cancela desde este flujo. Atiéndela mediante garantía o devolución.');
      }
      final paid = (row['paid'] as num).toDouble();
      final previousRefunds = (row['refunded_total'] as num).toDouble();
      final refund = FinancialRules.money(
        (paid - previousRefunds).clamp(0.0, double.infinity).toDouble(),
      );
      if (refund > 0) {
        await tx.insert('order_refunds', {
          'order_id': orderId, 'amount': refund, 'method': method,
          'reason': reason.trim(), 'created_at': now,
        });
        await tx.insert('cash_movements', {
          'movement_type': 'OUT', 'amount': refund,
          'concept': 'Reembolso de orden ${row['folio']}',
          'reference': method, 'payment_method': method,
          'related_order_id': orderId, 'created_at': now,
        });
      }
      await tx.update('service_orders', {
        'status': 'CANCELADO',
        'paid': FinancialRules.money((paid - refund).clamp(0.0, double.infinity).toDouble()),
        'refunded_total': previousRefunds + refund,
      }, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('order_events', {
        'order_id': orderId, 'from_status': status, 'to_status': 'CANCELADO',
        'description': 'Orden cancelada · ${reason.trim()} · Reembolso ${refund.toStringAsFixed(2)}',
        'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'service_order', 'entity_id': orderId,
        'action': 'CANCEL_WITH_REFUND',
        'detail': '${row['folio']} · reembolso $refund · $method · ${reason.trim()}',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'service_order', 'entity_id': orderId,
        'operation': 'CANCEL_WITH_REFUND',
        'payload': jsonEncode({
          'folio': row['folio'], 'refund': refund,
          'method': method, 'reason': reason.trim(),
        }),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> orderEvents(int id) => db.query('order_events', where: 'order_id=?', whereArgs: [id], orderBy: 'id DESC');
  Future<List<Map<String, Object?>>> orderEvidence(int id) => db.query('evidences', where: 'order_id=?', whereArgs: [id], orderBy: 'id DESC');
  Future<void> addEvidence(int orderId, String path, String caption) async {
    final now = _now();
    final id = await db.insert('evidences', {'order_id': orderId, 'file_path': path, 'caption': caption, 'kind': 'photo', 'created_at': now});
    await _audit('evidence', id, 'CREATE', caption);
    await _outbox('evidence', id, 'CREATE', {'order_id': orderId, 'file_path': path, 'caption': caption});
  }

  Future<void> addOrderPayment(
    int orderId,
    double amount,
    String method, {
    String reference = '',
    String notes = '',
    List<Map<String, Object?>>? paymentBreakdown,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('El importe debe ser mayor a cero y válido.');
    }
    final tender = FinancialRules.normalizePayments(
      total: FinancialRules.money(amount),
      fallbackMethod: method,
      payments: paymentBreakdown,
    );
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query(
        'service_orders',
        columns: ['paid', 'total', 'folio', 'status'],
        where: 'id=?', whereArgs: [orderId], limit: 1,
      );
      if (rows.isEmpty) throw StateError('Orden no encontrada.');
      if (const {'CANCELADO', 'ENTREGADO'}.contains(rows.first['status'])) {
        throw StateError('No se pueden registrar pagos en una orden cerrada.');
      }
      final paid = (rows.first['paid'] as num).toDouble();
      final total = (rows.first['total'] as num).toDouble();
      if (FinancialRules.money(amount) > total - paid + 0.01) {
        throw StateError('El pago supera el saldo pendiente.');
      }
      final storedMethod = tender.length > 1 ? 'MIXTO' : tender.first['method'] as String;
      for (final part in tender) {
        final partMethod = part['method'] as String;
        final partAmount = part['amount'] as double;
        await tx.insert('payments', {
          'order_id': orderId, 'amount': partAmount, 'method': partMethod,
          'reference': reference.trim(), 'notes': notes.trim(), 'created_at': now,
        });
        await tx.insert('cash_movements', {
          'movement_type': 'IN', 'amount': partAmount,
          'concept': 'Pago de reparación ${rows.first['folio']}',
          'reference': reference.trim().isEmpty ? partMethod : reference.trim(),
          'created_at': now, 'related_order_id': orderId,
          'payment_method': partMethod,
        });
      }
      await tx.update('service_orders', {
        'paid': FinancialRules.money(paid + amount),
      }, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('audit_log', {
        'entity': 'payment', 'entity_id': orderId, 'action': 'CREATE',
        'detail': '${FinancialRules.money(amount)} · $storedMethod', 'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE',
        'payload': jsonEncode({
          'amount': FinancialRules.money(amount), 'method': storedMethod,
          'breakdown': tender, 'reference': reference.trim(),
        }),
        'created_at': now,
      });
    });
  }


}
