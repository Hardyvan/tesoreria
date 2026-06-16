import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'modelo_actividad.dart';
import 'modelo_usuario.dart';
import '../myPagesTema/c_formatos.dart';
import '../services/api_client.dart' as api_ext;
import 'k_gerente_notificaciones.dart';

class ControladorActividades extends ChangeNotifier {
  List<Actividad> _actividades = [];
  bool _cargando = false;

  List<Actividad> get actividades => _actividades;
  bool get cargando => _cargando;

  ControladorActividades() {
    unawaited(cargarCache());
  }

  Future<void> cargarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('cache_actividades');
      if (cacheData != null) {
        final List<dynamic> datos = jsonDecode(cacheData);
        _actividades = datos.map((fila) => Actividad.desdeMapa(Map<String, dynamic>.from(fila))).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando cache de actividades: $e');
    }
  }

  Future<void> _guardarCacheLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listado = _actividades.map((a) => {
        'id': a.id,
        'titulo': a.titulo,
        'costo': a.costo,
        'fecha_creacion': a.fechaCreada.toIso8601String(),
        'fecha_limite': a.fechaLimite?.toIso8601String(),
        'multa_por_dia': a.multaPorDia,
        'requiere_asistencia': a.requiereAsistencia ? 1 : 0,
        'multa_inasistencia': a.multaInasistencia,
      }).toList();
      await prefs.setString('cache_actividades', jsonEncode(listado));
    } catch (e) {
      debugPrint('Error guardando cache actividades: $e');
    }
  }

  // Crear una nueva actividad (Solo Admin)
  Future<bool> crearActividad(String titulo, double costo, Usuario usuario, {
    DateTime? fechaLimite,
    double multaPorDia = 0.0,
    bool requiereAsistencia = false,
    double multaInasistencia = 0.0,
  }) async {
    _cargando = true;
    notifyListeners();
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('crearActividad', {
        'titulo': titulo,
        'costo': costo,
        'fechaLimite': fechaLimite?.toIso8601String().split('T')[0],
        'multaPorDia': multaPorDia,
        'requiereAsistencia': requiereAsistencia,
        'multaInasistencia': multaInasistencia,
        'adminRol': usuario.rol,
        'adminId': usuario.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      
      if (res['ok'] == true) {
        final lastId = res['id'] as int;
        _actividades.insert(0, Actividad(
          id: lastId, 
          titulo: titulo, 
          costo: costo, 
          fechaCreada: DateTime.now(),
          fechaLimite: fechaLimite,
          multaPorDia: multaPorDia,
          requiereAsistencia: requiereAsistencia,
          multaInasistencia: multaInasistencia,
        ));
        unawaited(_guardarCacheLocal());
        
        // Push notification masiva a todos los usuarios del aula
        try {
           unawaited(GerenteNotificaciones.enviarPush(
              tokenDestino: '/topics/tesoreria',
              titulo: '📢 Nueva Actividad Creada',
              cuerpo: 'El administrador ${usuario.nombre.toFirstName()} ha registrado "$titulo" (Costo: ${costo.toSoles()}). ¡Revisa tu estado de cuenta!',
           ));
        } catch (_) {}
        
        return true;
      }
      return false;
    } catch (e) {
       debugPrint('Error creando actividad: $e');
       return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Listar actividades disponibles
  Future<void> listarActividades() async {
    // Solo cargando visual si está vacío
    if (_actividades.isEmpty) {
      _cargando = true;
      notifyListeners();
    }
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('listarActividades', {});
      
      if (res['ok'] == true) {
        final datos = res['datos'] as List<dynamic>;
        final nuevasActividades = datos.map((fila) => Actividad.desdeMapa({
          'id': fila['id'],
          'titulo': fila['titulo'].toString(),
          'costo': fila['costo'],
          'fecha_creacion': fila['fecha_creacion'],
          'fecha_limite': fila['fecha_limite'],
          'multa_por_dia': fila['multa_por_dia'],
          'requiere_asistencia': fila['requiere_asistencia'],
          'multa_inasistencia': fila['multa_inasistencia'],
        })).toList();

        // Comparar para evitar rebuilds innecesarios
        bool hayCambios = false;
        if (_actividades.length != nuevasActividades.length) {
          hayCambios = true;
        } else {
          for (int i = 0; i < _actividades.length; i++) {
            final a = _actividades[i];
            final b = nuevasActividades[i];
            if (a.id != b.id ||
                a.titulo != b.titulo ||
                a.costo != b.costo ||
                a.fechaLimite != b.fechaLimite ||
                a.multaPorDia != b.multaPorDia ||
                a.requiereAsistencia != b.requiereAsistencia ||
                a.multaInasistencia != b.multaInasistencia) {
              hayCambios = true;
              break;
            }
          }
        }

        if (hayCambios) {
          _actividades = nuevasActividades;
          unawaited(_guardarCacheLocal());
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error listando actividades: $e');
    } finally {
      if (_cargando) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  // Editar Actividad Existente (Solo Admin)
  Future<bool> editarActividad(int id, String nuevoTitulo, double nuevoCosto, Usuario usuario, {
    DateTime? fechaLimite,
    double multaPorDia = 0.0,
    bool requiereAsistencia = false,
    double multaInasistencia = 0.0,
  }) async {
    _cargando = true;
    notifyListeners();
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('editarActividad', {
        'id': id,
        'titulo': nuevoTitulo,
        'costo': nuevoCosto,
        'fechaLimite': fechaLimite?.toIso8601String().split('T')[0],
        'multaPorDia': multaPorDia,
        'requiereAsistencia': requiereAsistencia,
        'multaInasistencia': multaInasistencia,
        'adminRol': usuario.rol,
        'adminId': usuario.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      
      if (res['ok'] == true) {
        final index = _actividades.indexWhere((a) => a.id == id);
        if (index != -1) {
          final actVieja = _actividades[index];
          _actividades[index] = Actividad(
              id: id, 
              titulo: nuevoTitulo, 
              costo: nuevoCosto, 
              fechaCreada: actVieja.fechaCreada,
              fechaLimite: fechaLimite,
              multaPorDia: multaPorDia,
              requiereAsistencia: requiereAsistencia,
              multaInasistencia: multaInasistencia,
          );
        }
        unawaited(_guardarCacheLocal());
        return true;
      }
      return false;
    } catch (e) {
       debugPrint('Error editando actividad: $e');
       return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Eliminar Actividad Existente (Solo Admin)
  Future<String?> eliminarActividad(int id, Usuario usuario) async {
    _cargando = true;
    notifyListeners();
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('eliminarActividad', {
        'id': id,
        'adminRol': usuario.rol,
        'adminId': usuario.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      
      if (res['ok'] == true) {
        _actividades.removeWhere((a) => a.id == id);
        unawaited(_guardarCacheLocal());
        return null;
      } else {
        return res['msj'] ?? 'Error al eliminar.';
      }
    } catch (e) {
       debugPrint('Error eliminando actividad: $e');
       return 'Ocurrió un error al eliminar.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Obtener Asistencia
  Future<List<Map<String, dynamic>>> obtenerAsistencia(int actividadId) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerAsistencia', {'actividadId': actividadId});
      if (res['ok'] == true) {
        return List<Map<String, dynamic>>.from(res['datos']);
      }
    } catch (e) {
      debugPrint('Error obteniendo asistencia: $e');
    }
    return [];
  }

  // Guardar Asistencia
  Future<bool> guardarAsistenciaLote(int actividadId, List<Map<String, dynamic>> asistencias, Usuario usuario) async {
    _cargando = true;
    notifyListeners();
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('guardarAsistenciaLote', {
        'actividadId': actividadId,
        'asistencias': asistencias,
        'adminRol': usuario.rol,
        'adminId': usuario.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      return res['ok'] == true;
    } catch (e) {
      debugPrint('Error guardando asistencia: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
