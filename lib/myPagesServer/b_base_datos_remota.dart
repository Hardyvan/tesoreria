import 'package:mysql1/mysql1.dart';
import 'package:flutter/foundation.dart';
import 'a_configuracion_db.dart';

class BaseDatosRemota {
  static MySqlConnection? _conexion;

  // Método para obtener conexión
  Future<MySqlConnection> obtenerConexion() async {
    if (_conexion != null) {
      // Verificar si sigue abierta
      // Nota: mysql1 no tiene un método directo 'isOpen', manejamos errores en query
      return _conexion!;
    }

    final settings = ConnectionSettings(
      host: ConfiguracionDB.host,
      port: ConfiguracionDB.puerto,
      user: ConfiguracionDB.usuario,
      password: ConfiguracionDB.password,
      db: ConfiguracionDB.nombreBaseDatos,
    );

    try {
      _conexion = await MySqlConnection.connect(settings);
      return _conexion!;
    } catch (e) {
      debugPrint('Error conectando a MySQL: $e');
      rethrow;
    }
  }

  // Método para cerrar conexión
  Future<void> cerrarConexion() async {
    await _conexion?.close();
    _conexion = null;
  }
}
