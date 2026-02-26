# Protocolo de MigraciÃ³n de Base de Datos - InSOFT TesorerÃ­a

Este protocolo detalla los pasos a seguir cada vez que la aplicaciÃ³n necesite conectarse a un nuevo servidor MySQL o restaurar su estructura desde cero.

## 1. Archivo de ConexiÃ³n (`.env`)
La aplicaciÃ³n Flutter toma sus credenciales de forma segura desde el archivo `.env` ubicado en la raÃ­z del proyecto.
Cuando cambies de servidor, debes editar este archivo exclusivamente:

```env
DB_HOST=192.168.1.100 (Tu nueva IP o dominio)
DB_PORT=3306
DB_USER=usuario_bd
DB_PASS=tu_password
DB_NAME=nombre_base_datos
DB_SSL=0 (Recomendado 0 si no tienes certificados SSL internos)
```

## 2. RecreaciÃ³n de Estructura (Tablas)
La app espera encontrar 5 tablas especÃ­ficas con relaciones (Llaves ForÃ¡neas) precisas para proteger la integridad del Kardex.

1. **Abre tu gestor de Base de Datos** (ej. phpMyAdmin, DBeaver, HeidiSQL).
2. ConÃ©ctate al nuevo servidor usando las credenciales del punto 1.
3. Importa o ejecuta el contenido completo del archivo `01_esquema_inicial.sql` (ubicado en esta misma carpeta `basedatos/`).
   
### Tablas Creadas por el Script
*   `DSI_salon_usuarios`: Guarda alumnos, administradores y super admins.
*   `DSI_salon_actividades`: Eventos (ej. "Semana 1", "DÃ­a de la Madre") con un costo establecido.
*   `DSI_salon_pagos`: Dinero que ENTRA a la tesorerÃ­a (vinculado a un Usuario y a una Actividad).
*   `DSI_salon_gastos`: Dinero que SALE de la tesorerÃ­a.
*   `DSI_salon_auditoria`: Registro de seguridad de quiÃ©n borrÃ³ o modificÃ³ registros crÃ­ticos.

## 3. Consideraciones de Red (Android)
Si intentas conectar la app desde un celular fÃ­sico hacia un servidor externo, recuerda siempre verificar dos cosas ajenas al cÃ³digo Dart:

*   **Permiso de Internet:** El celular debe tener `<uses-permission android:name="android.permission.INTERNET" />` activado (ya solucionado).
*   **Firewall del Hosting:** El servidor MySQL (cPanel) debe tener autorizada tu direcciÃ³n IP pÃºblica en su configuraciÃ³n de "MySQL Remoto", o bien usar el comodÃ­n `%` bajo tu propio riesgo.
