
import 'package:flutter/foundation.dart';
import 'modelo_usuario.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import '../myPagesServer/c_base_datos_local.dart';

/// Repositorio exclusivo para operaciones con la Base de Datos Remota, Local y Storage.
class RepositorioUsuarios {
  final BaseDatosRemota _dbRemota = BaseDatosRemota();
  
  // Lista de correos con privilegio ROOT (Auto-Promoción a SuperAdmin)
  final List<String> _correosRoot = [
    'gurenge.leveling@gmail.com',
    'hao_asakura@gmail.com' // Agregamos alias por si acaso
  ];

  //-------------------------------------------------------------------------
  // 0. VERIFICAR UNICIDAD DE CELULAR
  //-------------------------------------------------------------------------
  Future<bool> verificarCelularEnUso(String celular, {int? excluirId}) async {
    if (celular.isEmpty) return false;
    try {
      final conn = await _dbRemota.obtenerConexion();
      final results = await conn.query(
        'SELECT id FROM DSI_salon_usuarios WHERE celular = ? ${excluirId != null ? "AND id != $excluirId" : ""}',
        [celular]
      );
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando celular único: $e');
      return false; // Ante la duda, permitimos
    }
  }

  //-------------------------------------------------------------------------
  // 1. SINCRONIZAR O CREAR USUARIO (Desde Firebase Auth hacia MySQL)
  //-------------------------------------------------------------------------
  Future<Map<String, dynamic>> sincronizarUsuarioBD(String uid, String email, String nombre, String fotoGoogle) async {
    try {
      final conn = await _dbRemota.obtenerConexion();
      
      // A. Búsqueda por UID
      var results = await conn.query(
        'SELECT id, uid, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM DSI_salon_usuarios WHERE uid = ?', 
        [uid]
      );

      // B. Fallback a Búsqueda por Email (Usuarios antiguos de Legacy App)
      if (results.isEmpty && email.isNotEmpty) {
        results = await conn.query(
          'SELECT id, uid, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM DSI_salon_usuarios WHERE email = ?', 
          [email]
        );
        
        if (results.isNotEmpty) {
          final idLegacy = results.first['id'];
          await conn.query('UPDATE DSI_salon_usuarios SET uid = ? WHERE id = ?', [uid, idLegacy]);
          if (fotoGoogle.isNotEmpty) {
             await conn.query('UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ? AND (foto_url IS NULL OR foto_url = "")', [fotoGoogle, idLegacy]);
          }
        }
      }

      // C. PROCESAR RESULTADO
      if (results.isNotEmpty) {
        // EXISTE
        final fila = results.first;
        final estado = _convertirAString(fila['estado'] ?? 'activo');
        
        if (estado == 'inactivo') {
          return {'error': 'Tu cuenta ha sido bloqueada. Contacta al administrador.'};
        }

        String rolActual = _convertirAString(fila['rol'] ?? 'Alumno');
        
        // AUTO-PROMOCIÓN: Si el correo está en ROOT pero tiene otro rol, actualizar en cascada.
        final emailLimpio = email.trim().toLowerCase();
        debugPrint('--- [SECURITY] Verificando permisos ROOT para: $emailLimpio ---');
        
        if (_correosRoot.contains(emailLimpio) && rolActual != 'SuperAdmin') {
           debugPrint('--- [SECURITY] ¡MATCH! Promocionando a SuperAdmin ID: ${fila['id']} ---');
           rolActual = 'SuperAdmin';
           await conn.query('UPDATE DSI_salon_usuarios SET rol = "SuperAdmin" WHERE id = ?', [fila['id']]);
        } else if (_correosRoot.contains(emailLimpio)) {
           debugPrint('--- [SECURITY] Acceso SuperAdmin YA activo para $emailLimpio ---');
        }

        final usuarioLocal = Usuario(
          id: fila['id'],
          uid: uid,
          nombre: _convertirAString(fila['nombre']),
          celular: _convertirAString(fila['celular']),
          email: _convertirAString(fila['email']),
          fotoUrl: _convertirAString(fila['foto_url']),
          rol: rolActual, // Usamos el rol actualizado o el de la BD
          direccion: _convertirAString(fila['direccion']),
          edad: fila['edad'] ?? 0,
          sexo: _convertirAString(fila['sexo']),
          estado: estado,
        );

        if (usuarioLocal.celular.isEmpty) {
           return {'status': 'UsuarioIncompleto', 'usuario': usuarioLocal}; 
        }
        return {'status': 'OK', 'usuario': usuarioLocal};
      
      } else {
        // NO EXISTE (NUEVO) - AUTO-PROMOCIÓN
        String rolAsignado = _correosRoot.contains(email.toLowerCase()) ? 'SuperAdmin' : 'Alumno';

        final resultInsert = await conn.query(
          'INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
          [uid, nombre, email, '', '', 0, '', fotoGoogle, rolAsignado]
        );

        final usuarioNuevo = Usuario(
          id: resultInsert.insertId!, 
          uid: uid,
          nombre: nombre,
          celular: '',
          email: email,
          fotoUrl: fotoGoogle,
          rol: rolAsignado,
        );
        return {'status': 'UsuarioNuevo', 'usuario': usuarioNuevo}; 
      }
    } catch (e) {
      debugPrint('Error Repositorio SQL - Sincronizar: $e');
      return {'error': 'Error de Base de Datos: $e'};
    }
  }

  //-------------------------------------------------------------------------
  // 2. CREAR USUARIO FULL PERFIL (Registro por Correo Tradicional)
  //-------------------------------------------------------------------------
  Future<String?> insertarUsuarioEnBD({
    required String nombre, required String email, required String celular,
    required String direccion, required int edad, required String sexo
  }) async {
    try {
      final conn = await _dbRemota.obtenerConexion();
      String rolAsignado = _correosRoot.contains(email.toLowerCase()) ? 'SuperAdmin' : 'Alumno';

      await conn.query(
        'INSERT INTO DSI_salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
        [nombre, email, celular, direccion, edad, sexo, '', rolAsignado]
      );
      return null; // OK
    } catch (e) {
      debugPrint('Error Insert Auth BD: $e');
      return 'Fallo en guardado de datos. Intentando Rollback de Auth...';
    }
  }

  //-------------------------------------------------------------------------
  // 3. COMPLETAR PERFIL INCOMPLETO
  //-------------------------------------------------------------------------
  Future<Usuario?> guardarPerfilCompletado(Usuario usuarioBase, String nombre, String celular, String direccion, int edad, String sexo) async {
    try {
      final conn = await _dbRemota.obtenerConexion();
      int id = usuarioBase.id;

      if (id == 0) {
        String rolAsignado = _correosRoot.contains(usuarioBase.email.toLowerCase()) ? 'SuperAdmin' : 'Alumno';
        final resultInsert = await conn.query(
          'INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
          [usuarioBase.uid, nombre, usuarioBase.email, celular, direccion, edad, sexo, usuarioBase.fotoUrl, rolAsignado]
        );
        id = resultInsert.insertId!;
      } else {
        await conn.query(
          'UPDATE DSI_salon_usuarios SET nombre = ?, celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
          [nombre, celular, direccion, edad, sexo, id]
        );
      }

      return usuarioBase.copyWith(id: id, nombre: nombre, celular: celular, direccion: direccion, edad: edad, sexo: sexo);
    } catch (e) {
      debugPrint('Error guardando perfil completado: $e');
      return null;
    }
  }

  //-------------------------------------------------------------------------
  // 4. ACTUALIZAR CELULAR O FOTO (OFFLINE FIRST LÓGICA)
  //-------------------------------------------------------------------------
  Future<Usuario?> actualizarElementoUsuario(Usuario usuarioActual, {String? celular, String? fotoUrl}) async {
    try {
      final usuarioActualizado = usuarioActual.copyWith(
        celular: celular ?? usuarioActual.celular,
        fotoUrl: fotoUrl ?? usuarioActual.fotoUrl
      );
      
      // Guardar local (SQLite)
      await BaseDatosLocal.instance.insertarUsuario(usuarioActualizado, sincronizado: false);

      // Sincronizar (DSI Nube)
      try {
        final conn = await _dbRemota.obtenerConexion();
        
        if (celular != null) {
          await conn.query('UPDATE DSI_salon_usuarios SET celular = ? WHERE id = ?', [celular, usuarioActual.id]);
        } else if (fotoUrl != null) {
          await conn.query('UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ?', [fotoUrl, usuarioActual.id]);
        }
        
        await BaseDatosLocal.instance.marcarSincronizado(usuarioActual.id);
      } catch (e) {
        debugPrint('Guardado en SQLite, subida diferida por conexión fallida');
      }

      return usuarioActualizado;
    } catch (e) {
      return null;
    }
  }

  // Las imágenes se suben ahora directamente mediante ApiUploadService
  

  // Utilidad de parseo de Base de datos Blob -> String
  String _convertirAString(dynamic valor) {
    if (valor == null) return '';
    if (valor is String) return valor;
    return valor.toString();
  }
}
