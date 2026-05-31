
import 'package:flutter/foundation.dart';
import 'modelo_usuario.dart';
import '../services/api_client.dart' as api_ext;


/// Repositorio exclusivo para operaciones con la Base de Datos Remota (vía API), Local y Storage.
class RepositorioUsuarios {
  
  //-------------------------------------------------------------------------
  // 0. VERIFICAR UNICIDAD DE CELULAR
  //-------------------------------------------------------------------------
  Future<bool> verificarCelularEnUso(String celular, {int? excluirId}) async {
    if (celular.isEmpty) return false;
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('verificarCelularEnUso', {
        'celular': celular,
        'excluirId': excluirId
      });
      return res['ok'] == true && res['enUso'] == true;
    } catch (e) {
      debugPrint('Error verificando celular único: $e');
      return false; 
    }
  }

  //-------------------------------------------------------------------------
  // 1. SINCRONIZAR O CREAR USUARIO (Desde Firebase Auth hacia API)
  //-------------------------------------------------------------------------
  Future<Map<String, dynamic>> sincronizarUsuarioBD(String uid, String email, String nombre, String fotoGoogle) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('sincronizarUsuarioBD', {
        'uid': uid,
        'email': email,
        'nombre': nombre,
        'fotoGoogle': fotoGoogle
      });

      if (res['ok'] == true) {
        if (res['status'] == 'bloqueado') {
          return {'error': 'Tu cuenta ha sido bloqueada. Contacta al administrador.'};
        }

        final uMap = res['usuario'];
        final usuarioLocal = Usuario(
          id: uMap['id'] is int ? uMap['id'] : int.tryParse(uMap['id']?.toString() ?? '0') ?? 0,
          uid: uMap['uid']?.toString() ?? '',
          nombre: uMap['nombre']?.toString() ?? '',
          celular: uMap['celular']?.toString() ?? '',
          email: uMap['email']?.toString() ?? '',
          fotoUrl: uMap['foto_url']?.toString() ?? '',
          rol: uMap['rol']?.toString() ?? 'Alumno',
          direccion: uMap['direccion']?.toString() ?? '',
          edad: uMap['edad'] is int ? uMap['edad'] : int.tryParse(uMap['edad']?.toString() ?? '0') ?? 0,
          sexo: uMap['sexo']?.toString() ?? '',
          estado: uMap['estado']?.toString() ?? 'activo',
        );

        if (res['status'] == 'UsuarioNuevo' || usuarioLocal.celular.isEmpty) {
           return {'status': res['status'] ?? 'UsuarioIncompleto', 'usuario': usuarioLocal}; 
        }
        return {'status': 'OK', 'usuario': usuarioLocal};
      }
      return {'error': 'Respuesta de API inválida'};
    } catch (e) {
      debugPrint('Error Repositorio API - Sincronizar: $e');
      return {'error': 'Error de Conexión API: $e'};
    }
  }

  //-------------------------------------------------------------------------
  // 2. CREAR USUARIO FULL PERFIL (Legacy / Auxiliar)
  //-------------------------------------------------------------------------
  Future<String?> insertarUsuarioEnBD({
    required String nombre, required String email, required String celular,
    required String direccion, required int edad, required String sexo
  }) async {
    // Reutilizamos guardarPerfilCompletado en el back o creamos wrapper
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('guardarPerfilCompletado', {
        'uid': 'legacy_${DateTime.now().millisecondsSinceEpoch}',
        'nombre': nombre,
        'email': email,
        'celular': celular,
        'direccion': direccion,
        'edad': edad,
        'sexo': sexo
      });
      return res['ok'] == true ? null : 'Error en API';
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  //-------------------------------------------------------------------------
  // 3. COMPLETAR PERFIL INCOMPLETO
  //-------------------------------------------------------------------------
  Future<Usuario?> guardarPerfilCompletado(Usuario usuarioBase, String nombre, String celular, String direccion, int edad, String sexo) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('guardarPerfilCompletado', {
        'id': usuarioBase.id,
        'uid': usuarioBase.uid,
        'email': usuarioBase.email,
        'nombre': nombre,
        'celular': celular,
        'direccion': direccion,
        'edad': edad,
        'sexo': sexo,
        'fotoUrl': usuarioBase.fotoUrl
      });

      if (res['ok'] == true) {
        return usuarioBase.copyWith(
          id: res['id'] ?? usuarioBase.id, 
          nombre: nombre, 
          celular: celular, 
          direccion: direccion, 
          edad: edad, 
          sexo: sexo
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error guardando perfil completado: $e');
      return null;
    }
  }

  //-------------------------------------------------------------------------
  // 4. ACTUALIZAR CELULAR O FOTO (API DIRECTA)
  //-------------------------------------------------------------------------
  Future<Usuario?> actualizarElementoUsuario(Usuario usuarioActual, {String? nombre, String? celular, String? fotoUrl, String? fcmToken}) async {
    try {
      final usuarioActualizado = usuarioActual.copyWith(
        nombre: nombre ?? usuarioActual.nombre,
        celular: celular ?? usuarioActual.celular,
        fotoUrl: fotoUrl ?? usuarioActual.fotoUrl
      );
      
      // Sincronizar con API directamente
      try {
        final api = api_ext.ApiClient();
        final res = await api.post('actualizarElementoUsuario', {
          'id': usuarioActual.id,
          'nombre': nombre,
          'celular': celular ?? usuarioActual.celular,
          'fotoUrl': fotoUrl ?? usuarioActual.fotoUrl,
          'fcmToken': fcmToken
        });
        
        if (res['ok'] != true) {
           return null;
        }
      } catch (e) {
        debugPrint('Error actualizando elemento en la API: $e');
        return null;
      }

      return usuarioActualizado;
    } catch (e) {
      return null;
    }
  }

  //-------------------------------------------------------------------------
  // 5. EXONERACIONES DE ACTIVIDADES
  //-------------------------------------------------------------------------
  Future<List<int>> obtenerExoneracionesUsuario(int usuarioId) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerExoneracionesUsuario', {
        'usuarioId': usuarioId,
      });
      if (res['ok'] == true && res['actividades'] != null) {
        return List<int>.from(res['actividades']);
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo exoneraciones del repositorio: $e');
      return [];
    }
  }

  Future<bool> guardarExoneracion(int usuarioId, int actividadId, bool exonerado) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('guardarExoneracion', {
        'usuarioId': usuarioId,
        'actividadId': actividadId,
        'exonerado': exonerado,
      });
      return res['ok'] == true;
    } catch (e) {
      debugPrint('Error guardando exoneración en el repositorio: $e');
      return false;
    }
  }
}
