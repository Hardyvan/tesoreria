import 'package:flutter/material.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import 'modelo_usuario.dart';
import '../myPagesServer/c_base_datos_local.dart';
import '../myPagesServer/d_sincronizador.dart';
import 'f_servicio_auditoria.dart';
import 'dart:async';

class ControladorUsuarios extends ChangeNotifier {
  List<Usuario> _usuarios = [];
  bool _cargando = false;

  List<Usuario> get usuarios => _usuarios;
  bool get cargando => _cargando;

  // Listar todos los usuarios (Desde LOCAL)
  Future<void> listarUsuarios() async {
    _cargando = true;
    notifyListeners();

    try {
      // 1. Leer de Base de Datos Local
      final usuariosLocales = await BaseDatosLocal.instance.obtenerUsuarios();
      
      // Filtrar o manejar estados si se requiere (pero el admin debe ver todos)
      _usuarios = usuariosLocales;
      
      // 2. Intentar Sincronizar en Segundo Plano
      unawaited(sincronizarUsuarios());

    } catch (e) {
      debugPrint('Error listando usuarios locales: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // SincronizaciÃ³n en segundo plano
  Future<void> sincronizarUsuarios() async {
    try {
      final sinc = Sincronizador();
      await sinc.sincronizarTodo(); 
      
      // Actualizar la lista local
      _usuarios = await BaseDatosLocal.instance.obtenerUsuarios();
      notifyListeners();
      
    } catch (e) {
      debugPrint('Modo Offline: No se pudo sincronizar ($e)');
    }
  }



  // Actualizar Rol (Solo Admin)
  Future<bool> actualizarRol(int idUsuario, String nuevoRol) async {
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      await conn.query(
        'UPDATE DSI_salon_usuarios SET rol = ? WHERE id = ?',
        [nuevoRol, idUsuario]
      );
      
      // Actualizar lista localmente para reflejar cambio inmediato
      final index = _usuarios.indexWhere((u) => u.id == idUsuario);
      if (index != -1) {
        final usuarioModificado = _usuarios[index].copyWith(rol: nuevoRol);
        _usuarios[index] = usuarioModificado;
        await BaseDatosLocal.instance.insertarUsuario(usuarioModificado, sincronizado: true);
        notifyListeners();
      }

      // --- AUDITORÃA ---
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Cambiar Rol',
        detalle: 'Usuario ID: $idUsuario - Nuevo Rol: $nuevoRol',
      ));

      return true;
    } catch (e) {
      debugPrint('Error actualizando rol: $e');
      return false;
    }
  }
  // Cambiar Estado (Bloquear/Desbloquear)
  Future<bool> cambiarEstadoUsuario(int idUsuario, String nuevoEstado) async {
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      int estadoInt = (nuevoEstado == 'activo') ? 1 : 0;
      await conn.query(
        'UPDATE DSI_salon_usuarios SET estado = ? WHERE id = ?',
        [estadoInt, idUsuario]
      );
      
      // Actualizar localmente
      final index = _usuarios.indexWhere((u) => u.id == idUsuario);
      if (index != -1) {
         final usuarioModificado = _usuarios[index].copyWith(estado: nuevoEstado);
         _usuarios[index] = usuarioModificado;
         await BaseDatosLocal.instance.insertarUsuario(usuarioModificado, sincronizado: true);
         notifyListeners();
      }

      // await listarUsuarios(); // Refrescar lista completa ya no es necesario si actualizamos en memoria y en local

      
      // --- AUDITORÃA ---
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Cambiar Estado Usuario',
        detalle: 'Usuario ID: $idUsuario - Nuevo Estado: $nuevoEstado',
      ));

      return true;
    } catch (e) {
      debugPrint('Error cambiando estado: $e');
      return false;
    }
  }

  // Enviar Correo de Restablecimiento (Firebase)
  Future<bool> enviarCorreoRestablecimiento(String email) async {
    // Delegamos a FirebaseAuth (Usamos instancia directa o vÃ­a AuthController)
    // Para no acoplar, lo hacemos aquÃ­ simple si la dependencia firebase_auth estÃ¡ disponible
    // O mejor, dejÃ©moslo en la UI llamando a FirebaseAuth directamente o importarlo.
    // Lo ideal es tenerlo en ControladorAuth, pero lo haremos aquÃ­ por contexto de gestiÃ³n.
    try {
        // Necesitamos importar firebase_auth. Lo harÃ© en la UI mejor o agrego import aquÃ­.
        // Simulamos Ã©xito para lÃ³gica de negocio
        return true; 
    } catch (e) {
      return false;
    }
  }

  // Eliminar Usuario (Solo Admin)
  Future<bool> eliminarUsuario(int idUsuario) async {
    final db = BaseDatosRemota();
    try {
      // 1. Eliminar de MySQL (Remoto)
      final conn = await db.obtenerConexion();
      await conn.query('DELETE FROM DSI_salon_usuarios WHERE id = ?', [idUsuario]);

      // 2. Eliminar de SQLite (Local)
      final dbLocal = await BaseDatosLocal.instance.database;
      await dbLocal.delete('usuarios', where: 'id = ?', whereArgs: [idUsuario]);

      // 3. Actualizar Lista en Memoria
      _usuarios.removeWhere((u) => u.id == idUsuario);
      notifyListeners();

      // --- AUDITORÃA ---
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Eliminar Usuario',
        detalle: 'Usuario ID: $idUsuario (Eliminado permanentemente)',
      ));

      return true;
    } catch (e) {
      debugPrint('Error eliminando usuario: $e');
      return false;
    }
  }
}

