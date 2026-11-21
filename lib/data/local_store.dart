import 'dart:convert';
import 'dart:io';
import 'database_backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/workflow.dart';
import '../domain/financial_rules.dart';

Future<void> _createOrderRefundTable(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS order_refunds(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    method TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(order_id) REFERENCES service_orders(id) ON DELETE CASCADE
  )''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_order_refunds_order ON order_refunds(order_id)');
}

Future<void> _createFinancialTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS sale_payments(
    id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
    method TEXT NOT NULL, amount REAL NOT NULL, reference TEXT DEFAULT '',
    created_at TEXT NOT NULL,
    FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS purchase_payments(
    id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL,
    method TEXT NOT NULL, amount REAL NOT NULL, reference TEXT DEFAULT '',
    created_at TEXT NOT NULL,
    FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS sale_returns(
    id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
    amount REAL NOT NULL, refund_method TEXT NOT NULL, reason TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS sale_return_items(
    id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL,
    sale_item_id INTEGER NOT NULL, quantity REAL NOT NULL, amount REAL NOT NULL,
    FOREIGN KEY(return_id) REFERENCES sale_returns(id) ON DELETE CASCADE,
    FOREIGN KEY(sale_item_id) REFERENCES sale_items(id)
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS purchase_returns(
    id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL,
    amount REAL NOT NULL, cash_refund REAL NOT NULL DEFAULT 0,
    refund_method TEXT NOT NULL DEFAULT 'SALDO_PROVEEDOR',
    reason TEXT NOT NULL, created_at TEXT NOT NULL,
    FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS purchase_return_items(
    id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL,
    purchase_item_id INTEGER NOT NULL, item_id INTEGER NOT NULL,
    quantity REAL NOT NULL, unit_cost REAL NOT NULL, line_total REAL NOT NULL,
    FOREIGN KEY(return_id) REFERENCES purchase_returns(id) ON DELETE CASCADE,
    FOREIGN KEY(purchase_item_id) REFERENCES purchase_items(id),
    FOREIGN KEY(item_id) REFERENCES inventory_items(id)
  )''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_payments_sale ON sale_payments(sale_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_payments_purchase ON purchase_payments(purchase_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_returns_sale ON sale_returns(sale_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_returns_purchase ON purchase_returns(purchase_id)');
}

Future<void> _createOrderPartsTable(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE order_parts(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    quantity REAL NOT NULL,
    unit_cost REAL NOT NULL,
    unit_price REAL NOT NULL,
    line_total REAL NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(order_id) REFERENCES service_orders(id) ON DELETE CASCADE,
    FOREIGN KEY(item_id) REFERENCES inventory_items(id)
  )''');
  await db.execute('CREATE INDEX idx_order_parts_order ON order_parts(order_id)');
}

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
    status TEXT NOT NULL DEFAULT 'RECEIVED',
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
    received_quantity REAL NOT NULL DEFAULT 0,
    unit_cost REAL NOT NULL,
    line_total REAL NOT NULL,
    returned_quantity REAL NOT NULL DEFAULT 0,
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
      version: 8,
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
          refunded_total REAL NOT NULL DEFAULT 0,
          warranty_days INTEGER NOT NULL DEFAULT 30, notes TEXT DEFAULT '', is_demo INTEGER NOT NULL DEFAULT 0,
          authorization_status TEXT NOT NULL DEFAULT 'PENDING', authorized_at TEXT,
          authorized_by TEXT DEFAULT '', authorization_method TEXT DEFAULT '', authorization_note TEXT DEFAULT '',
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
          status TEXT NOT NULL DEFAULT 'COMPLETED', refunded_total REAL NOT NULL DEFAULT 0,
          notes TEXT DEFAULT '', created_at TEXT NOT NULL,
          FOREIGN KEY(client_id) REFERENCES clients(id))''');
        batch.execute('''CREATE TABLE sale_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
          item_id INTEGER, description TEXT NOT NULL, quantity REAL NOT NULL,
          unit_price REAL NOT NULL, line_total REAL NOT NULL, returned_quantity REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
          FOREIGN KEY(item_id) REFERENCES inventory_items(id))''');
        batch.execute('''CREATE TABLE cash_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT, movement_type TEXT NOT NULL,
          amount REAL NOT NULL, concept TEXT NOT NULL, reference TEXT DEFAULT '',
          created_at TEXT NOT NULL, related_order_id INTEGER, related_sale_id INTEGER,
          payment_method TEXT NOT NULL DEFAULT 'EFECTIVO')''');
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
        await _createOrderPartsTable(db);
        await _createFinancialTables(db);
        await _createOrderRefundTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPurchaseTables(db);
        }
        if (oldVersion < 3) {
          await _createOrderPartsTable(db);
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE service_orders ADD COLUMN authorization_status TEXT NOT NULL DEFAULT 'PENDING'");
          await db.execute("ALTER TABLE service_orders ADD COLUMN authorized_at TEXT");
          await db.execute("ALTER TABLE service_orders ADD COLUMN authorized_by TEXT DEFAULT ''");
          await db.execute("ALTER TABLE service_orders ADD COLUMN authorization_method TEXT DEFAULT ''");
          await db.execute("ALTER TABLE service_orders ADD COLUMN authorization_note TEXT DEFAULT ''");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE cash_movements ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'EFECTIVO'");
          await db.execute("UPDATE cash_movements SET payment_method=UPPER(reference) WHERE UPPER(COALESCE(reference,'')) IN ('TRANSFERENCIA','TARJETA','OTRO')");
        }
        if (oldVersion < 6) {
          await db.execute("ALTER TABLE sales ADD COLUMN status TEXT NOT NULL DEFAULT 'COMPLETED'");
          await db.execute("ALTER TABLE sales ADD COLUMN refunded_total REAL NOT NULL DEFAULT 0");
          await db.execute("ALTER TABLE sale_items ADD COLUMN returned_quantity REAL NOT NULL DEFAULT 0");
          if (oldVersion >= 2) {
            await db.execute("ALTER TABLE purchases ADD COLUMN status TEXT NOT NULL DEFAULT 'RECEIVED'");
            await db.execute("ALTER TABLE purchase_items ADD COLUMN returned_quantity REAL NOT NULL DEFAULT 0");
          }
          await _createFinancialTables(db);
          await db.execute("""INSERT INTO sale_payments(sale_id, method, amount, reference, created_at)
            SELECT id, payment_method, amount_paid, '', created_at FROM sales WHERE amount_paid > 0""");
          await db.execute("""INSERT INTO purchase_payments(purchase_id, method, amount, reference, created_at)
            SELECT id, payment_method, paid, 'Registro histórico migrado', created_at
            FROM purchases WHERE paid > 0""");
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE service_orders ADD COLUMN refunded_total REAL NOT NULL DEFAULT 0");
          await _createOrderRefundTable(db);
        }
        if (oldVersion < 8 && oldVersion >= 2) {
          await db.execute("ALTER TABLE purchase_items ADD COLUMN received_quantity REAL NOT NULL DEFAULT 0");
          await db.execute("UPDATE purchase_items SET received_quantity=quantity");
        }
      },
    );
    _instance = LocalStore._(database);
    await _instance!._seedIfEmpty();
    return _instance!;
  }

  Future<String?> exportBackup() async {
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final root = await getDatabasesPath();
    final source = File(p.join(root, 'eshokfix_mobile_v1.db'));
    if (!await source.exists()) throw StateError('No se encontró la base local de eShokFix.');
    final safeName = 'eShokFix-backup-${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.db';
    return DatabaseBackupService().exportDatabase(
      sourcePath: source.path,
      suggestedName: safeName,
    );
  }

  Future<void> restoreBackup(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() < 512) {
      throw ArgumentError('El archivo seleccionado no parece una copia de eShokFix.');
    }

    final verification = await openDatabase(
      source.path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final integrity = await verification.rawQuery('PRAGMA quick_check');
      final check = integrity.isEmpty ? '' : integrity.first.values.first.toString().toLowerCase();
      if (check != 'ok') throw StateError('La copia no pasó la verificación de integridad de SQLite.');
      final versionRows = await verification.rawQuery('PRAGMA user_version');
      final version = (versionRows.first.values.first as num).toInt();
      if (version < 1 || version > 6) {
        throw StateError('La versión de la copia ($version) no es compatible con esta app.');
      }
      final requiredTables = await verification.rawQuery('''
        SELECT COUNT(*) total FROM sqlite_master
        WHERE type='table' AND name IN ('clients','service_orders','inventory_items','sales','settings')
      ''');
      if ((requiredTables.first['total'] as num).toInt() != 5) {
        throw StateError('La copia no contiene las tablas principales de eShokFix.');
      }
    } finally {
      await verification.close();
    }

    final root = await getDatabasesPath();
    final target = File(p.join(root, 'eshokfix_mobile_v1.db'));
    final staged = File('${target.path}.restore');
    final rollback = File('${target.path}.rollback');
    await source.copy(staged.path);
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await db.close();

    try {
      if (await rollback.exists()) await rollback.delete();
      if (await target.exists()) await target.rename(rollback.path);
      await staged.rename(target.path);
      _instance = null;
      await LocalStore.open();
      if (await rollback.exists()) await rollback.delete();
    } catch (error) {
      _instance = null;
      if (await target.exists()) await target.delete();
      if (await rollback.exists()) await rollback.rename(target.path);
      rethrow;
    } finally {
      if (await staged.exists()) await staged.delete();
    }
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
    if (![labor, parts, discount, deposit].every((value) => value.isFinite)) {
      throw ArgumentError('Los importes deben ser números válidos.');
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
        await tx.insert('cash_movements', {'movement_type': 'IN', 'amount': deposit, 'concept': 'Anticipo $folio', 'reference': folio, 'created_at': now, 'related_order_id': orderId, 'payment_method': 'EFECTIVO'});
        await tx.insert('audit_log', {'entity': 'payment', 'entity_id': orderId, 'action': 'DEPOSIT', 'detail': '$deposit · EFECTIVO', 'created_at': now});
        await tx.insert('sync_outbox', {'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE', 'payload': jsonEncode({'amount': deposit, 'method': 'EFECTIVO', 'folio': folio}), 'created_at': now});
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
    if (quantity <= 0) throw ArgumentError('La cantidad debe ser mayor a cero.');
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
      if (stock < quantity) throw StateError('Existencia insuficiente para esta refacción.');

      final cost = (inventoryItem['cost'] as num).toDouble();
      final price = unitPrice ?? (inventoryItem['price'] as num).toDouble();
      if (price < 0) throw ArgumentError('El precio de venta no puede ser negativo.');
      final lineTotal = OrderPartAccounting.lineTotal(quantity, price);
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
        'unit_price': price,
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
        'parts_total': newPartsTotal, 'total': newTotal,
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
          'unit_price': price, 'line_total': lineTotal,
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
        'authorization_method': method,
        'authorization_note': note.trim(),
      }, where: 'id=?', whereArgs: [id]);
      await tx.insert('order_events', {
        'order_id': id,
        'from_status': 'ESPERA_AUTORIZACION',
        'to_status': 'ESPERA_AUTORIZACION',
        'description': 'Autorización del cliente registrada · ${authorizedBy.trim()} · $method',
        'created_at': now,
      });
      await tx.insert('audit_log', {
        'entity': 'service_order',
        'entity_id': id,
        'action': 'CUSTOMER_AUTHORIZED',
        'detail': '${authorizedBy.trim()} · $method · ${note.trim()}',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'service_order',
        'entity_id': id,
        'operation': 'CUSTOMER_AUTHORIZED',
        'payload': jsonEncode({
          'authorized_by': authorizedBy.trim(),
          'method': method,
          'note': note.trim(),
          'authorized_at': now,
        }),
        'created_at': now,
      });
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

  Future<void> addOrderPayment(int orderId, double amount, String method, {String reference = '', String notes = ''}) async {
    if (!amount.isFinite || amount <= 0) throw ArgumentError('El importe debe ser mayor a cero y válido.');
    if (!FinancialRules.paymentMethods.contains(method.trim().toUpperCase())) throw ArgumentError('Medio de pago no válido.');
    final now = _now();
    await db.transaction((tx) async {
      final row = await tx.query('service_orders', columns: ['paid', 'total', 'folio'], where: 'id=?', whereArgs: [orderId], limit: 1);
      if (row.isEmpty) throw StateError('Orden no encontrada.');
      final orderState = await tx.query('service_orders', columns: ['status'], where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orderState.isEmpty || const {'CANCELADO', 'ENTREGADO'}.contains(orderState.first['status'])) throw StateError('No se pueden registrar pagos en una orden cerrada.');
      final paid = (row.first['paid'] as num).toDouble();
      final total = (row.first['total'] as num).toDouble();
      if (amount > total - paid + 0.01) throw StateError('El pago supera el saldo pendiente.');
      await tx.insert('payments', {'order_id': orderId, 'amount': amount, 'method': method, 'reference': reference, 'notes': notes, 'created_at': now});
      await tx.update('service_orders', {'paid': paid + amount}, where: 'id=?', whereArgs: [orderId]);
      await tx.insert('cash_movements', {'movement_type': 'IN', 'amount': amount, 'concept': 'Pago de reparación ${row.first['folio']}', 'reference': reference, 'created_at': now, 'related_order_id': orderId, 'payment_method': method});
      await tx.insert('audit_log', {'entity': 'payment', 'entity_id': orderId, 'action': 'CREATE', 'detail': '$amount · $method', 'created_at': now});
      await tx.insert('sync_outbox', {'entity': 'payment', 'entity_id': orderId, 'operation': 'CREATE', 'payload': jsonEncode({'amount': amount, 'method': method, 'reference': reference}), 'created_at': now});
    });
  }

  Future<List<Map<String, Object?>>> inventory({String query = ''}) {
    final q = '%${query.trim()}%';
    return db.rawQuery('SELECT * FROM inventory_items WHERE name LIKE ? OR COALESCE(sku,\'\') LIKE ? ORDER BY name COLLATE NOCASE', [q, q]);
  }

  Future<int> saveInventoryItem({int? id, String sku = '', required String name, String category = 'General', double stock = 0, double minStock = 0, double cost = 0, double price = 0, String location = ''}) async {
    if (name.trim().isEmpty) throw ArgumentError('El nombre del artículo es obligatorio.');
    if (!stock.isFinite || !minStock.isFinite || !cost.isFinite || !price.isFinite ||
        stock < 0 || minStock < 0 || cost < 0 || price < 0) {
      throw ArgumentError('Existencia, mínimo, costo y precio deben ser importes válidos no negativos.');
    }
    final now = _now();
    final data = {
      'sku': sku.trim().isEmpty ? null : sku.trim(),
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'min_stock': minStock,
      'cost': cost,
      'price': price,
      'location': location.trim(),
      'updated_at': now,
    };
    int itemId;
    if (id == null) {
      itemId = await db.insert('inventory_items', {...data, 'stock': stock});
      if (stock > 0) await _inventoryMovement(itemId, stock, 'IN', 'Existencia inicial');
      await _audit('inventory_item', itemId, 'CREATE', name.trim());
    } else {
      final exists = await db.query('inventory_items', columns: ['id'],
        where: 'id=?', whereArgs: [id], limit: 1);
      if (exists.isEmpty) throw StateError('Artículo de inventario no encontrado.');
      await db.update('inventory_items', data, where: 'id=?', whereArgs: [id]);
      itemId = id;
      await _audit('inventory_item', itemId, 'UPDATE', name.trim());
    }
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
    List<Map<String, Object?>>? paymentBreakdown,
    bool receiveImmediately = true,
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
    final tender = FinancialRules.normalizePayments(
      total: paid, fallbackMethod: paymentMethod, payments: paymentBreakdown,
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
        'discount': discount,
        'total': total,
        'paid': paid,
        'payment_status': PurchaseAccounting.paymentStatus(total, paid),
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
          'subtotal': subtotal, 'discount': discount,
          'total': total, 'paid': paid, 'status': receiveImmediately ? 'RECEIVED' : 'ORDERED',
          'payment_breakdown': tender, 'items': prepared,
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
      await tx.insert('purchase_payments', {
        'purchase_id': purchaseId, 'method': method, 'amount': amount,
        'reference': reference.trim(), 'created_at': now,
      });
      await tx.insert('cash_movements', {
        'movement_type': 'OUT', 'amount': amount,
        'concept': 'Abono a compra ${rows.first['folio']}',
        'reference': reference.trim().isEmpty ? method : reference.trim(),
        'payment_method': method, 'created_at': now,
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
  Future<List<Map<String, Object?>>> salePayments(int saleId) => db.query(
    'sale_payments', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id');
  Future<List<Map<String, Object?>>> saleReturns(int saleId) => db.query(
    'sale_returns', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id DESC');
  Future<List<Map<String, Object?>>> purchasePayments(int purchaseId) => db.query(
    'purchase_payments', where: 'purchase_id=?', whereArgs: [purchaseId], orderBy: 'id');
  Future<List<Map<String, Object?>>> purchaseReturns(int purchaseId) => db.query(
    'purchase_returns', where: 'purchase_id=?', whereArgs: [purchaseId], orderBy: 'id DESC');
  Future<void> createSale({int? itemId, required String description, required double quantity, required double unitPrice, required String paymentMethod, double discount = 0, String notes = ''}) async {
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

  Future<List<Map<String, Object?>>> saleItems(int saleId) =>
      db.query('sale_items', where: 'sale_id=?', whereArgs: [saleId], orderBy: 'id');

  Future<int> createSaleCart({
    int? clientId,
    required List<Map<String, Object?>> items,
    required String paymentMethod,
    double discount = 0,
    List<Map<String, Object?>>? paymentBreakdown,
    String notes = '',
  }) async {
    if (items.isEmpty) throw ArgumentError('Agrega al menos un producto o servicio.');
    if (discount < 0) throw ArgumentError('El descuento no puede ser negativo.');

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
      if (quantity <= 0 || unitPrice < 0 || (itemId != null && itemId is! int)) {
        throw ArgumentError('Revisa la cantidad, precio y artículo de cada partida.');
      }
      final lineTotal = quantity * unitPrice;
      subtotal += lineTotal;
      prepared.add({
        'item_id': itemId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_total': lineTotal,
      });
    }
    if (discount > subtotal) throw ArgumentError('El descuento no puede superar el subtotal.');
    final total = (subtotal - discount).clamp(0.0, double.infinity).toDouble();
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
        'discount': discount,
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
          'discount': discount, 'total': total, 'method': storedMethod,
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

  Future<void> receivePurchaseItem(
    int purchaseId,
    int purchaseItemId,
    double quantity,
  ) async {
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('La cantidad recibida debe ser mayor a cero.');
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.rawQuery('''SELECT pi.*, p.folio, p.status purchase_status,
          i.name item_name, i.stock
        FROM purchase_items pi
        JOIN purchases p ON p.id=pi.purchase_id
        JOIN inventory_items i ON i.id=pi.item_id
        WHERE pi.id=? AND pi.purchase_id=?''', [purchaseItemId, purchaseId]);
      if (rows.isEmpty) throw StateError('No se encontró la partida de compra.');
      final row = rows.first;
      if (row['purchase_status'] == 'CANCELLED') throw StateError('La compra está cancelada.');
      final ordered = (row['quantity'] as num).toDouble();
      final received = (row['received_quantity'] as num).toDouble();
      final pending = FinancialRules.remainingQuantity(ordered, received);
      if (quantity > pending + 0.000001) {
        throw StateError('La cantidad supera lo pendiente por recibir.');
      }
      final stock = (row['stock'] as num).toDouble();
      final itemId = row['item_id'] as int;
      await tx.update('inventory_items', {
        'stock': stock + quantity, 'cost': row['unit_cost'], 'updated_at': now,
      }, where: 'id=?', whereArgs: [itemId]);
      await tx.update('purchase_items', {
        'received_quantity': received + quantity,
      }, where: 'id=?', whereArgs: [purchaseItemId]);
      await tx.insert('inventory_movements', {
        'item_id': itemId, 'movement_type': 'IN', 'quantity': quantity,
        'reason': 'Recepción de compra ${row['folio']}', 'created_at': now,
      });
      final remainingRows = await tx.rawQuery('''SELECT COUNT(*) pending
        FROM purchase_items WHERE purchase_id=?
        AND received_quantity < quantity - 0.000001''', [purchaseId]);
      final allReceived = (remainingRows.first['pending'] as num).toInt() == 0;
      await tx.update('purchases', {
        'status': allReceived ? 'RECEIVED' : 'PARTIAL_RECEIVED',
        'received_at': now,
      }, where: 'id=?', whereArgs: [purchaseId]);
      await tx.insert('audit_log', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'action': 'RECEIVE_ITEMS',
        'detail': '${row['item_name']} · $quantity · ${row['folio']}',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'purchase', 'entity_id': purchaseId,
        'operation': 'RECEIVE_ITEMS',
        'payload': jsonEncode({
          'purchase_id': purchaseId, 'purchase_item_id': purchaseItemId,
          'item_id': itemId, 'quantity': quantity,
        }),
        'created_at': now,
      });
    });
  }

  Future<void> returnPurchaseItem({
    required int purchaseId,
    required int purchaseItemId,
    required double quantity,
    String refundMethod = 'EFECTIVO',
    required String reason,
  }) async {
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('La cantidad a devolver debe ser mayor a cero.');
    if (reason.trim().isEmpty) throw ArgumentError('Indica el motivo de la devolución.');
    final method = refundMethod.trim().toUpperCase();
    if (!FinancialRules.paymentMethods.contains(method)) throw ArgumentError('Selecciona un medio de reembolso válido.');
    final now = _now();
    await db.transaction((tx) async {
      final rows = await tx.rawQuery('''SELECT pi.*, i.stock,
          p.folio, p.subtotal purchase_subtotal, p.total purchase_total, p.paid purchase_paid
        FROM purchase_items pi JOIN purchases p ON p.id=pi.purchase_id
        JOIN inventory_items i ON i.id=pi.item_id
        WHERE pi.id=? AND pi.purchase_id=?''', [purchaseItemId, purchaseId]);
      if (rows.isEmpty) throw StateError('No se encontró la partida de compra.');
      final row = rows.first;
      final received = (row['received_quantity'] as num).toDouble();
      final returned = (row['returned_quantity'] as num).toDouble();
      final remaining = FinancialRules.remainingQuantity(received, returned);
      if (quantity > remaining + 0.000001) throw StateError('La cantidad supera lo recibido y aún disponible para devolución.');
      final stock = (row['stock'] as num).toDouble();
      if (stock + 0.000001 < quantity) throw StateError('No hay existencias suficientes para devolver esta cantidad al proveedor.');
      final unitCost = (row['unit_cost'] as num).toDouble();
      final amount = FinancialRules.saleLineRefund(
        quantity: quantity,
        unitPrice: unitCost,
        saleSubtotal: (row['purchase_subtotal'] as num).toDouble(),
        saleTotal: (row['purchase_total'] as num).toDouble(),
      );
      final oldTotal = (row['purchase_total'] as num).toDouble();
      final oldPaid = (row['purchase_paid'] as num).toDouble();
      final newTotal = FinancialRules.money((oldTotal - amount).clamp(0.0, double.infinity).toDouble());
      final cashRefund = FinancialRules.supplierCashRefund(
        purchaseTotal: oldTotal, paid: oldPaid, returnAmount: amount,
      );
      final newPaid = FinancialRules.money((oldPaid - cashRefund).clamp(0.0, newTotal).toDouble());
      final returnId = await tx.insert('purchase_returns', {
        'purchase_id': purchaseId, 'amount': amount, 'cash_refund': cashRefund,
        'refund_method': cashRefund > 0 ? method : 'SALDO_PROVEEDOR',
        'reason': reason.trim(), 'created_at': now,
      });
      await tx.insert('purchase_return_items', {
        'return_id': returnId, 'purchase_item_id': purchaseItemId,
        'item_id': row['item_id'], 'quantity': quantity,
        'unit_cost': unitCost, 'line_total': amount,
      });
      await tx.update('purchase_items', {'returned_quantity': returned + quantity},
        where: 'id=?', whereArgs: [purchaseItemId]);
      await tx.update('inventory_items', {'stock': stock - quantity, 'updated_at': now},
        where: 'id=?', whereArgs: [row['item_id']]);
      await tx.insert('inventory_movements', {
        'item_id': row['item_id'], 'movement_type': 'OUT', 'quantity': quantity,
        'reason': 'Devolución a proveedor ${row['folio']}', 'created_at': now,
      });
      await tx.update('purchases', {
        'total': newTotal, 'paid': newPaid, 'payment_status': PurchaseAccounting.paymentStatus(newTotal, newPaid),
      }, where: 'id=?', whereArgs: [purchaseId]);
      if (cashRefund > 0) {
        await tx.insert('cash_movements', {
          'movement_type': 'IN', 'amount': cashRefund,
          'concept': 'Reembolso de proveedor ${row['folio']}',
          'reference': method, 'payment_method': method, 'created_at': now,
        });
      }
      await tx.insert('audit_log', {
        'entity': 'purchase', 'entity_id': purchaseId, 'action': 'RETURN_ITEM',
        'detail': '$quantity · $amount · reembolso $cashRefund · ${reason.trim()}',
        'created_at': now,
      });
      await tx.insert('sync_outbox', {
        'entity': 'purchase_return', 'entity_id': returnId, 'operation': 'CREATE',
        'payload': jsonEncode({'purchase_id': purchaseId, 'purchase_item_id': purchaseItemId,
          'quantity': quantity, 'amount': amount, 'cash_refund': cashRefund, 'reason': reason.trim()}),
        'created_at': now,
      });
    });
  }

  Future<Map<String, double>> cashSummary() async {
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
    if (!amount.isFinite || amount <= 0) throw ArgumentError('El importe debe ser mayor a cero y válido.');
    if (concept.trim().isEmpty) throw ArgumentError('El concepto es obligatorio.');
    if (!FinancialRules.paymentMethods.contains(paymentMethod.trim().toUpperCase())) throw ArgumentError('Medio de pago no válido.');
    final now = _now();
    final id = await db.insert('cash_movements', {
      'movement_type': income ? 'IN' : 'OUT',
      'amount': amount,
      'concept': concept.trim(),
      'reference': reference.trim(),
      'payment_method': paymentMethod,
      'created_at': now,
    });
    await _audit('cash_movement', id, income ? 'IN' : 'OUT', '$amount · ${concept.trim()} · $paymentMethod');
    await _outbox('cash_movement', id, 'CREATE', {
      'amount': amount, 'type': income ? 'IN' : 'OUT',
      'concept': concept.trim(), 'payment_method': paymentMethod,
    });
  }

  Future<void> closeCashCut(double counted, String notes) async {
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

  Future<List<Map<String, Object?>>> cashMovements() => db.query('cash_movements', orderBy: 'id DESC', limit: 100);
  Future<List<Map<String, Object?>>> cashCuts() => db.query('cash_cuts', orderBy: 'id DESC', limit: 30);
  Future<List<Map<String, Object?>>> warranties() => db.rawQuery('''SELECT w.*, o.folio, c.name client_name, d.brand, d.model FROM warranties w
    JOIN service_orders o ON o.id=w.order_id JOIN clients c ON c.id=o.client_id LEFT JOIN devices d ON d.id=o.device_id ORDER BY w.id DESC''');

  Future<Map<String, double>> reportTotals() async {
    final orders = await db.rawQuery("SELECT COALESCE(SUM(total),0) total, COALESCE(SUM(paid),0) paid, COUNT(*) count FROM service_orders WHERE status!='CANCELADO'");
    final sales = await db.rawQuery('SELECT COALESCE(SUM(total),0) total, COUNT(*) count FROM sales');
    final cash = await cashSummary();
    return {'orders_total': (orders.first['total'] as num).toDouble(), 'orders_paid': (orders.first['paid'] as num).toDouble(), 'orders_count': (orders.first['count'] as num).toDouble(), 'sales_total': (sales.first['total'] as num).toDouble(), 'sales_count': (sales.first['count'] as num).toDouble(), 'cash_balance': cash['balance'] ?? 0, 'digital_balance': cash['digital_balance'] ?? 0};
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

  Future<void> _audit(String entity, int id, String action, String detail) async {
    await db.insert('audit_log', {'entity': entity, 'entity_id': id, 'action': action, 'detail': detail, 'created_at': _now()});
  }
  Future<void> _outbox(String entity, int id, String operation, Map<String, Object?> payload) async {
    await db.insert('sync_outbox', {'entity': entity, 'entity_id': id, 'operation': operation, 'payload': jsonEncode(payload), 'created_at': _now()});
  }
}
