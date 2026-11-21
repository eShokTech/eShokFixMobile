import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/workflow.dart';

void main() {
  group('OrderWorkflow', () {
    test('allows the normal repair lifecycle', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'DIAGNOSTICO'), isTrue);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'REPARACION'), isTrue);
      expect(OrderWorkflow.canTransition('REPARACION', 'PRUEBAS'), isTrue);
      expect(OrderWorkflow.canTransition('PRUEBAS', 'LISTO'), isTrue);
      expect(OrderWorkflow.canTransition('LISTO', 'ENTREGADO'), isTrue);
    });

    test('blocks skipping required workflow steps', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'LISTO'), isFalse);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'ENTREGADO'), isFalse);
      expect(OrderWorkflow.canTransition('ENTREGADO', 'REPARACION'), isFalse);
    });

    test('allows a delivered order to remain in its current state', () {
      expect(OrderWorkflow.canTransition('ENTREGADO', 'ENTREGADO'), isTrue);
    });

    test('provides readable labels for all known states', () {
      expect(OrderWorkflow.label('ESPERA_AUTORIZACION'), 'Esperando autorización');
      expect(OrderWorkflow.label('LISTO'), 'Listo para entregar');
    });
  });
}
