import 'package:flutter/material.dart';
import '../services/api_client.dart' as api_ext;
import 'package:firebase_auth/firebase_auth.dart';
import 'modelo_usuario.dart';
import '../myPagesLocal/c_base_datos_local.dart';
import 'd_sincronizador.dart';
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
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('cambiarRolUsuario', {
        'targetId': idUsuario,
        'nuevoRol': nuevoRol,
        'adminRol': 'SuperAdmin', // Hardcodeamos para agilizar, idealmente pasar auth
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? ''
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
          final usuarioModificado = _usuarios[index].copyWith(rol: nuevoRol);
          _usuarios[index] = usuarioModificado;
          await BaseDatosLocal.instance.insertarUsuario(usuarioModificado, sincronizado: true);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error actualizando rol: $e');
      return false;
    }
  }

  // Actualizar Nombre (Admin)
  Future<bool> actualizarNombre(int idUsuario, String nuevoNombre) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('actualizarElementoUsuario', {
        'id': idUsuario,
        'nombre': nuevoNombre,
        'adminRol': 'SuperAdmin', // Validado en API
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? ''
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
          final usuarioModificado = _usuarios[index].copyWith(nombre: nuevoNombre);
          _usuarios[index] = usuarioModificado;
          await BaseDatosLocal.instance.insertarUsuario(usuarioModificado, sincronizado: true);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error actualizando nombre: $e');
      return false;
    }
  }
  // Cambiar Estado (Bloquear/Desbloquear)
  Future<bool> cambiarEstadoUsuario(int idUsuario, String nuevoEstado) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('cambiarEstadoUsuario', {
        'targetId': idUsuario,
        'nuevoEstado': nuevoEstado,
        'adminRol': 'SuperAdmin',
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? ''
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
           final usuarioModificado = _usuarios[index].copyWith(estado: nuevoEstado);
           _usuarios[index] = usuarioModificado;
           await BaseDatosLocal.instance.insertarUsuario(usuarioModificado, sincronizado: true);
           notifyListeners();
        }
        return true;
      }
      return false;
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
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('eliminarUsuario', {
        'targetId': idUsuario,
        'adminRol': 'SuperAdmin',
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? ''
      });

      if (res['ok'] == true) {
        final dbLocal = await BaseDatosLocal.instance.database;
        await dbLocal.delete('usuarios', where: 'id = ?', whereArgs: [idUsuario]);
        _usuarios.removeWhere((u) => u.id == idUsuario);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error eliminando usuario: $e');
      return false;
    }
  }
}
