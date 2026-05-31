import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_client.dart' as api_ext;
import 'modelo_usuario.dart';
import 'm_repositorio_usuarios.dart';

import 'dart:async';

class ControladorUsuarios extends ChangeNotifier {
  List<Usuario> _usuarios = [];
  bool _cargando = false;

  List<Usuario> get usuarios => _usuarios;
  bool get cargando => _cargando;

  // Listar todos los usuarios (Directo desde la API)
  Future<void> listarUsuarios() async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('listarUsuariosCompleto', {});
      
      if (res['ok'] == true && res['datos'] != null) {
        final List<dynamic> lista = res['datos'];
        _usuarios = lista.map((u) {
          String estadoLocal = 'activo';
          final estadoRaw = u['estado'];
          if (estadoRaw != null) {
            if (estadoRaw.toString() == '1' || estadoRaw == true || estadoRaw.toString().toLowerCase() == 'activo') {
              estadoLocal = 'activo';
            } else {
              estadoLocal = 'inactivo';
            }
          }
          
          return Usuario(
            id: u['id'] is int ? u['id'] : int.tryParse(u['id'].toString()) ?? 0,
            nombre: u['nombre']?.toString() ?? '',
            celular: u['celular']?.toString() ?? '',
            uid: u['uid']?.toString() ?? '',
            email: u['email']?.toString() ?? '',
            fotoUrl: u['foto_url']?.toString() ?? '',
            rol: u['rol']?.toString() ?? 'Alumno',
            direccion: u['direccion']?.toString() ?? '',
            edad: u['edad'] is int ? u['edad'] : int.tryParse(u['edad'].toString()) ?? 0,
            sexo: u['sexo']?.toString() ?? '',
            estado: estadoLocal,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error listando usuarios de la API: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }



  // Actualizar Rol (Solo Admin/SuperAdmin)
  Future<bool> actualizarRol(int idUsuario, String nuevoRol) async {
    try {
      final api = api_ext.ApiClient();
      // adminUid se inyecta automáticamente por ApiClient; el backend revalida el rol real desde la BD
      final res = await api.post('cambiarRolUsuario', {
        'targetId': idUsuario,
        'nuevoRol': nuevoRol,
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
          _usuarios[index] = _usuarios[index].copyWith(rol: nuevoRol);
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

  // Actualizar Nombre (Admin/SuperAdmin o el propio usuario)
  Future<bool> actualizarNombre(int idUsuario, String nuevoNombre) async {
    try {
      final api = api_ext.ApiClient();
      // adminUid se inyecta automáticamente; el backend valida: dueño del perfil o admin
      final res = await api.post('actualizarElementoUsuario', {
        'id': idUsuario,
        'nombre': nuevoNombre,
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
          _usuarios[index] = _usuarios[index].copyWith(nombre: nuevoNombre);
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
  // Cambiar Estado (Bloquear/Desbloquear) - Solo Admin/SuperAdmin
  Future<bool> cambiarEstadoUsuario(int idUsuario, String nuevoEstado) async {
    try {
      final api = api_ext.ApiClient();
      // adminUid se inyecta automáticamente; el backend revalida el rol real
      final res = await api.post('cambiarEstadoUsuario', {
        'targetId': idUsuario,
        'nuevoEstado': nuevoEstado,
      });
      
      if (res['ok'] == true) {
        final index = _usuarios.indexWhere((u) => u.id == idUsuario);
        if (index != -1) {
           _usuarios[index] = _usuarios[index].copyWith(estado: nuevoEstado);
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
    try {
      if (email.isEmpty) return false;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return true; 
    } catch (e) {
      debugPrint('Error enviando correo de reset: $e');
      return false;
    }
  }

  // Eliminar Usuario (Solo Admin/SuperAdmin)
  Future<bool> eliminarUsuario(int idUsuario) async {
    try {
      final api = api_ext.ApiClient();
      // adminUid se inyecta automáticamente; el backend revalida el rol real
      final res = await api.post('eliminarUsuario', {
        'targetId': idUsuario,
      });

      if (res['ok'] == true) {
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

  // Obtener exoneraciones de un usuario
  Future<List<int>> obtenerExoneraciones(int usuarioId) async {
    try {
      final repo = RepositorioUsuarios();
      return await repo.obtenerExoneracionesUsuario(usuarioId);
    } catch (e) {
      debugPrint('Error en obtenerExoneraciones: $e');
      return [];
    }
  }

  // Guardar exoneración
  Future<bool> guardarExoneracion(int usuarioId, int actividadId, bool exonerado) async {
    try {
      final repo = RepositorioUsuarios();
      final exito = await repo.guardarExoneracion(usuarioId, actividadId, exonerado);
      if (exito) {
        notifyListeners();
      }
      return exito;
    } catch (e) {
      debugPrint('Error en guardarExoneracion: $e');
      return false;
    }
  }
}
