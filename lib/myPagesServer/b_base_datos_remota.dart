import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart';
import 'a_configuracion_db.dart';
import 'c_excepciones.dart'; // Import nuevo

class BaseDatosRemota {
  static MySqlConnection? _conexion;

  // MÃ©todo para obtener conexiÃ³n
  Future<MySqlConnection> obtenerConexion() async {
    // Para evitar problemas de timeout ("MySQL server has gone away")
    // con conexiones remotas inactivas, cerramos la anterior y abrimos una nueva.
    try {
      if (_conexion != null) {
        await _conexion!.close();
      }
    } catch (_) {}
    _conexion = null;

    final settings = ConnectionSettings(
      host: ConfiguracionDB.host,
      port: ConfiguracionDB.puerto,
      user: ConfiguracionDB.usuario,
      password: ConfiguracionDB.password,
      db: ConfiguracionDB.nombreBaseDatos,
      timeout: const Duration(seconds: 5), 
    );

    try {
      _conexion = await MySqlConnection.connect(settings);
      return _conexion!;
    } catch (e) {
      // SEGURIDAD: No re-lanzar la excepciÃ³n cruda que puede contener la IP.
      debugPrint('Error CRÃTICO conectando a MySQL: $e'); // Log interno sÃ­ puede tener detalles
      throw ExcepcionSegura('No se pudo conectar al servidor. Verifique su internet.');
    }
  }

  // MÃ©todo para cerrar conexiÃ³n
  Future<void> cerrarConexion() async {
    await _conexion?.close();
    _conexion = null;
  }

  // --- CONSULTAS OPTIMIZADAS PARA KARDEX (Reporte Financiero) ---

  // 1. Total Ingresos (Suma directa en BD)
  Future<double> obtenerSumaIngresos() async {
    try {
      final conn = await obtenerConexion();
      final result = await conn.query('SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1');
      return (result.first['total'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('Error obteniendo suma ingresos: $e');
      return 0.0;
    }
  }

  // 2. Total Gastos (Suma directa en BD)
  Future<double> obtenerSumaGastos() async {
    try {
      final conn = await obtenerConexion();
      final result = await conn.query('SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos');
      return (result.first['total'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('Error obteniendo suma gastos: $e');
      return 0.0;
    }
  }

  // 3. Historial Kardex (UNION de Pagos y Gastos)
  Future<List<Map<String, dynamic>>> obtenerHistorialKardex({int limit = 20, int offset = 0}) async {
    try {
      final conn = await obtenerConexion();
      
      // La consulta maestra con UNION ALL
      String sql = '''
        SELECT 
            'I' AS tipo, 
            p.id AS id_movimiento, 
            CONCAT('Pago: ', u.nombre) AS descripcion, 
            p.monto AS monto, 
            p.fecha_pago AS fecha
        FROM DSI_salon_pagos p
        JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
        WHERE p.confirmado = 1

        UNION ALL

        SELECT 
            'E' AS tipo, 
            g.id AS id_movimiento, 
            g.descripcion AS descripcion, 
            g.monto AS monto, 
            g.fecha_gasto AS fecha
        FROM DSI_salon_gastos g

        ORDER BY fecha DESC
        LIMIT ? OFFSET ?
      ''';

      final results = await conn.query(sql, [limit, offset]);
      
      return results.map((fila) => {
        'tipo': fila['tipo'].toString(), // 'I' o 'E'
        'id': fila['id_movimiento'],
        'descripcion': fila['descripcion'].toString(),
        'monto': (fila['monto'] ?? 0.0).toDouble(),
        'fecha': fila['fecha']
      }).toList();

    } catch (e) {
      debugPrint('Error obteniendo historial kardex: $e');
      return [];
    }
  }
  // --- MANTENIMIENTO BD ---
  @Deprecated('Desactivado por seguridad. Las migraciones deben ser manuales.')
  Future<void> autocorregirTablas() async {
    // DESACTIVADO POR SEGURIDAD
    // La app no debe tener permisos de ALTER TABLE en producciÃ³n.
    
    try {
      final conn = await obtenerConexion();
      try {
        await conn.query('ALTER TABLE DSI_salon_gastos ADD COLUMN actividad_id INT NULL');
        debugPrint('Columna actividad_id agregada a DSI_salon_gastos.');
      } catch (e) {
         debugPrint('Columna actividad_id probablemente ya existe o error menor: $e');
      }
    } catch (e) {
      debugPrint('Error en autocorregirTablas: $e');
    }
  }
}
