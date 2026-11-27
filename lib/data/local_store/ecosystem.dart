part of '../local_store.dart';

extension LocalStoreEcosystemOperations on LocalStore {
  Future<List<Map<String, Object?>>> globalSearch(
    String query, {
    int limit = 40,
  }) async {
    requirePermission('dashboard.view');
    final user = authenticatedUser;
    if (user == null) throw StateError('Inicia sesión para buscar en eShokFix.');

    final term = query.trim();
    if (term.length < 2) return [];
    final pattern = '%${term}%';
    final compactTerm = term.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final compactPattern = '%${compactTerm}%';
    final safeLimit = limit.clamp(1, 50).toInt();
    final results = <Map<String, Object?>>[];

    Future<void> append(String sql, List<Object?> args) async {
      final rows = await db.rawQuery(sql, [...args, safeLimit]);
      results.addAll(rows);
    }

    if (AuthService.can(user.role, 'clients.view')) {
      await append('''
        SELECT 'CLIENTE' type, c.id target_id, 'clientes' target_view,
               c.name title,
               TRIM(COALESCE(c.phone,'') || ' · ' || COALESCE(c.whatsapp,'')) subtitle,
               c.updated_at sort_date
        FROM clients c
        WHERE COALESCE(c.is_demo,0)=0
          AND (c.name LIKE ? COLLATE NOCASE OR COALESCE(c.phone,'') LIKE ?
            OR COALESCE(c.whatsapp,'') LIKE ? OR COALESCE(c.email,'') LIKE ?)
        ORDER BY c.updated_at DESC LIMIT ?
      ''', [pattern, pattern, pattern, pattern]);

      await append('''
        SELECT 'EQUIPO' type, c.id target_id, 'clientes' target_view,
               TRIM(COALESCE(d.brand,'') || ' ' || COALESCE(d.model,'')) title,
               c.name || ' · IMEI ' || COALESCE(d.imei,'') subtitle,
               d.created_at sort_date
        FROM devices d JOIN clients c ON c.id=d.client_id
        WHERE COALESCE(c.is_demo,0)=0
          AND (
            COALESCE(d.brand,'') LIKE ? COLLATE NOCASE
            OR COALESCE(d.model,'') LIKE ? COLLATE NOCASE
            OR COALESCE(d.imei,'') LIKE ?
            OR COALESCE(d.serial,'') LIKE ?
            OR COALESCE(d.color,'') LIKE ? COLLATE NOCASE
            OR COALESCE(d.accessories,'') LIKE ? COLLATE NOCASE
            OR COALESCE(d.condition_note,'') LIKE ? COLLATE NOCASE
            OR COALESCE(d.notes,'') LIKE ? COLLATE NOCASE
            OR c.name LIKE ? COLLATE NOCASE
            OR REPLACE(REPLACE(REPLACE(UPPER(COALESCE(d.brand,'') || COALESCE(d.model,'')), '-', ''), ' ', ''), '.', '') LIKE ?
            OR REPLACE(REPLACE(REPLACE(UPPER(COALESCE(d.imei,'')), '-', ''), ' ', ''), '.', '') LIKE ?
            OR REPLACE(REPLACE(REPLACE(UPPER(COALESCE(d.serial,'')), '-', ''), ' ', ''), '.', '') LIKE ?
          )
        ORDER BY d.id DESC LIMIT ?
      ''', [
        pattern, pattern, pattern, pattern, pattern, pattern,
        pattern, pattern, pattern, compactPattern, compactPattern, compactPattern,
      ]);
    }

    if (AuthService.can(user.role, 'orders.view')) {
      await append('''
        SELECT 'ORDEN' type, o.id target_id, 'ordenes' target_view,
               o.folio title,
               TRIM(COALESCE(d.brand,'') || ' ' || COALESCE(d.model,'') ||
                    ' · ' || c.name || ' · ' || o.status) subtitle,
               o.received_at sort_date
        FROM service_orders o
        JOIN clients c ON c.id=o.client_id
        LEFT JOIN devices d ON d.id=o.device_id
        WHERE COALESCE(o.is_demo,0)=0
          AND (o.folio LIKE ? OR c.name LIKE ? COLLATE NOCASE
            OR COALESCE(c.phone,'') LIKE ? OR COALESCE(d.brand,'') LIKE ?
            OR COALESCE(d.model,'') LIKE ? OR COALESCE(d.imei,'') LIKE ?
            OR COALESCE(d.serial,'') LIKE ? OR o.failure_description LIKE ?)
        ORDER BY o.id DESC LIMIT ?
      ''', [pattern, pattern, pattern, pattern, pattern, pattern, pattern, pattern]);
    }

    if (AuthService.can(user.role, 'inventory.view')) {
      await append('''
        SELECT 'PRODUCTO' type, i.id target_id, 'inventario' target_view,
               i.name title,
               TRIM(COALESCE(i.sku,'') || ' · ' || COALESCE(i.category,'')) subtitle,
               i.updated_at sort_date
        FROM inventory_items i
        WHERE COALESCE(i.is_demo,0)=0
          AND (i.name LIKE ? COLLATE NOCASE OR COALESCE(i.sku,'') LIKE ?
            OR COALESCE(i.category,'') LIKE ? COLLATE NOCASE)
        ORDER BY i.updated_at DESC LIMIT ?
      ''', [pattern, pattern, pattern]);
    }

    if (AuthService.can(user.role, 'purchases.view')) {
      await append('''
        SELECT 'PROVEEDOR' type, s.id target_id, 'compras' target_view,
               s.name title,
               TRIM(COALESCE(s.phone,'') || ' · ' || COALESCE(s.tax_id,'')) subtitle,
               s.updated_at sort_date
        FROM suppliers s
        WHERE s.name LIKE ? COLLATE NOCASE OR COALESCE(s.phone,'') LIKE ?
          OR COALESCE(s.whatsapp,'') LIKE ? OR COALESCE(s.tax_id,'') LIKE ?
        ORDER BY s.updated_at DESC LIMIT ?
      ''', [pattern, pattern, pattern, pattern]);

      await append('''
        SELECT 'COMPRA' type, p.id target_id, 'compras' target_view,
               p.folio title, s.name || ' · Saldo ' ||
                 printf('\$%.2f', MAX(0, p.total-p.paid)) subtitle,
               p.created_at sort_date
        FROM purchases p JOIN suppliers s ON s.id=p.supplier_id
        WHERE p.folio LIKE ? OR s.name LIKE ? COLLATE NOCASE
        ORDER BY p.created_at DESC LIMIT ?
      ''', [pattern, pattern]);
    }

    if (AuthService.can(user.role, 'sales.view')) {
      await append('''
        SELECT 'VENTA' type, s.id target_id, 'pos' target_view,
               s.folio title, COALESCE(c.name,'Venta general') subtitle,
               s.created_at sort_date
        FROM sales s LEFT JOIN clients c ON c.id=s.client_id
        WHERE s.folio LIKE ? OR COALESCE(c.name,'') LIKE ? COLLATE NOCASE
        ORDER BY s.created_at DESC LIMIT ?
      ''', [pattern, pattern]);
    }

    if (AuthService.can(user.role, 'warranties.view')) {
      await append('''
        SELECT 'GARANTIA' type, w.id target_id, 'garantias' target_view,
               o.folio title,
               c.name || ' · ' || COALESCE(d.brand,'') || ' ' || COALESCE(d.model,'') subtitle,
               w.starts_at sort_date
        FROM warranties w
        JOIN service_orders o ON o.id=w.order_id
        JOIN clients c ON c.id=o.client_id
        LEFT JOIN devices d ON d.id=o.device_id
        WHERE o.folio LIKE ? OR c.name LIKE ? COLLATE NOCASE
          OR COALESCE(d.imei,'') LIKE ? OR COALESCE(d.model,'') LIKE ?
        ORDER BY w.id DESC LIMIT ?
      ''', [pattern, pattern, pattern, pattern]);
    }

    results.sort((a, b) =>
      _sortDate(b['sort_date']).compareTo(_sortDate(a['sort_date'])));
    return results.take(safeLimit).toList(growable: false);
  }

  String _sortDate(Object? value) => value == null ? '' : value.toString();

  Future<void> refreshOperationalNotifications() async {
    requirePermission('dashboard.view');
    final now = DateTime.now().toIso8601String();
    await db.transaction((tx) async {
      final overdue = await tx.rawQuery('''
        SELECT o.id, o.folio, c.name client_name
        FROM service_orders o JOIN clients c ON c.id=o.client_id
        WHERE COALESCE(o.is_demo,0)=0
          AND COALESCE(o.estimated_delivery_at,'') <> ''
          AND o.estimated_delivery_at < ?
          AND o.status NOT IN ('ENTREGADO','CANCELADO')
      ''', [now]);
      for (final row in overdue) {
        final id = row['id'] as int;
        await tx.rawInsert('''
          INSERT INTO app_notifications
            (event_key,type,title,message,severity,target_view,target_id,
             required_permission,created_at)
          VALUES (?,?,?,?,?,?,?,?,?)
          ON CONFLICT(event_key) DO UPDATE SET
            title=excluded.title, message=excluded.message,
            severity=excluded.severity, resolved_at=NULL
        ''', [
          'ORDER_OVERDUE:$id', 'ORDER_OVERDUE', 'Orden fuera de fecha',
          'El folio ${row['folio']} de ${row['client_name']} superó su fecha estimada.',
          'WARNING', 'ordenes', id, 'orders.view', now,
        ]);
      }
      await tx.rawUpdate('''
        UPDATE app_notifications SET resolved_at=?
        WHERE type='ORDER_OVERDUE' AND resolved_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM service_orders o
            WHERE o.id=app_notifications.target_id
              AND COALESCE(o.estimated_delivery_at,'') <> ''
              AND o.estimated_delivery_at < ?
              AND o.status NOT IN ('ENTREGADO','CANCELADO')
          )
      ''', [now, now]);

      final lowStock = await tx.rawQuery('''
        SELECT id, name, stock, min_stock FROM inventory_items
        WHERE COALESCE(is_demo,0)=0 AND COALESCE(min_stock,0)>0
          AND COALESCE(stock,0)<=COALESCE(min_stock,0)
      ''');
      for (final row in lowStock) {
        final id = row['id'] as int;
        await tx.rawInsert('''
          INSERT INTO app_notifications
            (event_key,type,title,message,severity,target_view,target_id,
             required_permission,created_at)
          VALUES (?,?,?,?,?,?,?,?,?)
          ON CONFLICT(event_key) DO UPDATE SET
            title=excluded.title, message=excluded.message,
            severity=excluded.severity, resolved_at=NULL
        ''', [
          'LOW_STOCK:$id', 'LOW_STOCK', 'Existencia baja',
          '${row['name']}: quedan ${row['stock']} unidades; mínimo ${row['min_stock']}.',
          'WARNING', 'inventario', id, 'inventory.view', now,
        ]);
      }
      await tx.rawUpdate('''
        UPDATE app_notifications SET resolved_at=?
        WHERE type='LOW_STOCK' AND resolved_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM inventory_items i
            WHERE i.id=app_notifications.target_id
              AND COALESCE(i.is_demo,0)=0
              AND COALESCE(i.min_stock,0)>0
              AND COALESCE(i.stock,0)<=COALESCE(i.min_stock,0)
          )
      ''', [now]);

      final unpaidPurchases = await tx.rawQuery('''
        SELECT p.id, p.folio, p.total, p.paid, s.name supplier_name
        FROM purchases p JOIN suppliers s ON s.id=p.supplier_id
        WHERE COALESCE(p.total,0)>COALESCE(p.paid,0)+0.009
      ''');
      for (final row in unpaidPurchases) {
        final id = row['id'] as int;
        final balance = ((row['total'] as num).toDouble() -
            (row['paid'] as num).toDouble()).clamp(0.0, double.infinity).toDouble();
        await tx.rawInsert('''
          INSERT INTO app_notifications
            (event_key,type,title,message,severity,target_view,target_id,
             required_permission,created_at)
          VALUES (?,?,?,?,?,?,?,?,?)
          ON CONFLICT(event_key) DO UPDATE SET
            title=excluded.title, message=excluded.message,
            severity=excluded.severity, resolved_at=NULL
        ''', [
          'PURCHASE_BALANCE:$id', 'PURCHASE_BALANCE', 'Compra con saldo pendiente',
          'La compra ${row['folio']} de ${row['supplier_name']} tiene un saldo de \\${balance.toStringAsFixed(2)}.',
          'INFO', 'compras', id, 'purchases.view', now,
        ]);
      }
      await tx.rawUpdate('''
        UPDATE app_notifications SET resolved_at=?
        WHERE type='PURCHASE_BALANCE' AND resolved_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM purchases p
            WHERE p.id=app_notifications.target_id
              AND COALESCE(p.total,0)>COALESCE(p.paid,0)+0.009
          )
      ''', [now]);
    });
  }

  Future<List<Map<String, Object?>>> notifications({
    bool unreadOnly = false,
  }) async {
    requirePermission('dashboard.view');
    final user = authenticatedUser!;
    final rows = await db.query(
      'app_notifications',
      where: unreadOnly ? 'resolved_at IS NULL AND read_at IS NULL' : 'resolved_at IS NULL',
      orderBy: "CASE severity WHEN 'CRITICAL' THEN 0 WHEN 'WARNING' THEN 1 ELSE 2 END, created_at DESC",
      limit: 100,
    );
    return rows.where((row) => AuthService.can(
      user.role, (row['required_permission'] as String?) ?? 'dashboard.view',
    )).toList(growable: false);
  }

  Future<int> unreadNotificationCount() async {
    requirePermission('dashboard.view');
    final user = authenticatedUser!;
    final rows = await db.query(
      'app_notifications',
      columns: ['required_permission'],
      where: 'resolved_at IS NULL AND read_at IS NULL',
    );
    return rows.where((row) => AuthService.can(
      user.role, (row['required_permission'] as String?) ?? 'dashboard.view',
    )).length;
  }

  Future<void> markNotificationRead(int id) async {
    requirePermission('dashboard.view');
    final rows = await db.query(
      'app_notifications',
      columns: ['required_permission'],
      where: 'id=? AND resolved_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final permission = rows.first['required_permission'] as String? ?? 'dashboard.view';
    requirePermission(permission);
    await db.update(
      'app_notifications',
      {'read_at': _now()},
      where: 'id=? AND read_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> markAllNotificationsRead() async {
    requirePermission('dashboard.view');
    final rows = await notifications(unreadOnly: true);
    final now = _now();
    await db.transaction((tx) async {
      for (final row in rows) {
        await tx.update(
          'app_notifications',
          {'read_at': now},
          where: 'id=? AND read_at IS NULL',
          whereArgs: [row['id']],
        );
      }
    });
  }
}
