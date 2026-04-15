import 'package:flutter/foundation.dart';
import '../myPagesServer/c_base_datos_local.dart';
import 'modelo_usuario.dart';
import '../services/api_client.dart' as api_ext;

class Sincronizador {
  final BaseDatosLocal _dbLocal = BaseDatosLocal.instance;

  // 1. DESCARGAR DE LA NUBE (API -> SQLite)
  Future<void> descargarDatosNube() async {
    try {
      debugPrint('☁️ Iniciando descarga de datos...');
      
      final api = api_ext.ApiClient();
      final res = await api.post('listarUsuariosCompleto', {});
      
      if (res['ok'] == true && res['datos'] != null) {
        final results = res['datos'] as List<dynamic>;

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
            id: fila['id'] is int ? fila['id'] : int.tryParse(fila['id'].toString()) ?? 0,
            nombre: _convertir(fila['nombre']),
            celular: _convertir(fila['celular']),
            uid: _convertir(fila['uid']),
            email: _convertir(fila['email']),
            fotoUrl: _convertir(fila['foto_url']),
            rol: _convertir(fila['rol'] ?? 'Alumno'),
            direccion: _convertir(fila['direccion']),
            edad: fila['edad'] is int ? fila['edad'] : int.tryParse(fila['edad']?.toString() ?? '0') ?? 0,
            sexo: _convertir(fila['sexo']),
            estado: estadoLocal,
            updatedAt: fila['updated_at'] != null ? DateTime.tryParse(fila['updated_at'].toString()) : null,
          );

          // Guardar en local (marcándolo como 'sincronizado')
          await _dbLocal.insertarUsuario(usuario, sincronizado: true);
        }
        debugPrint('✅ Datos descargados y guardados localmente (\${results.length} usuarios).');
      }

    } catch (e) {
      debugPrint('❌ Error descargando datos: $e');
    }
  }

  // 2. SUBIR CAMBIOS PENDIENTES (SQLite -> API)
  Future<void> subirCambios() async {
    try {
      final pendientes = await _dbLocal.obtenerNoSincronizados();
      final pagosPendientes = await _dbLocal.obtenerPagosNoSincronizados();

      if (pendientes.isNotEmpty || pagosPendientes.isNotEmpty) {
        final api = api_ext.ApiClient();
        
        final listUsers = pendientes.map((u) => {
          'id': u.id,
          'celular': u.celular,
          'direccion': u.direccion,
          'edad': u.edad,
          'sexo': u.sexo,
          'updatedAt': u.updatedAt?.toIso8601String()
        }).toList();

        final listPagos = pagosPendientes.map((p) => {
          'usuarioId': p.usuarioId,
          'actividadId': p.actividadId,
          'montoPagado': p.montoPagado,
          'fechaPago': p.fechaPago.toIso8601String(),
          'metodoPago': p.metodoPago,
          'confirmado': p.confirmado
        }).toList();

        final res = await api.post('sincronizarLoteOffline', {
          'usuarios': listUsers,
          'pagos': listPagos
        });

        if (res['ok'] == true) {
          for (var user in pendientes) {
             await _dbLocal.marcarSincronizado(user.id);
          }
          for (var pago in pagosPendientes) {
             await _dbLocal.marcarPagoSincronizado(pago.id, 0); 
          }
          debugPrint('✅ Todos los cambios pendientes fueron subidos y marcados.');
        } else {
          debugPrint('❌ El API rechazó la subida por lotes.');
        }
      } else {
        debugPrint('✅ No hay cambios pendientes por subir.');
      }
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
