# Guía de Compilación Segura (Anti-Hacking) 🛡️

Para asegurar que tu aplicación "DSI Tesorería" sea resistente a la ingeniería inversa (descompilación) y proteger tus credenciales maestras, **NUNCA** utilices el comando `flutter build apk` normal.

Utiliza siempre uno de los siguientes comandos ofuscados cuando vayas a mandar la app a producción o a tus compañeros:

## 1. Para compilar un APK (Instalación directa)
Abre tu terminal en la raíz de `tesoreria_ivan` y ejecuta:
```bash
flutter build apk --release --obfuscate --split-debug-info=./debug_info
```

## 2. Para compilar un AppBundle (Subir a Play Store)
Abre tu terminal en la raíz de `tesoreria_ivan` y ejecuta:
```bash
flutter build appbundle --release --obfuscate --split-debug-info=./debug_info
```

### ¿Qué hace `--obfuscate`?
Marea el código fuente. Cambia todos los nombres de tus variables, clases y funciones (como `ControladorAuth` o `logan1992`) a letras aleatorias como `a, b, c, x, y, z`. Si un hacker descarga tu APK e intenta leer tu código Dart, solo verá texto sin sentido y lógico roto.

### ¿Qué hace `--split-debug-info`?
Extrae los nombres reales (tu código legible) y los guarda en una carpeta privada en tu computadora llamada `debug_info`. De esa manera, los nombres reales nunca viajan dentro del APK hacia el teléfono de tus compañeros.
