part of '../local_store.dart';

extension LocalStorePurchaseReceivingOperations on LocalStore {
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


}
