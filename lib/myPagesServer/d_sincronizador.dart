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
      debugPrint("☁️ Iniciando descarga de datos...");
      
      final conn = await _dbRemota.obtenerConexion();
      
      // Consultar usuarios remotos
      final results = await conn.query(
        'SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM salon_usuarios'
      );

      for (var fila in results) {
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
          estado: _convertir(fila['estado'] ?? 'activo'),
        );

        // Guardar en local (marcándolo como 'sincronizado')
        await _dbLocal.insertarUsuario(usuario, sincronizado: true);
      }
      debugPrint("✅ Datos descargados y guardados localmente (${results.length} usuarios).");

    } catch (e) {
      debugPrint("❌ Error descargando datos: $e");
    }
  }

  // 2. SUBIR CAMBIOS PENDIENTES (SQLite -> MySQL)
  Future<void> subirCambios() async {
    try {
      debugPrint("⬆️ Buscando cambios pendientes...");
      final pendientes = await _dbLocal.obtenerNoSincronizados();

      if (pendientes.isEmpty) {
        debugPrint("✅ No hay cambios pendientes para subir.");
        return;
      }

      final conn = await _dbRemota.obtenerConexion();

      for (var user in pendientes) {
        debugPrint("Sincronizando usuario: ${user.nombre}...");
        
        // Estrategia simple: UPDATE directo basado en ID
        // (Asumimos que la Nube es la verdad, pero aquí sobreescribimos con lo local)
        await conn.query(
          'UPDATE salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
          [user.celular, user.direccion, user.edad, user.sexo, user.id]
        );

        // Marcar como sincronizado
        await _dbLocal.marcarSincronizado(user.id);
      }

      debugPrint("✅ Todos los cambios pendientes fueron subidos.");

    } catch (e) {
      debugPrint("❌ Error subiendo cambios: $e");
    }
  }

  // 3. SINCRONIZACIÓN COMPLETA
  Future<void> sincronizarTodo() async {
    // Primero subimos lo local para no perder datos
    await subirCambios();
    // Luego bajamos lo último de la nube
    await descargarDatosNube();
  }

  String _convertir(dynamic valor) => valor?.toString() ?? '';
}
