import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eshokfix_mobile/data/local_store.dart';
import 'package:eshokfix_mobile/data/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath = p.join(await getDatabasesPath(), 'eshokfix_mobile_v1.db');
    await deleteDatabase(databasePath);
    store = await LocalStore.open();
    store.setAuthenticatedUser(const AuthUser(id: 1, username: 'test-admin', displayName: 'Administrador de pruebas', role: 'ADMIN'));
  });

  tearDown(() async {
    await store.close();
    await deleteDatabase(databasePath);
  });

  test('sale split payments, partial returns and full cancellation stay consistent', () async {
    final itemId = await store.saveInventoryItem(
      name: 'Pantalla de prueba',
      sku: 'TEST-DISPLAY',
      stock: 5,
      cost: 40,
      price: 100,
    );
    await store.saveInventoryItem(
      id: itemId, name: 'Pantalla de prueba', sku: 'TEST-DISPLAY',
      stock: 999, cost: 40, price: 105,
      priceChangeReason: 'Ajuste de precio en prueba',
    );
    final preSaleInventory = await store.inventory(query: 'Pantalla de prueba');
    expect(preSaleInventory.single['stock'], 5);

    final saleId = await store.createSaleCart(
      items: [{
        'item_id': itemId, 'description': 'Pantalla de prueba',
        'quantity': 2, 'unit_price': 100,
      }],
      paymentMethod: 'EFECTIVO',
      paymentBreakdown: [
        {'method': 'EFECTIVO', 'amount': 100},
        {'method': 'TARJETA', 'amount': 100},
      ],
    );

    var inventory = await store.inventory(query: 'Pantalla de prueba');
    expect(inventory.single['stock'], 3);
    final payments = await store.salePayments(saleId);
    expect(payments, hasLength(2));
    expect(payments.fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble()), 200);

    final lines = await store.saleItems(saleId);
    await store.returnSaleItem(
      saleId: saleId, saleItemId: lines.single['id'] as int,
      quantity: 1, refundMethod: 'EFECTIVO',
      reason: 'Prueba de devolución parcial',
    );
    inventory = await store.inventory(query: 'Pantalla de prueba');
    expect(inventory.single['stock'], 4);
    final saleAfterPartial = (await store.sales()).singleWhere((row) => row['id'] == saleId);
    expect(saleAfterPartial['status'], 'PARTIAL_RETURN');
    expect((saleAfterPartial['refunded_total'] as num).toDouble(), 100);

    await store.returnSaleItem(
      saleId: saleId, saleItemId: lines.single['id'] as int,
      quantity: 1, refundMethod: 'TARJETA',
      reason: 'Prueba de devolución total',
    );
    inventory = await store.inventory(query: 'Pantalla de prueba');
    expect(inventory.single['stock'], 5);
    final saleAfterFull = (await store.sales()).singleWhere((row) => row['id'] == saleId);
    expect(saleAfterFull['status'], 'VOID');
    expect((saleAfterFull['refunded_total'] as num).toDouble(), 200);
    expect(await store.saleReturns(saleId), hasLength(2));
  });

  test('purchase order receipts only increase stock as goods physically arrive', () async {
    final supplierId = await store.saveSupplier(name: 'Proveedor de prueba');
    final itemId = await store.saveInventoryItem(
      name: 'Batería de prueba', sku: 'TEST-BATTERY',
      stock: 0, cost: 50, price: 120,
    );
    final purchaseId = await store.createPurchase(
      supplierId: supplierId,
      items: [{'item_id': itemId, 'quantity': 5, 'unit_cost': 50}],
      discount: 50,
      receiveImmediately: false,
      paid: 100,
      paymentMethod: 'TRANSFERENCIA',
    );

    var inventory = await store.inventory(query: 'Batería de prueba');
    expect(inventory.single['stock'], 0);
    var purchase = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect(purchase['status'], 'ORDERED');

    final lines = await store.purchaseItems(purchaseId);
    final purchaseItemId = lines.single['id'] as int;
    await store.receivePurchaseItem(purchaseId, purchaseItemId, 2);
    inventory = await store.inventory(query: 'Batería de prueba');
    expect(inventory.single['stock'], 2);
    purchase = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect(purchase['status'], 'PARTIAL_RECEIVED');

    await store.receivePurchaseItem(purchaseId, purchaseItemId, 3);
    inventory = await store.inventory(query: 'Batería de prueba');
    expect(inventory.single['stock'], 5);
    purchase = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect(purchase['status'], 'RECEIVED');

    await expectLater(
      store.receivePurchaseItem(purchaseId, purchaseItemId, 1),
      throwsA(isA<StateError>()),
    );
    await store.returnPurchaseItem(
      purchaseId: purchaseId, purchaseItemId: purchaseItemId,
      quantity: 1, refundMethod: 'EFECTIVO', reason: 'Primera devolución',
    );
    inventory = await store.inventory(query: 'Batería de prueba');
    expect(inventory.single['stock'], 4);
    var purchaseAfterReturn = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect((purchaseAfterReturn['total'] as num).toDouble(), 160);
    await store.returnPurchaseItem(
      purchaseId: purchaseId, purchaseItemId: purchaseItemId,
      quantity: 1, refundMethod: 'EFECTIVO', reason: 'Segunda devolución',
    );
    inventory = await store.inventory(query: 'Batería de prueba');
    expect(inventory.single['stock'], 3);
    final returnedLines = await store.purchaseItems(purchaseId);
    expect((returnedLines.single['returned_quantity'] as num).toDouble(), 2);
    purchaseAfterReturn = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect((purchaseAfterReturn['total'] as num).toDouble(), 120);
    final returns = await store.purchaseReturns(purchaseId);
    expect(returns, hasLength(2));
    expect(returns.fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble()), 80);
    await store.recordPurchasePayment(
      purchaseId,
      20,
      'EFECTIVO',
      paymentBreakdown: [
        {'method': 'EFECTIVO', 'amount': 10},
        {'method': 'TARJETA', 'amount': 10},
      ],
    );
    purchaseAfterReturn = (await store.purchases()).singleWhere((row) => row['id'] == purchaseId);
    expect((purchaseAfterReturn['paid'] as num).toDouble(), 120);
    expect(purchaseAfterReturn['payment_status'], 'PAGADA');
    final purchasePayments = await store.purchasePayments(purchaseId);
    expect(purchasePayments, hasLength(3));
    expect(purchasePayments.fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble()), 120);
  });

  test('cancelled service order refunds collected money and rejects future payments', () async {
    final clientId = await store.saveClient(name: 'Cliente de prueba');
    final orderId = await store.createOrder(
      clientId: clientId, brand: 'Samsung', model: 'A26',
      failure: 'No enciende', condition: 'Pantalla intacta',
      accessories: 'Equipo solamente', technician: 'Técnico de prueba',
      labor: 350, deposit: 100,
    );
    await store.cancelOrder(
      orderId, refundMethod: 'TRANSFERENCIA',
      reason: 'Cliente desistió del servicio',
    );

    final order = await store.order(orderId);
    expect(order!['status'], 'CANCELADO');
    expect((order['paid'] as num).toDouble(), 0);
    expect((order['refunded_total'] as num).toDouble(), 100);
    final refunds = await store.orderRefunds(orderId);
    expect(refunds, hasLength(1));
    expect(refunds.single['method'], 'TRANSFERENCIA');
    final cash = await store.cashSummary();
    expect(cash['balance'], 100);
    expect(cash['digital_balance'], -100);
    expect(
      () => store.addOrderPayment(orderId, 10, 'EFECTIVO'),
      throwsA(isA<StateError>()),
    );
  });

  test('repair parts require customer authorization and consumed stock is not restored on cancellation', () async {
    final clientId = await store.saveClient(name: 'Cliente autorización');
    final itemId = await store.saveInventoryItem(
      name: 'Centro de carga',
      sku: 'TEST-CHARGE',
      stock: 2,
      cost: 30,
      price: 90,
    );
    final orderId = await store.createOrder(
      clientId: clientId,
      brand: 'Motorola',
      model: 'G54',
      failure: 'No carga',
      condition: 'Equipo íntegro',
      accessories: 'Equipo solamente',
      technician: 'Técnico',
      labor: 150,
    );

    await expectLater(
      store.addOrderPart(orderId, itemId, 1),
      throwsA(isA<StateError>()),
    );
    var inventory = await store.inventory(query: 'TEST-CHARGE');
    expect(inventory.single['stock'], 2);

    await store.setOrderStatus(orderId, 'DIAGNOSTICO');
    await store.setOrderStatus(orderId, 'ESPERA_AUTORIZACION');
    await store.authorizeOrder(
      orderId,
      authorizedBy: 'Cliente autorización',
      method: 'WHATSAPP',
      note: 'Presupuesto aprobado',
    );
    await store.addOrderPart(orderId, itemId, 1);

    inventory = await store.inventory(query: 'TEST-CHARGE');
    expect(inventory.single['stock'], 1);
    var order = await store.order(orderId);
    expect((order!['parts_total'] as num).toDouble(), 90);
    expect((order['total'] as num).toDouble(), 240);

    await expectLater(
      store.addOrderPart(orderId, itemId, 2),
      throwsA(isA<StateError>()),
    );
    inventory = await store.inventory(query: 'TEST-CHARGE');
    expect(inventory.single['stock'], 1);

    await store.addOrderPayment(
      orderId,
      100,
      'EFECTIVO',
      paymentBreakdown: [
        {'method': 'EFECTIVO', 'amount': 60},
        {'method': 'TRANSFERENCIA', 'amount': 40},
      ],
    );
    final orderPayments = await store.orderPayments(orderId);
    expect(orderPayments, hasLength(2));
    await store.cancelOrder(
      orderId,
      refundMethod: 'EFECTIVO',
      reason: 'El cliente decidió no continuar',
    );
    inventory = await store.inventory(query: 'TEST-CHARGE');
    expect(inventory.single['stock'], 1);
    order = await store.order(orderId);
    expect(order!['status'], 'CANCELADO');
    expect((order['paid'] as num).toDouble(), 0);
    expect((order['refunded_total'] as num).toDouble(), 100);
    final refunds = await store.orderRefunds(orderId);
    expect(refunds, hasLength(1));
    expect(refunds.single['amount'], 100);
  });

  test('customer history cannot be deleted and closed order diagnosis cannot be edited', () async {
    final clientId = await store.saveClient(name: 'Cliente con historial');
    final orderId = await store.createOrder(
      clientId: clientId,
      brand: 'Xiaomi', model: 'POCO F6', failure: 'No carga',
      condition: 'Sin golpes', accessories: 'Equipo solamente',
      technician: 'Técnico', labor: 200,
    );
    await store.cancelOrder(
      orderId, refundMethod: 'EFECTIVO', reason: 'Prueba de cierre',
    );
    await expectLater(
      store.updateDiagnosis(orderId, 'Editar después de cancelar', ''),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.deleteClient(clientId),
      throwsA(isA<StateError>()),
    );
    final clients = await store.clients(query: 'Cliente con historial');
    expect(clients, hasLength(1));
  });


  test('first-run setup stores a salted hash for the six-digit PIN', () async {
    final auth = AuthService(store.db);
    expect(await auth.needsInitialSetup(), isTrue);
    await auth.createInitialAdmin(
      username: 'admin',
      displayName: 'Administrador principal',
      password: '123456',
    );
    expect(await auth.needsInitialSetup(), isFalse);
    final rows = await store.db.query(
      'users',
      columns: ['password_salt', 'password_hash'],
      where: 'username=?',
      whereArgs: ['admin'],
      limit: 1,
    );
    expect(rows, hasLength(1));
    expect(rows.single['password_salt'], isNotEmpty);
    expect(rows.single['password_hash'], isNot('123456'));
    expect((rows.single['password_hash'] as String).length, greaterThan(40));
    await expectLater(
      auth.createInitialAdmin(
        username: 'admin',
        displayName: 'Segundo intento',
        password: '654321',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('role permissions are enforced at the data layer', () async {
    store.setAuthenticatedUser(const AuthUser(
      id: 2, username: 'tecnico', displayName: 'Técnico', role: 'TECNICO',
    ));
    expect(await store.clients(), isA<List<Map<String, Object?>>>());
    expect(await store.inventory(), isA<List<Map<String, Object?>>>());
    final clientId = await store.saveClient(name: 'Cliente técnico');
    await expectLater(
      store.createOrder(
        clientId: clientId,
        brand: 'Samsung',
        model: 'A26',
        failure: 'No carga',
        condition: 'Sin golpes',
        accessories: 'Equipo',
        technician: 'Técnico',
        labor: 300,
        deposit: 100,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.saveInventoryItem(name: 'No autorizado', stock: 1),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.cashSummary(),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.createSaleCart(
        items: [{'description': 'Servicio', 'quantity': 1, 'unit_price': 100}],
        paymentMethod: 'EFECTIVO',
      ),
      throwsA(isA<StateError>()),
    );
  });


  test('global search finds real clients and inventory items without exposing demo data', () async {
    await store.saveClient(
      name: 'Nadia Global Search',
      phone: '8991234567',
      whatsapp: '8991234567',
    );
    await store.saveInventoryItem(
      name: 'Batería Global Search',
      sku: 'ESH-GLOBAL-2026',
      stock: 8,
      minStock: 2,
      cost: 100,
      price: 180,
    );

    final clientResults = await store.globalSearch('Nadia Global');
    expect(
      clientResults.any((row) =>
        row['type'] == 'CLIENTE' && row['title'] == 'Nadia Global Search'),
      isTrue,
    );

    final productResults = await store.globalSearch('ESH-GLOBAL-2026');
    expect(
      productResults.any((row) =>
        row['type'] == 'PRODUCTO' && row['title'] == 'Batería Global Search'),
      isTrue,
    );

    final deviceClientId = await store.saveClient(
      name: 'Cliente Equipo A26',
      phone: '8997654321',
    );
    await store.db.insert('devices', {
      'client_id': deviceClientId,
      'brand': 'Samsung',
      'model': 'Galaxy A26 5G',
      'color': 'Negro',
      'imei': '359111111111111',
      'serial': 'A26-TEST-001',
      'created_at': DateTime.now().toIso8601String(),
    });

    final deviceResults = await store.globalSearch('A26');
    expect(
      deviceResults.any((row) =>
        row['type'] == 'EQUIPO' &&
        row['title'] == 'Samsung Galaxy A26 5G'),
      isTrue,
    );

    final demoResults = await store.globalSearch('Cliente de demostración');
    expect(demoResults.any((row) => row['type'] == 'CLIENTE'), isFalse);
  });

  test('operational notifications are persisted, permission-filtered and markable as read', () async {
    final itemId = await store.saveInventoryItem(
      name: 'Refacción con stock crítico',
      sku: 'TEST-LOW-STOCK',
      stock: 1,
      minStock: 3,
      cost: 50,
      price: 100,
    );

    await store.refreshOperationalNotifications();
    final unread = await store.notifications(unreadOnly: true);
    final alert = unread.where((row) =>
      row['type'] == 'LOW_STOCK' && row['target_id'] == itemId);
    expect(alert, hasLength(1));

    await store.markNotificationRead(alert.single['id'] as int);
    final unreadAfter = await store.notifications(unreadOnly: true);
    expect(
      unreadAfter.any((row) =>
        row['type'] == 'LOW_STOCK' && row['target_id'] == itemId),
      isFalse,
    );

    final allActive = await store.notifications();
    expect(
      allActive.any((row) =>
        row['type'] == 'LOW_STOCK' && row['target_id'] == itemId),
      isTrue,
    );
  });


  test('inventory price changes require a reason and retain actor and before/after values', () async {
    final itemId = await store.saveInventoryItem(
      name: 'Cable con historial de precio',
      sku: 'PRICE-HISTORY-01',
      stock: 4,
      cost: 100,
      price: 150,
    );

    await expectLater(
      store.saveInventoryItem(
        id: itemId,
        name: 'Cable con historial de precio',
        sku: 'PRICE-HISTORY-01',
        stock: 4,
        cost: 100,
        price: 165,
      ),
      throwsArgumentError,
    );
    expect(await store.inventoryPriceHistory(itemId), isEmpty);

    await store.saveInventoryItem(
      id: itemId,
      name: 'Cable con historial de precio',
      sku: 'PRICE-HISTORY-01',
      stock: 4,
      cost: 100,
      price: 165,
      priceChangeReason: 'Nuevo costo del proveedor',
    );

    final history = await store.inventoryPriceHistory(itemId);
    expect(history, hasLength(1));
    expect((history.single['old_price'] as num).toDouble(), 150);
    expect((history.single['new_price'] as num).toDouble(), 165);
    expect(history.single['changed_by'], 1);
    expect(history.single['reason'], 'Nuevo costo del proveedor');
  });

}
