import 'package:flutter/foundation.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import '../myPagesServer/c_base_datos_local.dart';
import 'modelo_usuario.dart';

class Sincronizador {
  final BaseDatosRemota _dbRemota = BaseDatosRemota();
  final BaseDatosLocal _dbLocal = BaseDatosLocal.instance;

  // 1. DESCARGAR DE LA NUBE (MySQL -> SQLite)
  Future<void> descargarDatosNube() async {
    try {
      debugPrint('☁️ Iniciando descarga de datos...');
      
      final conn = await _dbRemota.obtenerConexion();
      
      // Consultar usuarios remotos
      final results = await conn.query(
        'SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado, updated_at FROM DSI_salon_usuarios'
      );

      for (var fila in results) {
        String estadoLocal = 'activo';
        final estadoRaw = fila['estado'];
        if (estadoRaw != null) {
          if (estadoRaw.toString() == '1' || estadoRaw == true || estadoRaw.toString().toLowerCase() == 'activo') {
            estadoLocal = 'activo';
          } else {
            estadoLocal = 'inactivo';
          }
        }

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
          estado: estadoLocal,
          updatedAt: fila['updated_at'] != null ? (fila['updated_at'] as DateTime) : null,
        );

        // Guardar en local (marcándolo como 'sincronizado')
        await _dbLocal.insertarUsuario(usuario, sincronizado: true);
      }
      debugPrint('✅ Datos descargados y guardados localmente (${results.length} usuarios).');

    } catch (e) {
      debugPrint('❌ Error descargando datos: $e');
    }
  }

  // 2. SUBIR CAMBIOS PENDIENTES (SQLite -> MySQL)
  Future<void> subirCambios() async {
    try {
      // SUBIDA DE USUARIOS PENDIENTES
      final pendientes = await _dbLocal.obtenerNoSincronizados();

      if (pendientes.isNotEmpty) {
        final conn = await _dbRemota.obtenerConexion();
        for (var user in pendientes) {
          debugPrint('Sincronizando usuario: ${user.nombre}...');
          var remoto = await conn.query('SELECT updated_at FROM DSI_salon_usuarios WHERE id = ?', [user.id]);
          bool sobrescribir = true;
          
          if (remoto.isNotEmpty && remoto.first['updated_at'] != null && user.updatedAt != null) {
            DateTime updatedRemoto = remoto.first['updated_at'] as DateTime;
            if (updatedRemoto.isAfter(user.updatedAt!)) {
              sobrescribir = false;
              debugPrint('⚠️ Conflicto: El servidor tiene datos más recientes para ${user.nombre}. Omitiendo subida.');
            }
          }

          if (sobrescribir) {
            await conn.query(
              'UPDATE DSI_salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
              [user.celular, user.direccion, user.edad, user.sexo, user.id]
            );
            debugPrint('✅ Usuario ${user.nombre} actualizado en la nube.');
          }

          await _dbLocal.marcarSincronizado(user.id);
        }
      }

      // SUBIDA DE PAGOS PENDIENTES (MODO OFFLINE)
      final pagosPendientes = await _dbLocal.obtenerPagosNoSincronizados();
      if (pagosPendientes.isNotEmpty) {
        final conn = await _dbRemota.obtenerConexion();
        for (var pago in pagosPendientes) {
          debugPrint('Sincronizando pago offline: S/ \${pago.montoPagado}...');
          try {
            await conn.query(
              'INSERT INTO dsi_pagos (usuario_id, actividad_id, monto_pagado, fecha_pago, metodo_pago, confirmado) VALUES (?, ?, ?, ?, ?, ?)',
              [pago.usuarioId, pago.actividadId, pago.montoPagado, pago.fechaPago.toIso8601String(), pago.metodoPago, pago.confirmado ? 1 : 0]
            );
            // Marcar como sincronizado a nivel local (remotoId dummy, se podria recuperar con LAST_INSERT_ID)
            await _dbLocal.marcarPagoSincronizado(pago.id, 0); 
            debugPrint('✅ Pago de S/ \${pago.montoPagado} subido a la nube.');
          } catch (e) {
            debugPrint('❌ Error al subir pago offline: $e');
          }
        }
      }

      debugPrint('✅ Todos los cambios pendientes fueron procesados.');

    } catch (e) {
      debugPrint('❌ Error subiendo cambios: $e');
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
