import 'dart:convert';
import 'auth_service.dart';
import 'dart:io';
import 'database_backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/workflow.dart';
import '../domain/financial_rules.dart';

part 'local_store/workshop.dart';
part 'local_store/inventory_purchases.dart';
part 'local_store/sales.dart';
part 'local_store/purchase_receiving.dart';
part 'local_store/finance_admin.dart';
part 'local_store/ecosystem.dart';

Future<void> _recordInventoryMovement(
  DatabaseExecutor db,
  int itemId,
  double quantity,
  String type,
  String reason,
  String createdAt,
) async {
  await db.insert('inventory_movements', {
    'item_id': itemId,
    'movement_type': type,
    'quantity': quantity.abs(),
    'reason': reason,
    'created_at': createdAt,
  });
}


Future<void> _createAppNotificationsTable(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS app_notifications(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_key TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'INFO',
    target_view TEXT NOT NULL,
    target_id INTEGER,
    required_permission TEXT NOT NULL DEFAULT 'dashboard.view',
    created_at TEXT NOT NULL,
    read_at TEXT,
    resolved_at TEXT
  )''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_app_notifications_active ON app_notifications(resolved_at, read_at, created_at)');
}

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
  AuthUser? _authenticatedUser;
  DateTime? _lastActivityAt;
  AuthUser? get authenticatedUser => _authenticatedUser;

  void setAuthenticatedUser(AuthUser? user) {
    _authenticatedUser = user;
    _lastActivityAt = user == null ? null : DateTime.now();
  }

  bool registerActivity() {
    final last = _lastActivityAt;
    if (_authenticatedUser == null || last == null ||
        DateTime.now().difference(last) > AuthService.idleLifetime) {
      _authenticatedUser = null;
      _lastActivityAt = null;
      return false;
    }
    _lastActivityAt = DateTime.now();
    return true;
  }

  void requirePermission(String permission) {
    final user = _authenticatedUser;
    final last = _lastActivityAt;
    if (user == null || last == null ||
        DateTime.now().difference(last) > AuthService.idleLifetime ||
        !AuthService.can(user.role, permission)) {
      throw StateError('No tienes permiso para realizar esta operación.');
    }
  }

  static LocalStore? _instance;

  static Future<LocalStore> open() async {
    if (_instance != null) return _instance!;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'eshokfix_mobile_v1.db'),
      version: 10,
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
          password_salt TEXT DEFAULT '', password_hash TEXT DEFAULT '',
          failed_attempts INTEGER NOT NULL DEFAULT 0, locked_until TEXT,
          last_login_at TEXT, created_at TEXT NOT NULL)''');
        batch.execute('''CREATE TABLE auth_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,
          token_hash TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL,
          last_seen_at TEXT NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT,
          FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
        batch.execute('CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id, revoked_at)');
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
        await _createAppNotificationsTable(db);
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
        if (oldVersion < 9) {
          await db.execute("ALTER TABLE users ADD COLUMN password_salt TEXT DEFAULT ''");
          await db.execute("ALTER TABLE users ADD COLUMN password_hash TEXT DEFAULT ''");
          await db.execute("ALTER TABLE users ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0");
          await db.execute("ALTER TABLE users ADD COLUMN locked_until TEXT");
          await db.execute("ALTER TABLE users ADD COLUMN last_login_at TEXT");
          await db.execute('''CREATE TABLE auth_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,
            token_hash TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL,
            last_seen_at TEXT NOT NULL, expires_at TEXT NOT NULL, revoked_at TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)''');
          await db.execute('CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id, revoked_at)');
        }
        if (oldVersion < 10) {
          await _createAppNotificationsTable(db);
        }
      },
    );
    _instance = LocalStore._(database);
    await _instance!._seedIfEmpty();
    return _instance!;
  }

  Future<void> close() async {
    await db.close();
    if (identical(_instance, this)) _instance = null;
  }

  Future<String?> exportBackup() async {
    requirePermission('settings.manage');
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
    requirePermission('settings.manage');
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
      if (version < 1 || version > 10) {
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


  Future<void> _audit(String entity, int id, String action, String detail) async {
    await db.insert('audit_log', {
      'entity': entity,
      'entity_id': id,
      'action': action,
      'detail': detail,
      'created_at': _now(),
    });
  }

  Future<void> _outbox(String entity, int id, String operation, Map<String, Object?> payload) async {
    await db.insert('sync_outbox', {
      'entity': entity,
      'entity_id': id,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': _now(),
    });
  }
}
