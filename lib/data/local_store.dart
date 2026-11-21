import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/workflow.dart';

Future<void> _createPurchaseTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE suppliers(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    whatsapp TEXT DEFAULT '',
    email TEXT DEFAULT '',
    tax_id TEXT DEFAULT '',
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''');
  await db.execute('''CREATE TABLE purchases(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    folio TEXT UNIQUE NOT NULL,
    supplier_id INTEGER NOT NULL,
    subtotal REAL NOT NULL,
    discount REAL NOT NULL DEFAULT 0,
    total REAL NOT NULL,
    paid REAL NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'PENDIENTE',
    payment_method TEXT NOT NULL DEFAULT 'EFECTIVO',
    notes TEXT DEFAULT '',
    received_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
  )''');
  await db.execute('''CREATE TABLE purchase_items(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    quantity REAL NOT NULL,
    unit_cost REAL NOT NULL,
    line_total REAL NOT NULL,
    FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
    FOREIGN KEY(item_id) REFERENCES inventory_items(id)
  )''');
  await db.execute('CREATE INDEX idx_purchases_supplier ON purchases(supplier_id)');
  await db.execute('CREATE INDEX idx_purchases_created ON purchases(created_at)');
  await db.execute('CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id)');
}

class LocalStore {
  LocalStore._(this.db);
  final Database db;
  static LocalStore? _instance;

  static Future<LocalStore> open() async {
    if (_instance != null) return _instance!;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'eshokfix_mobile_v1.db'),
      version: 2,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''CREATE TABLE clients(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT,
          whatsapp TEXT, email TEXT, address TEXT, notes TEXT,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL, is_demo INTEGER NOT NULL DEFAULT 0)''');
        batch.execute('''CREATE TABLE devices(
          id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER NOT NULL,
          brand TEXT, model TEXT, color TEXT, imei TEXT, serial TEXT,
          accessories TEXT, condition_note TEXT, notes TEXT, created_at TEXT NOT NULL,
          FOREIGN KEY(client_id) REFERENCES clients(id))''');
        batch.execute('''CREATE TABLE service_orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT, folio TEXT UNIQUE NOT NULL,
          client_id INTEGER NOT NULL, device_id INTEGER, status TEXT NOT NULL,
          failure_description TEXT NOT NULL, diagnosis TEXT DEFAULT '', technician TEXT DEFAULT '',
          received_at TEXT NOT NULL, estimated_delivery_at TEXT, delivered_at TEXT,
          labor REAL NOT NULL DEFAULT 0, parts_total REAL NOT NULL DEFAULT 0,
          discount REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0,
          paid REAL NOT NULL DEFAULT 0, deposit REAL NOT NULL DEFAULT 0,
          warranty_days INTEGER NOT NULL DEFAULT 30, notes TEXT DEFAULT '', is_demo INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(client_id) REFERENCES clients(id), FOREIGN KEY(device_id) REFERENCES devices(id))''');
        batch.execute('''CREATE TABLE order_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL,
          from_status TEXT, to_status TEXT, description TEXT, created_at TEXT NOT NULL,
          actor TEXT DEFAULT 'Administrador', FOREIGN KEY(order_id) REFERENCES service_orders(id) ON DELETE CASCADE)''');
        batch.execute('''CREATE TABLE evidences(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL,
          file_path TEXT NOT NULL, caption TEXT DEFAULT '', kind TEXT DEFAULT 'photo', created_at TEXT NOT NULL,
          FOREIGN KEY(order_id) REFERENCES service_orders(id) ON DELETE CASCADE)''');
        batch.execute('''CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER, amount REAL NOT NULL,
          method TEXT NOT NULL, reference TEXT DEFAULT '', notes TEXT DEFAULT '', created_at TEXT NOT NULL,
          FOREIGN KEY(order_id) REFERENCES service_orders(id))''');
        batch.execute('''CREATE TABLE inventory_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT, sku TEXT UNIQUE, name TEXT NOT NULL,
          category TEXT DEFAULT 'General', stock REAL NOT NULL DEFAULT 0,
          min_stock REAL NOT NULL DEFAULT 0, cost REAL NOT NULL DEFAULT 0,
          price REAL NOT NULL DEFAULT 0, location TEXT DEFAULT '', updated_at TEXT NOT NULL,
          is_demo INTEGER NOT NULL DEFAULT 0)''');
        batch.execute('''CREATE TABLE inventory_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL,
          movement_type TEXT NOT NULL, quantity REAL NOT NULL, reason TEXT DEFAULT '',
          related_order_id INTEGER, created_at TEXT NOT NULL,
          FOREIGN KEY(item_id) REFERENCES inventory_items(id))''');
        batch.execute('''CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT, folio TEXT UNIQUE NOT NULL,
          client_id INTEGER, subtotal REAL NOT NULL, discount REAL NOT NULL DEFAULT 0,
          total REAL NOT NULL, payment_method TEXT NOT NULL, amount_paid REAL NOT NULL,
          notes TEXT DEFAULT '', created_at TEXT NOT NULL,
          FOREIGN KEY(client_id) REFERENCES clients(id))''');
        batch.execute('''CREATE TABLE sale_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
          item_id INTEGER, description TEXT NOT NULL, quantity REAL NOT NULL,
          unit_price REAL NOT NULL, line_total REAL NOT NULL,
          FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
          FOREIGN KEY(item_id) REFERENCES inventory_items(id))''');
        batch.execute('''CREATE TABLE cash_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT, movement_type TEXT NOT NULL,
          amount REAL NOT NULL, concept TEXT NOT NULL, reference TEXT DEFAULT '',
          created_at TEXT NOT NULL, related_order_id INTEGER, related_sale_id INTEGER)''');
        batch.execute('''CREATE TABLE cash_cuts(
          id INTEGER PRIMARY KEY AUTOINCREMENT, opened_at TEXT NOT NULL,
          closed_at TEXT NOT NULL, expected REAL NOT NULL, counted REAL NOT NULL,
          difference REAL NOT NULL, notes TEXT DEFAULT '')''');
        batch.execute('''CREATE TABLE warranties(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL UNIQUE,
          starts_at TEXT NOT NULL, ends_at TEXT NOT NULL, days INTEGER NOT NULL,
          terms TEXT DEFAULT '', status TEXT NOT NULL DEFAULT 'VIGENTE',
          FOREIGN KEY(order_id) REFERENCES service_orders(id))''');
        batch.execute('''CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL,
          display_name TEXT NOT NULL, role TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL)''');
        batch.execute('''CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
        batch.execute('''CREATE TABLE audit_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id INTEGER,
          action TEXT NOT NULL, detail TEXT DEFAULT '', created_at TEXT NOT NULL, actor TEXT DEFAULT 'Administrador')''');
        batch.execute('''CREATE TABLE sync_outbox(
          id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id INTEGER,
          operation TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL,
          sync_state TEXT NOT NULL DEFAULT 'LOCAL_ONLY')''');
        batch.execute('''CREATE TABLE whatsapp_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL,
          event_type TEXT NOT NULL, message TEXT NOT NULL, created_at TEXT NOT NULL,
          delivery_state TEXT NOT NULL DEFAULT 'PENDING_CONFIGURATION',
          FOREIGN KEY(order_id) REFERENCES service_orders(id))''');
        batch.execute('CREATE INDEX idx_orders_status ON service_orders(status)');
        batch.execute('CREATE INDEX idx_orders_client ON service_orders(client_id)');
        batch.execute('CREATE INDEX idx_events_order ON order_events(order_id, created_at)');
        batch.execute('CREATE INDEX idx_cash_created ON cash_movements(created_at)');
        batch.execute('CREATE INDEX idx_outbox_state ON sync_outbox(sync_state)');
        await batch.commit(noResult: true);
        await _createPurchaseTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPurchaseTables(db);
        }
      },
    );
    _instance = LocalStore._(database);
    await _instance!._seedIfEmpty();
    return _instance!;
  }

  String _now() => DateTime.now().toIso8601String();
  String _moneyFolio(String prefix, int id) => '$prefix-${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}-${id.toString().padLeft(4, '0')}';

  Future<void> _seedIfEmpty() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM clients')) ?? 0;
    if (count > 0) return;
    await db.transaction((tx) async {
      final now = _now();
      await tx.insert('settings', {'key': 'shop_name', 'value': 'Computech · eShokFix'});
      await tx.insert('settings', {'key': 'currency', 'value': 'MXN'});
      await tx.insert('settings', {'key': 'default_warranty_days', 'value': '30'});
      await tx.insert('settings', {'key': 'demo_mode', 'value': '1'});
      await tx.insert('users', {'username': 'admin', 'display_name': 'Administrador', 'role': 'ADMIN', 'active': 1, 'created_at': now});
      final clientId = await tx.insert('clients', {
        'name': 'Cliente de demostración', 'phone': '8990000000',
        'whatsapp': '8990000000', 'email': 'demo@eshokfix.local',
        'address': 'Registro de prueba', 'notes': 'Datos ficticios para explorar la aplicación.',
        'created_at': now, 'updated_at': now, 'is_demo': 1,
      });
      final deviceId = await tx.insert('devices', {
        'client_id': clientId, 'brand': 'Samsung', 'model': 'Galaxy A26 5G',
        'color': 'Negro', 'imei': '', 'serial': '', 'accessories': 'Equipo solamente',
        'condition_note': 'Pantalla con marcas de uso', 'notes': 'Dispositivo demo', 'created_at': now,
      });
      final orderId = await tx.insert('service_orders', {
        'folio': 'EF-DEMO-001', 'client_id': clientId, 'device_id': deviceId,
        'status': 'DIAGNOSTICO', 'failure_description': 'No carga correctamente',
        'diagnosis': 'Revisar centro de carga y consumo.', 'technician': 'Técnico demo',
        'received_at': now, 'estimated_delivery_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'labor': 350, 'parts_total': 0, 'discount': 0, 'total': 350, 'paid': 100,
        'deposit': 100, 'warranty_days': 30, 'notes': 'Orden de demostración. No representa un cliente real.', 'is_demo': 1,
      });
      await tx.insert('order_events', {'order_id': orderId, 'from_status': null, 'to_status': 'RECIBIDO', 'description': 'Equipo recibido (demo)', 'created_at': now});
      await tx.insert('order_events', {'order_id': orderId, 'from_status': 'RECIBIDO', 'to_status': 'DIAGNOSTICO', 'description': 'Diagnóstico iniciado (demo)', 'created_at': now});
      await tx.insert('inventory_items', {'sku': 'DEMO-USB-C', 'name': 'Centro de carga USB-C (demo)', 'category': 'Refacciones', 'stock': 3, 'min_stock': 2, 'cost': 90, 'price': 180, 'location': 'A-01', 'updated_at': now, 'is_demo': 1});
      await tx.insert('inventory_items', {'sku': 'DEMO-CABLE', 'name': 'Cable USB-C (demo)', 'category': 'Accesorios', 'stock': 8, 'min_stock': 3, 'cost': 35, 'price': 90, 'location': 'B-02', 'updated_at': now, 'is_demo': 1});
    });
  }

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
    final orderCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM service_orders WHERE client_id=?', [id])) ?? 0;
    if (orderCount > 0) throw StateError('Este cliente tiene expedientes. No se puede eliminar; conserva su historial.');
    await db.delete('devices', where: 'client_id=?', whereArgs: [id]);
    await db.delete('clients', where: 'id=?', whereArgs: [id]);
    await _audit('client', id, 'DELETE', 'Cliente eliminado');
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

  Future<int> createOrder({required int clientId, required String brand, required String model, required String failure, required String condition, required String accessories, required String technician, double labor = 0, double parts = 0, double discount = 0, double deposit = 0, String notes = '', String imei = '', String serial = '', int warrantyDays = 30}) async {
    if (labor < 0 || parts < 0 || discount < 0 || deposit < 0 || warrantyDays < 0) {
      throw ArgumentError('Los importes y días de garantía no pueden ser negativos.');
    }
    final computedTotal = (labor + parts - discount).clamp(0, double.infinity).toDouble();
    if (deposit > computedTotal) throw ArgumentError('El anticipo no puede superar el total del servicio.');
    final clientExists = await db.query('clients', columns: ['id'], where: 'id=?', whereArgs: [clientId], limit: 1);
    if (clientExists.isEmpty) throw StateError('El cliente seleccionado ya no existe.');
    final now = _now();
    return db.transaction((tx) async {
      final deviceId = await tx.insert('devices', {'client_id': clientId, 'brand': brand.trim(), 'model': model.trim(), 'color': '', 'imei': imei.trim(), 'serial': serial.trim(), 'accessories': accessories.trim(), 'condition_note': condition.trim(), 'notes': '', 'created_at': now});
      final subtotal = computedTotal;
      final orderId = await tx.insert('service_orders', {'folio': 'PENDING-${DateTime.now().microsecondsSinceEpoch}', 'client_id': clientId, 'device_id': deviceId, 'status': 'RECIBIDO', 'failure_description': failure.trim(), 'diagnosis': '', 'technician': technician.trim(), 'received_at': now, 'estimated_delivery_at': null, 'delivered_at': null, 'labor': labor, 'parts_total': parts, 'discount': discount, 'total': subtotal < 0 ? 0 : subtotal, 'paid': 0, 'deposit': 0, 'warranty_days': warrantyDays, 'notes': notes.trim()});
      final folio = _moneyFolio('EF', orderId);
      await tx.update('service_orders', {'folio': folio}, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('order_events', {'order_id': orderId, 'from_status': null, 'to_status': 'RECIBIDO', 'description': 'Equipo recibido y registrado', 'created_at': now});
      await tx.insert('whatsapp_events', {'order_id': orderId, 'event_type': 'RECEIVED', 'message': 'Recibimos tu equipo. Folio $folio.', 'created_at': now});
      await tx.insert('audit_log', {'entity': 'service_order', 'entity_id': orderId, 'action': 'CREATE', 'detail': folio, 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'service_order', 'entity_id': orderId, 'operation': 'CREATE', 'payload': jsonEncode({'folio': folio, 'client_id': clientId}), 'created_at': now});
      if (deposit > 0) {
        await tx.insert('payments', {'order_id': orderId, 'amount': deposit, 'method': 'EFECTIVO', 'reference': '', 'notes': 'Anticipo de recepción', 'created_at': now});
        await tx.update('service_orders', {'paid': deposit, 'deposit': deposit}, where: 'id=?', whereArgs: [orderId]);
        await tx.insert('cash_movements', {'movement_type': 'IN', 'amount': deposit, 'concept': 'Anticipo $folio', 'reference': folio, 'created_at': now, 'related_order_id': orderId});
        await tx.insert('audit_log', {'entity': 'payment', 'entity_id': orderId, 'action': 'DEPOSIT', 'detail': '$deposit · EFECTIVO', 'created_at': now});
        await tx.insert('sync_outbox', {'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE', 'payload': jsonEncode({'amount': deposit, 'method': 'EFECTIVO', 'folio': folio}), 'created_at': now});
      }
      return orderId;
    });
  }

  Future<void> updateDiagnosis(int id, String diagnosis, String notes) async {
    final now = _now();
    await db.update('service_orders', {'diagnosis': diagnosis.trim(), 'notes': notes.trim()}, where: 'id=?', whereArgs: [id]);
    await db.insert('order_events', {'order_id': id, 'from_status': null, 'to_status': null, 'description': 'Diagnóstico o notas actualizadas', 'created_at': now});
    await _audit('service_order', id, 'DIAGNOSIS_UPDATE', diagnosis);
    await _outbox('service_order', id, 'DIAGNOSIS_UPDATE', {'diagnosis': diagnosis, 'notes': notes});
  }

  Future<void> setOrderStatus(int id, String next, {String note = ''}) async {
    final current = await order(id);
    if (current == null) throw StateError('No se encontró el expediente.');
    final old = current['status'] as String;
    if (!OrderWorkflow.canTransition(old, next)) throw StateError('No se permite pasar de ${OrderWorkflow.label(old)} a ${OrderWorkflow.label(next)}.');
    if (old == next) return;
    final now = _now();
    await db.transaction((tx) async {
      await tx.update('service_orders', {'status': next, if (next == 'ENTREGADO') 'delivered_at': now}, where: 'id=?', whereArgs: [id]);
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

  Future<List<Map<String, Object?>>> orderEvents(int id) => db.query('order_events', where: 'order_id=?', whereArgs: [id], orderBy: 'id DESC');
  Future<List<Map<String, Object?>>> orderEvidence(int id) => db.query('evidences', where: 'order_id=?', whereArgs: [id], orderBy: 'id DESC');
  Future<void> addEvidence(int orderId, String path, String caption) async {
    final now = _now();
    final id = await db.insert('evidences', {'order_id': orderId, 'file_path': path, 'caption': caption, 'kind': 'photo', 'created_at': now});
    await _audit('evidence', id, 'CREATE', caption);
    await _outbox('evidence', id, 'CREATE', {'order_id': orderId, 'file_path': path, 'caption': caption});
  }

  Future<void> addOrderPayment(int orderId, double amount, String method, {String reference = '', String notes = ''}) async {
    if (amount <= 0) throw ArgumentError('El importe debe ser mayor a cero.');
    final now = _now();
    await db.transaction((tx) async {
      final row = await tx.query('service_orders', columns: ['paid', 'total', 'folio'], where: 'id=?', whereArgs: [orderId], limit: 1);
      if (row.isEmpty) throw StateError('Orden no encontrada.');
      final paid = (row.first['paid'] as num).toDouble();
      final total = (row.first['total'] as num).toDouble();
      if (amount > total - paid + 0.01) throw StateError('El pago supera el saldo pendiente.');
      await tx.insert('payments', {'order_id': orderId, 'amount': amount, 'method': method, 'reference': reference, 'notes': notes, 'created_at': now});
      await tx.update('service_orders', {'paid': paid + amount}, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('cash_movements', {'movement_type': 'IN', 'amount': amount, 'concept': 'Pago de reparación ${row.first['folio']}', 'reference': reference, 'created_at': now, 'related_order_id': orderId});
      await tx.insert('audit_log', {'entity': 'payment', 'entity_id': orderId, 'action': 'CREATE', 'detail': '$amount · $method', 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE', 'payload': jsonEncode({'amount': amount, 'method': method, 'reference': reference}), 'created_at': now});
    });
  }

  Future<List<Map<String, Object?>>> inventory({String query = ''}) {
    final q = '%${query.trim()}%';
    return db.rawQuery('SELECT * FROM inventory_items WHERE name LIKE ? OR COALESCE(sku,\'\') LIKE ? ORDER BY name COLLATE NOCASE', [q, q]);
  }

  Future<int> saveInventoryItem({int? id, String sku = '', required String name, String category = 'General', double stock = 0, double minStock = 0, double cost = 0, double price = 0, String location = ''}) async {
    final now = _now();
    final data = {'sku': sku.trim().isEmpty ? null : sku.trim(), 'name': name.trim(), 'category': category.trim(), 'stock': stock, 'min_stock': minStock, 'cost': cost, 'price': price, 'location': location.trim(), 'updated_at': now};
    int itemId;
    if (id == null) { itemId = await db.insert('inventory_items', data); }
    else { await db.update('inventory_items', data, where: 'id=?', whereArgs: [id]); itemId = id; }
    if (id == null && stock != 0) await _inventoryMovement(itemId, stock, stock > 0 ? 'IN' : 'OUT', 'Existencia inicial');
    await _outbox('inventory_item', itemId, id == null ? 'CREATE' : 'UPDATE', data);
    return itemId;
  }

  Future<void> adjustInventory(int itemId, double quantity, String reason) async {
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

  Future<void> _inventoryMovement(int itemId, double quantity, String type, String reason) async {
    await db.insert('inventory_movements', {'item_id': itemId, 'movement_type': type, 'quantity': quantity.abs(), 'reason': reason, 'created_at': _now()});
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
    if (name.trim().isEmpty) throw ArgumentError('El nombre del proveedor es obligatorio.');
    final now = _now();
    final data = {
      'name': name.trim(), 'phone': phone.trim(), 'whatsapp': whatsapp.trim(),
      'email': email.trim(), 'tax_id': taxId.trim(), 'address': address.trim(),
      'notes': notes.trim(), 'updated_at': now,
    };
    final supplierId = id == null
        ? await db.insert('suppliers', {...data, 'created_at': now})
        : id;
    if (id != null) await db.update('suppliers', data, where: 'id=?', whereArgs: [id]);
    await _audit('supplier', supplierId, id == null ? 'CREATE' : 'UPDATE', name.trim());
    await _outbox('supplier', supplierId, id == null ? 'CREATE' : 'UPDATE', data);
    return supplierId;
  }

  Future<List<Map<String, Object?>>> purchases({String query = ''}) async {
    final q = '%${query.trim()}%';
    return db.rawQuery('''SELECT p.*, s.name supplier_name,
      (SELECT COUNT(*) FROM purchase_items pi WHERE pi.purchase_id=p.id) item_count
      FROM purchases p JOIN suppliers s ON s.id=p.supplier_id
      WHERE p.folio LIKE ? OR s.name LIKE ?
      ORDER BY p.id DESC''', [q, q]);
  }

  Future<List<Map<String, Object?>>> purchaseItems(int purchaseId) =>
      db.rawQuery('''SELECT pi.*, i.sku FROM purchase_items pi
      JOIN inventory_items i ON i.id=pi.item_id
      WHERE pi.purchase_id=? ORDER BY pi.id''', [purchaseId]);

  Future<int> createPurchase({
    required int supplierId,
    required List<Map<String, Object?>> items,
    double discount = 0,
    double paid = 0,
    String paymentMethod = 'EFECTIVO',
    String notes = '',
  }) async {
    if (items.isEmpty) throw ArgumentError('Agrega al menos un artículo a la compra.');
    if (discount < 0 || paid < 0) throw ArgumentError('Descuento y pago no pueden ser negativos.');
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
      if (quantity <= 0 || unitCost < 0) {
        throw ArgumentError('La cantidad debe ser mayor a cero y el costo no puede ser negativo.');
      }
      final lineTotal = PurchaseAccounting.lineTotal(quantity, unitCost);
      subtotal += lineTotal;
      prepared.add({
        'item_id': itemId,
        'quantity': quantity,
        'unit_cost': unitCost,
        'line_total': lineTotal,
      });
    }
    if (discount > subtotal) throw ArgumentError('El descuento no puede superar el subtotal.');
    final total = PurchaseAccounting.total(subtotal, discount);
    if (paid > total) throw ArgumentError('El pago inicial no puede superar el total de la compra.');
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
        'discount': discount,
        'total': total,
        'paid': paid,
        'payment_status': PurchaseAccounting.paymentStatus(total, paid),
        'payment_method': paymentMethod,
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
        await tx.update('inventory_items', {
          'stock': newStock, 'cost': unitCost, 'updated_at': now,
        }, where: 'id=?', whereArgs: [itemId]);
        await tx.insert('purchase_items', {
          'purchase_id': purchaseId, 'item_id': itemId,
          'description': current.first['name'],
          'quantity': quantity, 'unit_cost': unitCost,
          'line_total': line['line_total'],
        });
        await tx.insert('inventory_movements', {
          'item_id': itemId, 'movement_type': 'IN',
          'quantity': quantity, 'reason': 'Compra $folio',
          'created_at': now,
        });
      }
      if (paid > 0) {
        await tx.insert('cash_movements', {
          'movement_type': 'OUT', 'amount': paid,
          'concept': 'Pago de compra $folio', 'reference': paymentMethod,
          'created_at': now,
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
          'subtotal': subtotal, 'discount': discount,
          'total': total, 'paid': paid, 'items': prepared,
        }),
        'created_at': now,
      });
      return purchaseId;
    });
  }

  Future<void> recordPurchasePayment(
    int purchaseId, double amount, String method, {String reference = ''}
  ) async {
    if (amount <= 0) throw ArgumentError('El pago debe ser mayor a cero.');
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.query('purchases',
        columns: ['folio', 'total', 'paid'],
        where: 'id=?', whereArgs: [purchaseId], limit: 1);
      if (rows.isEmpty) throw StateError('Compra no encontrada.');
      final total = (rows.first['total'] as num).toDouble();
      final paid = (rows.first['paid'] as num).toDouble();
      if (amount > PurchaseAccounting.balance(total, paid) + 0.01) {
        throw StateError('El pago supera el saldo pendiente de la compra.');
      }
      final newPaid = paid + amount;
      await tx.update('purchases', {
        'paid': newPaid,
        'payment_status': PurchaseAccounting.paymentStatus(total, newPaid),
        'payment_method': method,
      }, where: 'id=?', whereArgs: [purchaseId]);
      await tx.insert('cash_movements', {
        'movement_type': 'OUT', 'amount': amount,
        'concept': 'Abono a compra ${rows.first['folio']}',
        'reference': reference.trim().isEmpty ? method : reference.trim(),
        'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'action': 'PAYMENT', 'detail': '$amount · $method',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'operation': 'PAYMENT',
        'payload': jsonEncode({'amount': amount, 'method': method, 'reference': reference}),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> sales() => db.rawQuery('''SELECT s.*, c.name client_name FROM sales s LEFT JOIN clients c ON c.id=s.client_id ORDER BY s.id DESC LIMIT 100''');
  Future<void> createSale({int? itemId, required String description, required double quantity, required double unitPrice, required String paymentMethod, double discount = 0, String notes = ''}) async {
    if (quantity <= 0 || unitPrice < 0 || discount < 0 || discount > quantity * unitPrice) throw ArgumentError('Revisa cantidad, importe y descuento.');
    final now = _now();
    await db.transaction((tx) async {
      if (itemId != null) {
        final items = await tx.query('inventory_items', columns: ['stock','name'], where: 'id=?', whereArgs: [itemId], limit: 1);
        if (items.isEmpty || (items.first['stock'] as num).toDouble() < quantity) throw StateError('Existencia insuficiente.');
        await tx.update('inventory_items', {'stock': (items.first['stock'] as num).toDouble() - quantity, 'updated_at': now}, where: 'id=?', whereArgs: [itemId]);
        await tx.insert('inventory_movements', {'item_id': itemId, 'movement_type': 'OUT', 'quantity': quantity, 'reason': 'Venta POS', 'created_at': now});
      }
      final subtotal = quantity * unitPrice;
      final total = (subtotal - discount).clamp(0, double.infinity).toDouble();
      final saleId = await tx.insert('sales', {'folio': 'PENDING-${DateTime.now().microsecondsSinceEpoch}', 'client_id': null, 'subtotal': subtotal, 'discount': discount, 'total': total, 'payment_method': paymentMethod, 'amount_paid': total, 'notes': notes, 'created_at': now});
      final folio = _moneyFolio('PV', saleId);
      await tx.update('sales', {'folio': folio}, where: 'id=?', whereArgs: [saleId]);
      await tx.insert('sale_items', {'sale_id': saleId, 'item_id': itemId, 'description': description, 'quantity': quantity, 'unit_price': unitPrice, 'line_total': subtotal});
      await tx.insert('cash_movements', {'movement_type': 'IN', 'amount': total, 'concept': 'Venta POS $folio', 'reference': paymentMethod, 'created_at': now, 'related_sale_id': saleId});
      await tx.insert('audit_log', {'entity': 'sale', 'entity_id': saleId, 'action': 'CREATE', 'detail': '$folio · $total', 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'sale', 'entity_id': saleId, 'operation': 'CREATE', 'payload': jsonEncode({'folio': folio, 'total': total, 'method': paymentMethod}), 'created_at': now});
    });
  }

  Future<Map<String, double>> cashSummary() async {
    final rows = await db.rawQuery('''SELECT COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE -amount END),0) balance,
      COALESCE(SUM(CASE WHEN movement_type='IN' THEN amount ELSE 0 END),0) income,
      COALESCE(SUM(CASE WHEN movement_type='OUT' THEN amount ELSE 0 END),0) expense FROM cash_movements
      WHERE created_at > COALESCE((SELECT MAX(closed_at) FROM cash_cuts),'0000-01-01')''');
    return {'balance': (rows.first['balance'] as num).toDouble(), 'income': (rows.first['income'] as num).toDouble(), 'expense': (rows.first['expense'] as num).toDouble()};
  }

  Future<void> addCashMovement({required bool income, required double amount, required String concept, String reference = ''}) async {
    if (amount <= 0) throw ArgumentError('El importe debe ser mayor a cero.');
    final now = _now();
    final id = await db.insert('cash_movements', {'movement_type': income ? 'IN' : 'OUT', 'amount': amount, 'concept': concept.trim(), 'reference': reference.trim(), 'created_at': now});
    await _audit('cash_movement', id, income ? 'IN' : 'OUT', '$amount · ${concept.trim()}');
    await _outbox('cash_movement', id, 'CREATE', {'amount': amount, 'type': income ? 'IN' : 'OUT', 'concept': concept.trim()});
  }

  Future<void> closeCashCut(double counted, String notes) async {
    final summary = await cashSummary();
    final now = _now();
    final id = await db.insert('cash_cuts', {'opened_at': 'Desde el corte anterior', 'closed_at': now, 'expected': summary['balance'], 'counted': counted, 'difference': counted - (summary['balance'] ?? 0), 'notes': notes});
    await _audit('cash_cut', id, 'CLOSE', 'Esperado ${summary['balance']} · contado $counted');
    await _outbox('cash_cut', id, 'CREATE', {'expected': summary['balance'], 'counted': counted, 'difference': counted - (summary['balance'] ?? 0)});
  }

  Future<List<Map<String, Object?>>> cashMovements() => db.query('cash_movements', orderBy: 'id DESC', limit: 100);
  Future<List<Map<String, Object?>>> cashCuts() => db.query('cash_cuts', orderBy: 'id DESC', limit: 30);
  Future<List<Map<String, Object?>>> warranties() => db.rawQuery('''SELECT w.*, o.folio, c.name client_name, d.brand, d.model FROM warranties w
    JOIN service_orders o ON o.id=w.order_id JOIN clients c ON c.id=o.client_id LEFT JOIN devices d ON d.id=o.device_id ORDER BY w.id DESC''');

  Future<Map<String, double>> reportTotals() async {
    final orders = await db.rawQuery("SELECT COALESCE(SUM(total),0) total, COALESCE(SUM(paid),0) paid, COUNT(*) count FROM service_orders WHERE status!='CANCELADO'");
    final sales = await db.rawQuery('SELECT COALESCE(SUM(total),0) total, COUNT(*) count FROM sales');
    final cash = await cashSummary();
    return {'orders_total': (orders.first['total'] as num).toDouble(), 'orders_paid': (orders.first['paid'] as num).toDouble(), 'orders_count': (orders.first['count'] as num).toDouble(), 'sales_total': (sales.first['total'] as num).toDouble(), 'sales_count': (sales.first['count'] as num).toDouble(), 'cash_balance': cash['balance'] ?? 0};
  }

  Future<List<Map<String, Object?>>> users() => db.query('users', orderBy: 'display_name');
  Future<void> saveUser({int? id, required String username, required String name, required String role, bool active = true}) async {
    final data = {'username': username.trim(), 'display_name': name.trim(), 'role': role, 'active': active ? 1 : 0, 'created_at': _now()};
    if (id == null) await db.insert('users', data); else await db.update('users', data, where: 'id=?', whereArgs: [id]);
  }
  Future<String> setting(String key, {String fallback = ''}) async {
    final rows = await db.query('settings', columns: ['value'], where: 'key=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }
  Future<void> saveSetting(String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> whatsappEvents() => db.rawQuery('''SELECT w.*, o.folio, c.name client_name FROM whatsapp_events w JOIN service_orders o ON o.id=w.order_id JOIN clients c ON c.id=o.client_id ORDER BY w.id DESC''');

  Future<Map<String, int>> demoDataCounts() async {
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
        await tx.delete('sync_outbox', where: 'entity_id=? AND entity IN (?,?)',
          whereArgs: [orderId, 'service_order', 'payment']);
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
        if (realOrders > 0) {
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
        if (sold > 0) {
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

  Future<void> _audit(String entity, int id, String action, String detail) async {
    await db.insert('audit_log', {'entity': entity, 'entity_id': id, 'action': action, 'detail': detail, 'created_at': _now()});
  }
  Future<void> _outbox(String entity, int id, String operation, Map<String, Object?> payload) async {
    await db.insert('sync_outbox', {'entity': entity, 'entity_id': id, 'operation': operation, 'payload': jsonEncode(payload), 'created_at': _now()});
  }
}
