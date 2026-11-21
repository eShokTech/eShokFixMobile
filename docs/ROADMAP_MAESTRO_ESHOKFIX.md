# Roadmap maestro eShokFix: Mobile + Desktop + Plataforma

**Objetivo:** construir un ecosistema coordinado para negocios de reparación, con operación móvil offline-first, PC local por sucursal, servidor central, licenciamiento y servicios externos.

Este documento es el plan de trabajo. Los estados describen intención y no deben interpretarse como funciones terminadas hasta que existan pruebas y criterios de aceptación cumplidos.

## Principios no negociables

1. La base de negocio y sus reglas deben ser coherentes entre Desktop y Mobile.
2. Cada registro operativo deberá quedar asociado a un negocio y una sucursal; cada instalación y dispositivo deberá tener identidad estable.
3. La licencia autoriza capacidades, sucursales y límites contratados. No sustituye la autenticación ni los permisos del usuario.
4. El PC de cada sucursal puede mantener la operación local aunque Internet no esté disponible.
5. La sincronización debe ser durable, idempotente y auditable. Nunca usar "última escritura gana" para cobros, ventas, devoluciones o caja.
6. Los servicios locales se exponen solo a redes confiables y requieren autenticación. No publicar puertos de administración o impresión directamente en Internet.
7. Cada entrega debe tener pruebas automatizadas y un criterio de aceptación verificable en dispositivos reales.

## Arquitectura objetivo

- **Servidor central:** negocios, licencias, sucursales, identidades de dispositivos, capacidades contratadas, sincronización entre sucursales, WhatsApp y distribución de versiones.
- **Nodo local Windows por sucursal:** API local, base de datos principal de la sucursal, descubrimiento LAN, cola de sincronización y servicio de impresión USB.
- **eShokFix Mobile:** SQLite offline-first, autenticación, permisos, búsqueda, notificaciones, flujos del taller y cliente de sincronización.
- **eShokFix Desktop:** continúa operando el taller y aloja/gestiona el nodo local sin que el servicio dependa de mantener abierta una ventana específica.

## Frentes de trabajo y entregables

### F0. Contrato de arquitectura y modelo común
- Definir tenant/negocio, sucursal, dispositivo, usuario, licencia y sesión.
- Definir qué datos son globales por negocio y cuáles pertenecen a una sucursal.
- Definir IDs estables, versionado, auditoría, permisos y reglas de migración.
- Documentar contratos API y políticas de sincronización.

**Aceptación:** modelo de entidades, matriz de permisos y contrato API versionado revisados antes de persistir datos multisucursal.

### F1. Plataforma central y licenciamiento
- Alta y administración de negocios.
- Alta, pausa y baja de sucursales.
- Planes/capacidades: número de sucursales, dispositivos, usuarios y módulos.
- Registro, renovación y revocación de dispositivos.
- Autorización offline firmada con vencimiento y periodo de gracia.
- Separación estricta entre licencia, dispositivo autorizado y sesión del usuario.

**Aceptación:** una licencia de una sucursal no permite registrar una segunda; una licencia multisucursal permite operar locales autorizados sin mezclar inventarios ni cajas.

### F2. Nodo local y API de PC
- FastAPI como servicio administrado por Windows.
- API desacoplada del ciclo de vida de la ventana Qt.
- Descubrimiento de la API en LAN, con autenticación posterior obligatoria.
- Estado de salud, configuración, logs, reinicio y arranque automático.
- Contratos compartidos con el servidor central.

**Aceptación:** un Android en la misma red encuentra el nodo, se autentica y consulta datos permitidos; apagar Internet no interrumpe la operación local.

### F3. Impresión centralizada desde Mobile
- Enumerar impresoras instaladas en Windows.
- Identificar nombre, controlador y puerto configurado.
- Seleccionar impresora y formato 58/80 mm.
- Cola durable con IDs únicos y estado de cada trabajo.
- Impresión de prueba, ticket, comprobante y garantía.
- Transporte RAW/ESC-POS solo cuando el modelo/controlador lo soporte; respetar impresoras que requieran su driver.
- Fallback a PDF o impresora Bluetooth directa si el PC está apagado.

**Aceptación:** Mobile envía un ticket a una impresora USB conectada a la PC, recibe estado del trabajo y no duplica impresiones por reintento.

### F4. Mejoras funcionales Mobile
- Búsqueda global por clientes, teléfono, folio, equipo, IMEI/serie, SKU, producto, proveedor, compra, venta y garantía.
- Centro de notificaciones con lectura, prioridad y navegación al registro relacionado.
- Adaptar reglas existentes de precio, costo, utilidad y margen del Desktop.
- Historial de cambios de precios con usuario y motivo.
- Cuentas por cobrar como subledger independiente: cargos autorizados, crédito/límite, vencimientos, abonos, reversos y estados de cuenta.
- Notificaciones de atrasos, stock bajo y obligaciones pendientes.
- Filtros y exportaciones avanzadas de reportes.

**Aceptación:** resultados y cálculos concuerdan con Desktop; los permisos de costo, crédito y finanzas se aplican también en la capa de datos.

### F5. Sincronización offline-first y multisucursal
- Outbox/inbox transaccionales y confirmaciones.
- IDs de evento, idempotencia en servidor, cursores y reintentos con backoff.
- Resolución explícita de conflictos y trazabilidad.
- Sincronización de evidencias y archivos.
- Separación de datos por tenant y sucursal.
- Consolidados de negocio sin mezclar cajas ni existencias.

**Aceptación:** probar PC y Android con la misma Wi-Fi, redes diferentes/VPN, Internet interrumpido, PC apagada, reconexión y reintentos duplicados.

### F6. WhatsApp Business Platform
- Servicio independiente en servidor central.
- Configuración del número y credenciales por negocio.
- Plantillas y consentimiento.
- Cola durable, idempotencia, reintentos y webhooks de estado.
- Solo tres comunicaciones automáticas acordadas: recepción, equipo listo y entrega con comprobante/garantía.
- Consultas y autorizaciones adicionales siguen siendo conversaciones iniciadas por el técnico.

**Aceptación:** cada evento genera como máximo un envío lógico; se conserva el estado y error devuelto por Meta.

### F7. Actualizador integrado
- Manifiesto de versiones y canales de distribución.
- Artefactos firmados y verificación de integridad.
- Actualizador Windows con respaldo, migración, rollback y logs.
- Actualización Android con descarga y confirmación del instalador/sistema.
- Política de compatibilidad de base de datos y mínimo de versión.

**Aceptación:** actualizar Desktop y Android sin pérdida de datos; una actualización fallida conserva/restaura una versión operativa.

### F8. Liberación y operación
- Pruebas de permisos, aislamiento de negocios y sucursales.
- Pruebas de restauración y recuperación.
- Pruebas físicas con impresoras y modelos Android.
- Monitoreo, logs, diagnóstico y soporte.
- Documentación de instalación, respaldo, actualización y recuperación.

## Orden de ejecución en paralelo

**Carril A: plataforma:** F0 → F1 → F5.

**Carril B: PC local:** contrato F0 → F2 → F3.

**Carril C: Mobile:** F0 → F4 → integración F5.

**Carril D: comunicaciones:** eventos existentes → F6 conectado al servidor.

**Carril E: distribución:** manifiesto/firmas en paralelo → F7.

Los carriles pueden avanzar simultáneamente cuando consumen contratos ya definidos. Ningún carril debe inventar nombres de campos, IDs, permisos o estados incompatibles con F0.

## Entrega inmediata: primera ola

1. Abrir una rama separada sin alterar ni fusionar la PR #1.
2. Añadir este roadmap al repositorio.
3. Implementar búsqueda global móvil con permisos por módulo.
4. Implementar centro de notificaciones locales con alertas idempotentes de operación.
5. Preparar contratos y pruebas para el siguiente incremento.
6. Ejecutar CI, corregir fallos y pedir prueba física antes de declarar la entrega lista.

## Regla de estado

Marcar una tarea como **terminada** solo cuando:
- código integrado en su rama de trabajo;
- migraciones probadas desde una base nueva y desde una versión anterior;
- análisis estático y pruebas automatizadas exitosos;
- flujo real probado en hardware cuando involucra Android, Windows, red o impresora;
- documentación actualizada.
