import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_client.dart' as api_ext;
import 'package:intl/intl.dart';

class ServicioAuditoria {
  static final ServicioAuditoria _instancia = ServicioAuditoria._internal();
  factory ServicioAuditoria() => _instancia;
  ServicioAuditoria._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Registra una acción sensible en la base de datos de auditoría (MIGRADO A API)
  Future<void> registrarAccion({
    required String accion, 
    required String detalle,
    int? usuarioId, 
  }) async {
    try {
      String infoDispositivo = await _obtenerNombreDispositivo();
      int adminId = usuarioId ?? await _obtenerIdAdminActual();
      
      if (adminId == -1) return;

      final api = api_ext.ApiClient();
      await api.post('registrarAccion', {
        'adminId': adminId,
        'accionLog': accion,
        'detalle': detalle,
        'dispositivo': infoDispositivo
      });
      
      debugPrint('AUDITORÍA: Acción registrada ($accion) vía API');
    } catch (e) {
      debugPrint('ERROR AUDITORÍA API: $e');
    }
  }

  /// Obtiene un nombre legible del dispositivo (ej: "Samsung S21", "iPhone 13")
  Future<String> _obtenerNombreDispositivo() async {
    try {
      if (kIsWeb) {
        WebBrowserInfo webInfo = await _deviceInfo.webBrowserInfo;
        return '${webInfo.browserName.name} (${webInfo.platform})';
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.systemName}';
      } else if (Platform.isWindows) {
        WindowsDeviceInfo winInfo = await _deviceInfo.windowsInfo;
        return 'PC Windows (${winInfo.computerName})';
      }
      return 'Dispositivo Desconocido';
    } catch (e) {
      return 'Error Info Dispositivo';
    }
  }

  Future<int> _obtenerIdAdminActual() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return -1; // No logueado

      final api = api_ext.ApiClient();
      final res = await api.post('obtenerIdAdminActual', {'uid': uid});
      
      if (res['ok'] == true && res['id'] != null) {
        return res['id'] as int;
      }
      return -1;
    } catch (e) {
      debugPrint('Error obteniendo ID admin via API: $e');
      return -1;
    }
  }

  // --- SOLO PARA SUPER ADMIN (MIGRADO A API) ---
  Future<List<Map<String, dynamic>>> obtenerLogsAuditoria() async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerLogsAuditoria');
      
      if (res['ok'] == true && res['datos'] != null) {
        final results = res['datos'] as List<dynamic>;
        return results.map((fila) => {
          'id': fila['id'],
          'admin': fila['admin_nombre'].toString(),
          'rol': fila['rol'].toString(),
          'accion': fila['accion'].toString(),
          'detalle': fila['detalle'].toString(),
          'dispositivo': fila['dispositivo'].toString(),
          'fecha': (fila['fecha'] is String) ? DateTime.tryParse(fila['fecha']) ?? DateTime.now() : fila['fecha']
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo logs API: $e');
      return [];
    }
  }

  /// Obtiene el resumen de dinero recaudado (MIGRADO A API)
  Future<List<Map<String, dynamic>>> obtenerResumenCaja(DateTime fecha) async {
    try {
      final api = api_ext.ApiClient();
      final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
      final res = await api.post('obtenerResumenCaja', {'fecha': fechaStr});
      
      if (res['ok'] == true && res['datos'] != null) {
        final results = res['datos'] as List<dynamic>;
        Map<String, double> totales = {};

        for (var row in results) {
          String admin = row['admin_nombre'].toString();
          String detalle = row['detalle'].toString();
          
          try {
            if (detalle.contains('S/ ')) {
              final parteMonto = detalle.split('S/ ')[1].split(' ')[0];
              double monto = double.parse(parteMonto.replaceAll(',', ''));
              if (!totales.containsKey(admin)) totales[admin] = 0.0;
              totales[admin] = totales[admin]! + monto;
            }
          } catch (e) {
            debugPrint('Error parseando monto: $e');
          }
        }

        final lista = totales.entries.map((e) => {'admin': e.key, 'total': e.value}).toList();
        lista.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
        return lista;
      }
      return [];
    } catch (e) {
      debugPrint('Error resumen caja API: $e');
      return [];
    }
  }

  /// Vacía todo el historial de auditoría (SOLO SUPERADMIN)
  Future<bool> vaciarHistorial(String adminRol, int adminId) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('vaciarAuditoria', {
        'adminRol': adminRol,
        'adminId': adminId
      });
      return res['ok'] == true;
    } catch (e) {
      debugPrint('Error vaciando historial: $e');
      return false;
    }
  }

  /// Ejecuta la sincronización masiva y total de la base de datos MySQL con Google Sheets
  Future<Map<String, dynamic>> sincronizarTodoGoogleSheets() async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('sincronizarTodoGoogleSheets');
      return res;
    } catch (e) {
      debugPrint('Error en sincronizarTodoGoogleSheets: $e');
      return {'ok': false, 'msj': 'Error de conexión al ejecutar sincronización masiva.'};
    }
  }
}
