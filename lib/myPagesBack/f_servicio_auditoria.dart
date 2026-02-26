import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../myPagesServer/b_base_datos_remota.dart';

class ServicioAuditoria {
  static final ServicioAuditoria _instancia = ServicioAuditoria._internal();
  factory ServicioAuditoria() => _instancia;
  ServicioAuditoria._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Registra una acciÃ³n sensible en la base de datos de auditorÃ­a
  Future<void> registrarAccion({
    required String accion, 
    required String detalle,
    int? usuarioId, // ID del admin en MySQL (si se tiene)
  }) async {
    try {
      // 1. Obtener informaciÃ³n del dispositivo
      String infoDispositivo = await _obtenerNombreDispositivo();
      
      // 2. Obtener ID del Admin (si no se pasÃ³)
      int adminId = usuarioId ?? await _obtenerIdAdminActual();
      
      if (adminId == -1) {
        debugPrint('AUDITORÃA: No se pudo identificar al admin. AcciÃ³n no registrada.');
        return;
      }

      // 3. Insertar en BD
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      // Asegurar tabla (simple check, idealmente esto va en script de migraciÃ³n)
      /* 
      CREATE TABLE IF NOT EXISTS DSI_salon_auditoria (
        id INT AUTO_INCREMENT PRIMARY KEY,
        admin_id INT NOT NULL,
        accion VARCHAR(255),
        detalle TEXT,
        dispositivo VARCHAR(255),
        fecha DATETIME,
        FOREIGN KEY (admin_id) REFERENCES DSI_salon_usuarios(id)
      );
      */

      await conn.query(
        'INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, ?, ?, ?, NOW())',
        [adminId, accion, detalle, infoDispositivo]
      );
      
      debugPrint('AUDITORÃA: AcciÃ³n registrada ($accion) desde $infoDispositivo');

    } catch (e) {
      debugPrint('ERROR AUDITORÃA: $e');
      // Fallo silencioso para no interrumpir el flujo principal
    }
  }

  /// Obtiene un nombre legible del dispositivo (ej: "Samsung S21", "iPhone 13")
  Future<String> _obtenerNombreDispositivo() async {
    try {
      // DeviceInfoPlugin deviceInfo = DeviceInfoPlugin(); // REMOVED local instance
      if (kIsWeb) {
        WebBrowserInfo webInfo = await _deviceInfo.webBrowserInfo;
        return '${webInfo.browserName.name} (${webInfo.platform})';
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.systemName}';
      } else if (Platform.isWindows) {
        WindowsDeviceInfo winInfo = await _deviceInfo.windowsInfo;
        return 'PC Windows (${winInfo.computerName})';
      }
      return 'Dispositivo Desconocido';
    } catch (e) {
      return 'Error Info Dispositivo';
    }
  }

  Future<int> _obtenerIdAdminActual() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return -1; // No logueado

      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      var result = await conn.query('SELECT id FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
      
      if (result.isNotEmpty) {
        return result.first['id'];
      }
      return -1;
    } catch (e) {
      return -1;
    }
  }

  // --- SOLO PARA SUPER ADMIN ---
  Future<List<Map<String, dynamic>>> obtenerLogsAuditoria() async {
    try {
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      // Join para ver el nombre del admin
      final results = await conn.query('''
        SELECT a.id, u.nombre as admin_nombre, u.rol, a.accion, a.detalle, a.dispositivo, a.fecha
        FROM DSI_salon_auditoria a
        JOIN DSI_salon_usuarios u ON a.admin_id = u.id
        ORDER BY a.fecha DESC
        LIMIT 100
      ''');

      return results.map((fila) => {
        'id': fila['id'],
        'admin': fila['admin_nombre'].toString(),
        'rol': fila['rol'].toString(),
        'accion': fila['accion'].toString(),
        'detalle': fila['detalle'].toString(),
        'dispositivo': fila['dispositivo'].toString(),
        'fecha': fila['fecha']
      }).toList();

    } catch (e) {
      debugPrint('Error obteniendo logs: $e');
      return [];
    }
  }

  /// Obtiene el resumen de dinero recaudado por cada admin en una fecha especÃ­fica
  Future<List<Map<String, dynamic>>> obtenerResumenCaja(DateTime fecha) async {
    try {
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      // Ajustar rango del dÃ­a
      final inicio = DateTime(fecha.year, fecha.month, fecha.day, 0, 0, 0);
      final fin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      // Traer solo logs de pagos del dÃ­a
      final results = await conn.query('''
        SELECT u.nombre as admin_nombre, a.detalle
        FROM DSI_salon_auditoria a
        JOIN DSI_salon_usuarios u ON a.admin_id = u.id
        WHERE a.accion = 'Registrar Pago' 
          AND a.fecha BETWEEN ? AND ?
      ''', [inicio, fin]);

      // Agrupar en Memoria (DART) para no complicar SQL parsing de texto
      Map<String, double> totales = {};

      for (var row in results) {
        String admin = row['admin_nombre'].toString();
        String detalle = row['detalle'].toString();
        
        // Parsear monto del texto "Monto: S/ 50.00 - ..."
        // Formato esperado: "Monto: S/ 150.00 - Alumno ID..."
        try {
          // Buscamos el valor entre "S/ " y " -"
          final parteMonto = detalle.split('S/ ')[1].split(' -')[0];
          double monto = double.parse(parteMonto);
          
          if (!totales.containsKey(admin)) totales[admin] = 0.0;
          totales[admin] = totales[admin]! + monto;
        } catch (e) {
          debugPrint('Error parseando monto auditorÃ­a: $e');
        }
      }

      // Convertir a lista ordenada
      final lista = totales.entries.map((e) => {
        'admin': e.key,
        'total': e.value
      }).toList();
      
      lista.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      
      return lista;

    } catch (e) {
      debugPrint('Error resumen caja: $e');
      return [];
    }
  }
}
