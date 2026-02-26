import 'package:flutter/foundation.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import 'c_base_datos_local.dart';
import '../myPagesBack/modelo_usuario.dart';

class Sincronizador {
  final BaseDatosRemota _dbRemota = BaseDatosRemota();
  final BaseDatosLocal _dbLocal = BaseDatosLocal.instance;

  // 1. DESCARGAR DE LA NUBE (MySQL -> SQLite)
  Future<void> descargarDatosNube() async {
    try {
      debugPrint('â˜ï¸ Iniciando descarga de datos...');
      
      final conn = await _dbRemota.obtenerConexion();
      
      // Consultar usuarios remotos
      final results = await conn.query(
        'SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado, updated_at FROM DSI_salon_usuarios'
      );

      for (var fila in results) {
        String estadoLocal = 'activo';
        final estadoRaw = fila['estado'];
        if (estadoRaw != null) {
          if (estadoRaw.toString() == '1' || estadoRaw == true || estadoRaw.toString().toLowerCase() == 'activo') {
            estadoLocal = 'activo';
          } else {
            estadoLocal = 'inactivo';
          }
        }

        final usuario = Usuario(
          id: fila['id'],
          nombre: _convertir(fila['nombre']),
          celular: _convertir(fila['celular']),
          email: _convertir(fila['email']),
          fotoUrl: _convertir(fila['foto_url']),
          rol: _convertir(fila['rol'] ?? 'Alumno'),
          direccion: _convertir(fila['direccion']),
          edad: fila['edad'] ?? 0,
          sexo: _convertir(fila['sexo']),
          estado: estadoLocal,
          updatedAt: fila['updated_at'] != null ? (fila['updated_at'] as DateTime) : null,
        );

        // Guardar en local (marcÃ¡ndolo como 'sincronizado')
        await _dbLocal.insertarUsuario(usuario, sincronizado: true);
      }
      debugPrint('âœ… Datos descargados y guardados localmente (${results.length} usuarios).');

    } catch (e) {
      debugPrint('âŒ Error descargando datos: $e');
    }
  }

  // 2. SUBIR CAMBIOS PENDIENTES (SQLite -> MySQL)
  Future<void> subirCambios() async {
    try {
      debugPrint('â¬†ï¸ Buscando cambios pendientes...');
      final pendientes = await _dbLocal.obtenerNoSincronizados();

      if (pendientes.isEmpty) {
        debugPrint('âœ… No hay cambios pendientes para subir.');
        return;
      }

      final conn = await _dbRemota.obtenerConexion();

      for (var user in pendientes) {
        debugPrint('Sincronizando usuario: ${user.nombre}...');
        
        // 1. Verificar si el remoto es más nuevo
        var remoto = await conn.query('SELECT updated_at FROM DSI_salon_usuarios WHERE id = ?', [user.id]);
        bool sobrescribir = true;
        
        if (remoto.isNotEmpty && remoto.first['updated_at'] != null && user.updatedAt != null) {
          DateTime updatedRemoto = remoto.first['updated_at'] as DateTime;
          if (updatedRemoto.isAfter(user.updatedAt!)) {
            // El remoto es MÁS NUEVO que nuestro cambio pendiente local. 
            // Abortamos la subida de este usuario para no chancar datos recientes.
            sobrescribir = false;
            debugPrint('⚠️ Conflicto: El servidor tiene datos más recientes para ${user.nombre}. Omitiendo subida.');
          }
        }

        if (sobrescribir) {
          await conn.query(
            'UPDATE DSI_salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
            [user.celular, user.direccion, user.edad, user.sexo, user.id]
          );
          debugPrint('✅ Usuario ${user.nombre} actualizado en la nube.');
        }

        // Marcar como sincronizado de todas formas (si no se sobrescribió, en el próximo 'descargarDatosNube' se actualizará la BD local)
        await _dbLocal.marcarSincronizado(user.id);
      }

      debugPrint('âœ… Todos los cambios pendientes fueron subidos.');

    } catch (e) {
      debugPrint('âŒ Error subiendo cambios: $e');
    }
  }

  // 3. SINCRONIZACIÃ“N COMPLETA
  Future<void> sincronizarTodo() async {
    // Primero subimos lo local para no perder datos
    await subirCambios();
    // Luego bajamos lo Ãºltimo de la nube
    await descargarDatosNube();
  }

  String _convertir(dynamic valor) => valor?.toString() ?? '';
}
