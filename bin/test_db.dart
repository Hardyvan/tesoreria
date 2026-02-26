import 'dart:developer';
import 'package:dsi/myPagesServer/b_base_datos_remota.dart';

void main() async {
  log('Iniciando...');
  final db = BaseDatosRemota();
  final conn = await db.obtenerConexion();
  log('Conexion obtenida');
  
  try {
    final res = await conn.query('DESCRIBE DSI_salon_usuarios');
    log('Columnas de DSI_salon_usuarios:');
    for (var row in res) {
      log('- ${row[0]} ${row[1]}');
    }
  } catch(e) {
    log('Error DESCRIBE: $e');
  }

  try {
    final res2 = await conn.query('SELECT id, nombre, email, rol, estado, updated_at FROM DSI_salon_usuarios');
    log('\nUsuarios en DSI_salon_usuarios:');
    for (var row in res2) {
      log('ID: ${row[0]}, Nombre: ${row[1]}, Email: ${row[2]}, Rol: ${row[3]}, Estado: ${row[4]}, Updated: ${row[5]}');
    }
  } catch(e) {
    log('Error SELECT: $e');
  }
  
  await conn.close();
  log('Fin.');
}
