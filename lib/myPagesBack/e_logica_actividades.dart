import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'modelo_actividad.dart';
import 'modelo_usuario.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import 'j_servicio_notificaciones_secundario.dart' as push;

class ControladorActividades extends ChangeNotifier {
  List<Actividad> _actividades = [];
  bool _cargando = false;

  List<Actividad> get actividades => _actividades;
  bool get cargando => _cargando;

  // Crear una nueva actividad (Solo Admin)
  Future<bool> crearActividad(String titulo, double costo, Usuario usuario, {
    DateTime? fechaLimite,
    double multaPorDia = 0.0,
  }) async {
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. SEGURIDAD: Verificar Admin
      bool esAdminSeguro = false;

      // A. Backdoor para Admin Legacy (ID 1)
      if (usuario.id == 1 && usuario.rol == 'Admin') {
        esAdminSeguro = true;
      } 
      // B. Verificacion Firebase (Produccion)
      else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty && resultRol.first['rol'] == 'Admin') {
             esAdminSeguro = true;
           }
        }
      }

      if (!esAdminSeguro) {
        debugPrint('SEGURIDAD: Intento de crear actividad no autorizado');
        return false;
      }
      
      // 2. Insertar en BD con soporte de fecha_limite y multa_por_dia
      final String fechaStr = fechaLimite != null
          ? '${fechaLimite.year}-${fechaLimite.month.toString().padLeft(2, '0')}-${fechaLimite.day.toString().padLeft(2, '0')}'
          : '';

      final result = await conn.query(
        'INSERT INTO DSI_salon_actividades (titulo, costo, fecha_creacion, fecha_limite, multa_por_dia) VALUES (?, ?, NOW(), ?, ?)',
        [titulo, costo, fechaStr.isNotEmpty ? fechaStr : null, multaPorDia]
      );
      
      // 3. Actualizar lista local
      _actividades.insert(0, Actividad(
        id: result.insertId!, 
        titulo: titulo, 
        costo: costo, 
        fechaCreada: DateTime.now(),
        fechaLimite: fechaLimite,
        multaPorDia: multaPorDia,
      ));

      // 4. Enviar notificación push masiva a todos los usuarios con FCM Token
      try {
        final resultTokens = await conn.query('SELECT fcm_token FROM DSI_salon_usuarios WHERE fcm_token IS NOT NULL AND fcm_token != "" AND id != ?', [usuario.id]);
        
        for (var row in resultTokens) {
          String tokenDestino = row['fcm_token'].toString();
          await push.ServicioNotificacionesSecundario.enviarPush(
            tokenDestino: tokenDestino,
            titulo: '📢 Nueva Actividad', 
            cuerpo: 'Se ha registrado la actividad "$titulo". ¡Revisa la app!',
          ).catchError((_) => false); // Silencioso individualmente
        }
        debugPrint('Notificaciones enviadas a ${resultTokens.length} usuarios.');
      } catch (e) {
        debugPrint('Aviso: Falló envío de notificaciones: $e');
      }
      
      return true;
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
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      final results = await conn.query('SELECT * FROM DSI_salon_actividades ORDER BY fecha_creacion DESC');
      
      _actividades = results.map((fila) => Actividad.desdeMapa({
        'id': fila['id'],
        'titulo': fila['titulo'].toString(),
        'costo': fila['costo'],
        'fecha_creada': fila['fecha_creacion']
      })).toList();
      
    } catch (e) {
      debugPrint('Error listando actividades: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Editar Actividad Existente (Solo Admin)
  Future<bool> editarActividad(int id, String nuevoTitulo, double nuevoCosto, Usuario usuario, {
    DateTime? fechaLimite,
    double multaPorDia = 0.0,
  }) async {
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. SEGURIDAD: Verificar Admin
      bool esAdminSeguro = false;
      if (usuario.id == 1 && usuario.rol == 'Admin') {
        esAdminSeguro = true;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty && resultRol.first['rol'] == 'Admin') {
             esAdminSeguro = true;
           }
        }
      }

      if (!esAdminSeguro) {
        debugPrint('SEGURIDAD: Intento de editar actividad no autorizado');
        return false;
      }
      
      // 2. Actualizar en BD incluyendo campos de multa
      final String? fechaStr = fechaLimite != null
          ? '${fechaLimite.year}-${fechaLimite.month.toString().padLeft(2, '0')}-${fechaLimite.day.toString().padLeft(2, '0')}'
          : null;

      await conn.query(
        'UPDATE DSI_salon_actividades SET titulo = ?, costo = ?, fecha_limite = ?, multa_por_dia = ?, updated_at = NOW() WHERE id = ?',
        [nuevoTitulo, nuevoCosto, fechaStr, multaPorDia, id]
      );
      
      // 3. Actualizar lista local
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
        );
      }
      
      return true;
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
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. SEGURIDAD: Verificar Admin
      bool esAdminSeguro = false;
      if (usuario.id == 1 && usuario.rol == 'Admin') {
        esAdminSeguro = true;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty && resultRol.first['rol'] == 'Admin') {
             esAdminSeguro = true;
           }
        }
      }

      if (!esAdminSeguro) {
        return 'Sin permisos de administrador.';
      }

      // 2. SEGURIDAD: Prevenir borrado en cascada descontrolado. Ver si hay pagos anclados.
      final resultPagos = await conn.query('SELECT COUNT(*) as total FROM DSI_salon_pagos WHERE actividad_id = ?', [id]);
      if (resultPagos.isNotEmpty && resultPagos.first['total'] > 0) {
        return 'No se puede eliminar porque hay pagos registrados para esta actividad.';
      }
      
      // 3. Eliminar de BD
      await conn.query('DELETE FROM DSI_salon_actividades WHERE id = ?', [id]);
      
      // 4. Actualizar lista local
      _actividades.removeWhere((a) => a.id == id);
      
      return null; // Null indica éxito
    } catch (e) {
       debugPrint('Error eliminando actividad: $e');
       return 'Ocurrió un error al eliminar.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
