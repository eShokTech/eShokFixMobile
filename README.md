# eShokFix Mobile | Paquete Android Studio

Esta carpeta ya incluye el proyecto Flutter y la estructura Android/Gradle. No necesitas crear el proyecto Android manualmente.

## Abrir y probar

1. Descomprime el ZIP.
2. Abre Android Studio y pulsa **Open**.
3. Selecciona esta carpeta principal, la que contiene `pubspec.yaml`, `lib` y `android`.
4. Espera a que Android Studio cargue el proyecto y resuelva las dependencias.
5. Conecta tu teléfono Android o selecciona un emulador y pulsa **Run**.
6. Para crear el APK, usa **Build > Flutter > Build APK**.

El APK de depuración se genera en:

`build/app/outputs/flutter-apk/app-debug.apk`

También se incluye `CREAR_APK_DESDE_AQUI.bat` como alternativa para compilar desde Windows. No es necesario usarlo si vas a trabajar dentro de Android Studio.

## Importante

- Abre la carpeta raíz del proyecto, no solamente `android`.
- Requiere Android Studio con el plugin Flutter y un Flutter SDK instalado. Si ya compilaste otros proyectos Flutter, usa ese mismo SDK.
- La primera carga necesita Internet para resolver y descargar paquetes y Gradle.
- La app contiene datos de demostración para probar operaciones locales. No uses información real de clientes en esta beta.

## Estado de esta beta

Incluye base local SQLite y módulos de prueba para inicio, clientes, órdenes/expedientes, evidencia, pagos, inventario, POS básico, caja, garantías, reportes y configuración.

Aún no están conectados el servidor de datos de PC, sincronización real, login/RBAC comercial, servidor de licencias ni WhatsApp Cloud API. Los perfiles de usuario y eventos de WhatsApp que aparecen en esta beta son demostrativos/locales.
