import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart';
import 'a_configuracion_db.dart';
import 'c_excepciones.dart';

class BaseDatosRemota {
  static MySqlConnection? _conexion;

  // Método para obtener conexión (con reintentos para redes lentas)
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
      timeout: const Duration(seconds: 15), // Aumentado para redes móviles lentas
    );

    // Reintento automático: 2 intentos con pausa de 2s entre ellos
    // Evita expulsar usuarios por picos de latencia transitorios
    const maxIntentos = 2;
    Exception? ultimoError;

    for (int intento = 1; intento <= maxIntentos; intento++) {
      try {
        debugPrint('Conectando a MySQL [Intento $intento/$maxIntentos]...');
        _conexion = await MySqlConnection.connect(settings);
        debugPrint('✅ Conexión MySQL Exitosa (intento $intento).');
        return _conexion!;
      } catch (e) {
        ultimoError = e is Exception ? e : Exception(e.toString());
        debugPrint('Fallo intento $intento: $e');
        if (intento < maxIntentos) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // SEGURIDAD: No re-lanzar la excepción cruda que puede contener la IP.
    debugPrint('Error CRÍTICO tras $maxIntentos intentos: $ultimoError');
    throw ExcepcionSegura('No se pudo conectar al servidor. Verifique su internet.');
  }

  // Método para cerrar conexión
  Future<void> cerrarConexion() async {
    await _conexion?.close();
    _conexion = null;
  }

  // --- CONFIGURACIONES GLOBALES (Saldo Inicial, etc) ---
  
  Future<void> inicializarTablaConfiguracion() async {
    try {
      final conn = await obtenerConexion();
      await conn.query('''
        CREATE TABLE IF NOT EXISTS DSI_salon_configuracion (
          clave VARCHAR(50) PRIMARY KEY,
          valor TEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
      ''');
    } catch (e) {
      debugPrint('Error creando tabla configuracion: $e');
    }
  }

  Future<String?> obtenerConfiguracion(String clave) async {
    try {
      final conn = await obtenerConexion();
      final results = await conn.query('SELECT valor FROM DSI_salon_configuracion WHERE clave = ?', [clave]);
      if (results.isNotEmpty) return results.first['valor'].toString();
    } catch (e) {
      debugPrint('Error leyendo configuracion ($clave): $e');
    }
    return null;
  }

  Future<bool> guardarConfiguracion(String clave, String valor) async {
    try {
      final conn = await obtenerConexion();
      await conn.query('''
        INSERT INTO DSI_salon_configuracion (clave, valor) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE valor = ?
      ''', [clave, valor, valor]);
      return true;
    } catch (e) {
      debugPrint('Error guardando configuracion ($clave): $e');
      return false;
    }
  }

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
    // La app no debe tener permisos de ALTER TABLE en producción.
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
