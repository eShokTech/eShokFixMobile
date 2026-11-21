# Pruebas manuales de eShokFix Mobile Beta

## Preparación

1. Compila con `BUILD_ANDROID_DEBUG_APK.bat` o inicia con `RUN_ANDROID.bat`.
2. Instala en un Android de prueba.
3. La primera apertura crea datos ficticios para que puedas recorrer la app.
4. No uses clientes reales hasta que exista autenticación, licencia y respaldo/sincronización.

## Casos recomendados

### Recepción y expediente

1. Abre Clientes y registra un cliente de prueba.
2. Abre Órdenes y toca Nueva.
3. Captura marca, modelo, falla, estado físico, accesorios, IMEI/serie, mano de obra, refacciones, descuento, anticipo y días de garantía.
4. Guarda y comprueba que se genera folio, historial y aviso local de recepción.
5. Abre el expediente, agrega diagnóstico y toma una fotografía.
6. Cierra y vuelve a abrir la app. Comprueba que orden, notas e imagen siguen disponibles.

### Flujo de reparación

1. Avanza por Diagnóstico, Espera de autorización/refacción (cuando corresponda), Reparación y Pruebas.
2. Intenta una transición que se salte etapas: debe bloquearse.
3. Marca Listo. Debe registrarse el segundo evento de WhatsApp.
4. Entrega el equipo. Debe generarse la garantía y el tercer evento.
5. Revisa que los estados internos no generan eventos de WhatsApp.

### Cobros, caja e inventario

1. Registra un pago parcial y confirma que reduce el saldo.
2. Intenta pagar más del saldo: debe rechazarse.
3. Crea un artículo, ajusta existencias y verifica el historial de movimientos.
4. Registra una venta de inventario y verifica el descuento de stock y la entrada a caja.
5. Registra una salida manual y cierra un corte. Comprueba diferencia entre efectivo esperado y contado.

### Comprobante y garantías

1. Abre un expediente y pulsa Imprimir/PDF.
2. Comprueba folio, cliente, equipo, importes, saldo y días de garantía.
3. Tras entregar el expediente, consulta el módulo Garantías.

## Límites conocidos de esta compilación

Esta beta opera con SQLite en el mismo teléfono. No tiene todavía sincronización con PC, autenticación segura/RBAC, licenciamiento conectado, WhatsApp real, pagos mixtos, devoluciones, POS técnico ni impresión Bluetooth/USB certificada. Los eventos WhatsApp son registros locales, no mensajes enviados.
