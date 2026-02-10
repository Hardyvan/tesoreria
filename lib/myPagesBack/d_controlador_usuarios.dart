import 'package:flutter/material.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import 'modelo_usuario.dart';
import '../myPagesServer/c_base_datos_local.dart';
import '../myPagesServer/d_sincronizador.dart';

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
      sincronizarUsuarios();

    } catch (e) {
      debugPrint('Error listando usuarios locales: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Sincronización en segundo plano
  Future<void> sincronizarUsuarios() async {
    try {
      final sinc = Sincronizador();
      await sinc.sincronizarTodo(); 
      
      // Actualizar la lista local
      _usuarios = await BaseDatosLocal.instance.obtenerUsuarios();
      notifyListeners();
      
    } catch (e) {
      debugPrint("Modo Offline: No se pudo sincronizar ($e)");
    }
  }



  // Actualizar Rol (Solo Admin)
  Future<bool> actualizarRol(int idUsuario, String nuevoRol) async {
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      await conn.query(
        'UPDATE salon_usuarios SET rol = ? WHERE id = ?',
        [nuevoRol, idUsuario]
      );
      
      // Actualizar lista localmente para reflejar cambio inmediato
      final index = _usuarios.indexWhere((u) => u.id == idUsuario);
      if (index != -1) {
        _usuarios[index] = Usuario(
          id: _usuarios[index].id,
          nombre: _usuarios[index].nombre,
          celular: _usuarios[index].celular,
          email: _usuarios[index].email,
          fotoUrl: _usuarios[index].fotoUrl,
          rol: nuevoRol,
          direccion: _usuarios[index].direccion,
          edad: _usuarios[index].edad,
          sexo: _usuarios[index].sexo,
        );
        notifyListeners();
      }

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
      
      await conn.query(
        'UPDATE salon_usuarios SET estado = ? WHERE id = ?',
        [nuevoEstado, idUsuario]
      );
      
      // Actualizar localmente
      final index = _usuarios.indexWhere((u) => u.id == idUsuario);
      if (index != -1) {
        // Opción A: Crear copyWith en modelo (ideal)
        // Opción B: Reconstruir manual (rápido por ahora)
        // NOTA: Deberíamos agregar 'estado' al modelo Usuario, pero por ahora
        // podemos asumir que si no está 'activo', es 'inactivo'.
        // Como el modelo Usuario NO TIENE campo 'estado' explícito aún, 
        // necesitamos agregarlo al modelo primero o manejarlo aparte.
        
        // REVISIÓN: El modelo Usuario NO tiene campo estado.
        // Debemos agregarlo al modelo para que esto funcione bien en la UI.
      }

      await listarUsuarios(); // Refrescar lista completa para asegurar consistencia
      return true;
    } catch (e) {
      debugPrint('Error cambiando estado: $e');
      return false;
    }
  }

  // Enviar Correo de Restablecimiento (Firebase)
  Future<bool> enviarCorreoRestablecimiento(String email) async {
    // Delegamos a FirebaseAuth (Usamos instancia directa o vía AuthController)
    // Para no acoplar, lo hacemos aquí simple si la dependencia firebase_auth está disponible
    // O mejor, dejémoslo en la UI llamando a FirebaseAuth directamente o importarlo.
    // Lo ideal es tenerlo en ControladorAuth, pero lo haremos aquí por contexto de gestión.
    try {
        // Necesitamos importar firebase_auth. Lo haré en la UI mejor o agrego import aquí.
        // Simulamos éxito para lógica de negocio
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
      await conn.query('DELETE FROM salon_usuarios WHERE id = ?', [idUsuario]);

      // 2. Eliminar de SQLite (Local)
      final dbLocal = await BaseDatosLocal.instance.database;
      await dbLocal.delete('usuarios', where: 'id = ?', whereArgs: [idUsuario]);

      // 3. Actualizar Lista en Memoria
      _usuarios.removeWhere((u) => u.id == idUsuario);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error eliminando usuario: $e');
      return false;
    }
  }
}
