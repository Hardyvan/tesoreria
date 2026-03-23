# 🐷 InSOFT Tesorería DSI

Una aplicación móvil robusta y elegante desarrollada en **Flutter** para la gestión financiera descentralizada y transparente de salones, organizaciones o grupos (DSI). Permite a los administradores registrar actividades, administrar pagos, auditar acciones y enviar notificaciones, mientras que los alumnos pueden visualizar su estado de deuda, pagar y recibir alertas en tiempo real.

![Flutter Version](https://img.shields.io/badge/Flutter-^3.10.8-0175C2?logo=flutter)
![Dart Version](https://img.shields.io/badge/Dart-^3.0.0-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20FCM-FFCA28?logo=firebase)
![MySQL](https://img.shields.io/badge/Database-MySQL-4479A1?logo=mysql)

---

## ✨ Características Principales

*   **Autenticación Segura (Auth):** Inicio de sesión con Google (SSO) y validación de roles en base de datos.
*   **Gestión de Finanzas:** Creación de actividades, costeo, balance de caja (Ingresos vs Gastos) y cálculo automático de deudas por alumno.
*   **Roles y Permisos:** 
    *   `Admin`: Puede registrar pagos, crear actividades, editar perfiles y ver auditorías.
    *   `Alumno`: Solo lectura de su estado de cuenta, historial de pagos y recepción de notificaciones.
*   **Notificaciones Push (FCM v1):** Alertas en tiempo real cuando un pago es validado.
*   **Recordatorios Locales:** Alarmas programadas (ej. 9:00 AM) para recordar saldos pendientes a los usuarios.
*   **Tema Dinámico:** Motor de personalización (Color y Estilo de Contornos) controlado por `Provider`.
*   **Auditoría Interna:** Registro estricto de "quién hizo qué y cuándo" (trazabilidad de IP y dispositivo).
*   **Modo Offline:** Detección de caída de red (Banner Global).

---

## 🏗 Arquitectura y Estructura del Proyecto

El código fuente está modularizado dentro de la carpeta `lib/` bajo los siguientes espacios de dominios:

### 1. `myPagesBack/` (Capa de Lógica - Controladores)
Se utiliza el patrón `Provider` (ChangeNotifier) para la inyección de dependencias y el manejo de estado global.
*   `a_controlador_auth.dart`: Manejo de inicio de sesión, sesiones persistentes y extracción de roles.
*   `b_controlador_finanzas.dart`: Cálculos de Kardex, Resumen de Caja, Deudores y lógica de pagos.
*   `c_controlador_actividades.dart`: ABM (Alta, Baja y Modificación) de las actividades del grupo.
*   `d_controlador_usuarios.dart`: Gestión de lista de usuarios, edición de celulares y roles (Solo Admins).
*   `e_servicio_notificaciones.dart`: Implementación de notificaciones Push (API v1 de FCM con ServiceAccount).
*   `a_servicio_notificaciones.dart`: Alertas Locales programadas (Local Notifications).
*   `f_servicio_auditoria.dart`: Inserts automáticos al Log de movimientos del sistema.

### 2. `myPagesServer/` (Capa de Datos)
*   `b_base_datos_remota.dart`: Manejador de la conexión directa a MySQL. Centraliza las sentencias SQL (Queries, Inserts, Updates).

### 3. `myPages/` y `myPagesTema/` (Capa de Presentación - UI)
*   Widgets puros que "escuchan" (`Consumer`) o "leen" (`Provider.of`) los datos de los controladores.
*   `a_tema.dart`: Motor de estilos, inyecta `ThemeData` con base a los colores y preferencias guardados en memoria del celular.
*   Diseño usando fuentes **Poppins** e **Inter** incrustadas localmente.

### 4. `myMenu/` (Navegación Core)
*   `b_rutas_app.dart`: Mapa enrutador central de la aplicación (Named Routes).

---

## 🛠 Tecnologías y Librerías (pubspec.yaml)

*   **Gestión de Estado:** `provider: ^6.0.0`
*   **Base de Datos:** `mysql1` (Remota), `sqflite` (Locales / Cache)
*   **Autenticación:** `firebase_auth`, `google_sign_in`
*   **Notificaciones:** `firebase_messaging`, `flutter_local_notifications`, `timezone`
*   **UI/UX:** `google_fonts`, `flutter_native_splash`, `flutter_launcher_icons`
*   **Seguridad:** `flutter_dotenv` (Oculta strings sensibles en `.env`)
*   **Multimedia:** `image_picker`, `firebase_storage`

---

## 🔒 Variables de Entorno (`.env`)

El aplicativo depende críticamente de un archivo oculto `.env` en la raíz (no versionado en GIT por seguridad) que debe contener:

```env
DB_HOST=tu_ip_mysql
DB_PORT=3306
DB_USER=usuario_mysql
DB_PASSWORD=clave_mysql
DB_NAME=dsi_bd
```

---

## 🚀 Despliegue (Play Store / Producción)
El proyecto ha sido configurado con firmas criptográficas de producción.

1. El Application ID oficial es `pe.insoft.dsi`.
2. Para compilar la versión de subida a la Google Play Store, ejecutar:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```
3. La llave de firma (`upload-keystore.jks`) está asegurada vía `key.properties`. No alterar estos archivos.

---
**Powered by InSOFT © 2026** - *Convertimos ideas en Software que funciona.*
