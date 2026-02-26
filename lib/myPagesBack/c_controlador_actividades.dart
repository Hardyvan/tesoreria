import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'modelo_actividad.dart';
import 'modelo_usuario.dart';
import '../myPagesServer/b_base_datos_remota.dart';

class ControladorActividades extends ChangeNotifier {
  List<Actividad> _actividades = [];
  bool _cargando = false;

  List<Actividad> get actividades => _actividades;
  bool get cargando => _cargando;

  // Crear una nueva actividad (Solo Admin)
  Future<bool> crearActividad(String titulo, double costo, Usuario usuario) async {
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
      // B. VerificaciÃ³n Firebase (ProducciÃ³n)
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
      
      // 2. Insertar en BD
      final result = await conn.query(
        'INSERT INTO DSI_salon_actividades (titulo, costo, fecha_creacion) VALUES (?, ?, NOW())',
        [titulo, costo]
      );
      
      // 3. Actualizar lista local
      _actividades.insert(0, Actividad(
        id: result.insertId!, 
        titulo: titulo, 
        costo: costo, 
        fechaCreada: DateTime.now() // Aproximado para UI inmediata
      ));
      
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
  Future<bool> editarActividad(int id, String nuevoTitulo, double nuevoCosto, Usuario usuario) async {
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
      
      // 2. Actualizar en BD
      await conn.query(
        'UPDATE DSI_salon_actividades SET titulo = ?, costo = ?, updated_at = NOW() WHERE id = ?',
        [nuevoTitulo, nuevoCosto, id]
      );
      
      // 3. Actualizar lista local (buscamos por ID y la sobreescribimos pero manteniendo su fecha_creacion)
      final index = _actividades.indexWhere((a) => a.id == id);
      if (index != -1) {
        final actVieja = _actividades[index];
        _actividades[index] = Actividad(
            id: id, 
            titulo: nuevoTitulo, 
            costo: nuevoCosto, 
            fechaCreada: actVieja.fechaCreada
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
