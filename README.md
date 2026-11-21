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

## Estado actual

Esta beta trabaja con SQLite local y modo offline-first. Incluye módulos para inicio, clientes, órdenes, diagnóstico, evidencias, pagos, inventario, POS, caja, garantías, reportes, proveedores y compras.

### Usuarios y seguridad local

- En la primera apertura se solicita crear una cuenta administradora. Ya no existe una contraseña predeterminada.
- Las contraseñas se almacenan como hashes PBKDF2-HMAC-SHA256 con salt aleatorio por usuario, nunca en texto plano.
- La sesión se guarda en Android Keystore mediante almacenamiento seguro. Tiene una duración máxima de 12 horas y se invalida si la app permanece en segundo plano más de 30 minutos.
- Cinco intentos fallidos bloquean temporalmente la cuenta durante 15 minutos.
- Los roles ADMIN, ENCARGADO, TECNICO y CAJA tienen permisos distintos. Los permisos se validan también en la capa de datos, no solo ocultando opciones de pantalla.
- El administrador puede crear cuentas, cambiar roles, desactivar usuarios y restablecer contraseñas. Al desactivar una cuenta o restablecer su contraseña se revocan sus sesiones.

### Arquitectura pendiente

- La app aún no se conecta a un servidor. La futura sincronización se hará contra un backend nuevo, diseñado y construido desde cero para eShokFix, no contra la aplicación de escritorio.
- El servidor, la sincronización multi-dispositivo, el licenciamiento remoto y WhatsApp Cloud API se abordarán en una fase posterior.
- La autenticación de esta etapa protege las cuentas locales de la instalación. Cuando exista el backend, la identidad y los permisos deberán validarse también en el servidor; una app móvil local no puede ser la autoridad final frente a un dispositivo comprometido o una APK modificada.

Los datos de demostración se incluyen para explorar operaciones locales. Retíralos desde Configuración antes de registrar información real.


### Validación de la rama

La verificación de esta etapa se ejecuta en GitHub Actions: resolución de dependencias, análisis estático, pruebas automatizadas y compilación de APK debug. La APK solo se considera lista para prueba cuando los cuatro pasos terminan correctamente.
