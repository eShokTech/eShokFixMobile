class OrderWorkflow {
  static const statuses = <String>[
    'RECIBIDO',
    'DIAGNOSTICO',
    'ESPERA_AUTORIZACION',
    'ESPERA_REFACCION',
    'REPARACION',
    'PRUEBAS',
    'LISTO',
    'ENTREGADO',
    'CANCELADO',
  ];

  static const labels = <String, String>{
    'RECIBIDO': 'Recibido',
    'DIAGNOSTICO': 'Diagnóstico',
    'ESPERA_AUTORIZACION': 'Esperando autorización',
    'ESPERA_REFACCION': 'Esperando refacción',
    'REPARACION': 'En reparación',
    'PRUEBAS': 'Pruebas',
    'LISTO': 'Listo para entregar',
    'ENTREGADO': 'Entregado',
    'CANCELADO': 'Cancelado',
  };

  static const transitions = <String, Set<String>>{
    'RECIBIDO': {'DIAGNOSTICO', 'CANCELADO'},
    'DIAGNOSTICO': {'ESPERA_AUTORIZACION', 'CANCELADO'},
    'ESPERA_AUTORIZACION': {'ESPERA_REFACCION', 'REPARACION', 'CANCELADO'},
    'ESPERA_REFACCION': {'REPARACION', 'CANCELADO'},
    'REPARACION': {'PRUEBAS', 'ESPERA_REFACCION', 'ESPERA_AUTORIZACION', 'CANCELADO'},
    'PRUEBAS': {'REPARACION', 'LISTO'},
    'LISTO': {'ENTREGADO', 'REPARACION'},
    'ENTREGADO': {},
    'CANCELADO': {},
  };

  static bool canTransition(String from, String to) =>
      from == to || (transitions[from]?.contains(to) ?? false);

  static String label(String status) => labels[status] ?? status;
}

class PurchaseAccounting {
  static double lineTotal(double quantity, double unitCost) =>
      quantity * unitCost;

  static double total(double subtotal, double discount) =>
      (subtotal - discount).clamp(0.0, double.infinity).toDouble();

  static double balance(double total, double paid) =>
      (total - paid).clamp(0.0, double.infinity).toDouble();

  static String paymentStatus(double total, double paid) {
    if (paid <= 0) return 'PENDIENTE';
    if (balance(total, paid) <= 0.01) return 'PAGADA';
    return 'PARCIAL';
  }
}

class OrderPartAccounting {
  static double lineTotal(double quantity, double unitPrice) =>
      quantity * unitPrice;

  static double orderTotal({
    required double labor,
    required double parts,
    required double discount,
  }) => (labor + parts - discount).clamp(0.0, double.infinity).toDouble();
}
