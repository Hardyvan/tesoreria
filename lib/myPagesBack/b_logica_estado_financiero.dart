import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_client.dart' as api_ext;
import 'modelo_pago.dart';
import 'modelo_gasto.dart';
import 'modelo_usuario.dart';
import 'k_gerente_notificaciones.dart';
import 'k_servicio_auditoria.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../myPagesTema/c_formatos.dart';

class ControladorFinanzas extends ChangeNotifier {
  double _deudaTotal = 0.0;
  double _totalPagado = 0.0;
  
  // Resumen Financiero General (Caja)
  double _totalIngresos = 0.0;
  double _totalGastos = 0.0;
  double _saldoCaja = 0.0;
  
  // Fondo Base / Apertura de Caja
  double _fondoBase = 0.0;
  String _fondoBaseMotivo = '';
  
  List<Map<String, dynamic>> _kardex = [];
  bool _hayMasKardex = true;
  int _kardexPage = 0;
  static const int _kardexItemsPerPage = 20;

  List<Map<String, dynamic>> _listaDeudores = [];
  List<Map<String, dynamic>> _misPagos = [];
  List<Map<String, dynamic>> _metasActividades = [];
  
  // CACHE SISTEMA (MAPA Y FUTUROS)
  final Map<int, List<Map<String, dynamic>>> _cacheDetallePagos = {};
  Future<void>? _futureResumenEnCurso;
  Future<void>? _futureKardexEnCurso;

  /// Invalida todo el caché de finanzas (llamar cuando cambian actividades/pagos)
  void invalidarCache() {
    _cacheDetallePagos.clear();
    _futureResumenEnCurso = null;
    _futureKardexEnCurso = null;
    notifyListeners();
  }

  bool _cargando = false;
  
  double get deudaTotal => _deudaTotal;
  double get totalPagado => _totalPagado;
  
  double get totalIngresos => _totalIngresos;
  double get totalGastos => _totalGastos;
  double get saldoCaja => _saldoCaja;
  
  double get fondoBase => _fondoBase;
  String get fondoBaseMotivo => _fondoBaseMotivo;
  
  List<Map<String, dynamic>> get kardex => _kardex;
  bool get hayMasKardex => _hayMasKardex;
  
  List<Map<String, dynamic>> get listaDeudores => _listaDeudores;
  List<Map<String, dynamic>> get misPagos => _misPagos;
  List<Map<String, dynamic>> get metasActividades => _metasActividades;

  bool get cargando => _cargando;

  // 1. Obtener lista simple de actividades para el Dropdown
  Future<List<Map<String, dynamic>>> obtenerActividadesSimplificadas() async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('listarActividades', {});
      
      if (res['ok'] == true) {
        final datos = res['datos'] as List<dynamic>;
        return datos.map((fila) => {
          'id': fila['id'],
          'titulo': fila['titulo'].toString()
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo actividades simples: ');
      return [];
    }
  }

  // Cargar resumen financiero del usuario - MIGRADO A API CON CACHÉ
  Future<void> cargarFinanzasUsuario(int usuarioId) async {
    // Solo mostramos carga si no hay datos previos
    if (_misPagos.isEmpty) {
      _cargando = true;
      notifyListeners();
    }

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerDatosFinanzasUsuario', {'usuarioId': usuarioId});
      
      if (res['ok'] == true) {
        _deudaTotal = (res['deudaTotal'] as num).toDouble();
        _totalPagado = (res['totalPagado'] as num).toDouble();
        
        final listado = res['misPagos'] as List<dynamic>;
        _misPagos = listado.map((fila) => {
          'id': fila['id'],
          'actividad': fila['actividad'].toString(),
          'monto': (fila['monto'] as num).toDouble(),
          'fecha': (fila['fecha_pago'] is String) ? DateTime.tryParse(fila['fecha_pago']) ?? DateTime.now() : fila['fecha_pago'],
        }).toList();

        // --- RECORDATORIO DIARIO ---
        if (_deudaTotal > 0) {
          unawaited(GerenteNotificaciones().programarRecordatorioDeuda(_deudaTotal));
        } else {
          unawaited(GerenteNotificaciones().cancelarRecordatorios());
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo finanzas usuario: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> obtenerDetallePagosPorActividad(int usuarioId, {bool forceRefresh = false}) async {
    // 1. Verificar CACHÉ (MAPA) para respuesta instantánea
    if (!forceRefresh && _cacheDetallePagos.containsKey(usuarioId)) {
      debugPrint('CACHE: Cargando historial desde memoria (instantáneo)');
      // Lanzamos actualización silenciosa en segundo plano
      unawaited(_obtenerDetallePagosPorActividadInterno(usuarioId));
      return _cacheDetallePagos[usuarioId]!;
    }

    return _obtenerDetallePagosPorActividadInterno(usuarioId);
  }

  Future<List<Map<String, dynamic>>> _obtenerDetallePagosPorActividadInterno(int usuarioId) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerDetallePagosPorActividad', {'usuarioId': usuarioId});
      
      if (res['ok'] == true && res['datos'] != null) {
        final results = res['datos'] as List<dynamic>;
        Map<int, Map<String, dynamic>> agrupado = {};

        for (var row in results) {
          int idActividad = row['actividad_id'];
          if (!agrupado.containsKey(idActividad)) {
            agrupado[idActividad] = {
              'titulo': row['titulo'].toString(),
              'costo': (row['costo'] as num? ?? 0.0).toDouble(),
              'pagos': <Map<String, dynamic>>[],
              'total_pagado': 0.0,
              'estado': 'Pendiente'
            };
          }

          if (row['pago_id'] != null) {
            double monto = (row['monto'] as num? ?? 0.0).toDouble();
            double multa = (row['monto_multa'] as num? ?? 0.0).toDouble();
            agrupado[idActividad]!['pagos'].add({
               'id': row['pago_id'],
               'fecha': row['fecha_pago'],
               'monto': monto,
               'multa': multa
            });
            agrupado[idActividad]!['total_pagado'] += monto;
          }
        }

        agrupado.forEach((key, value) {
          double costo = value['costo'];
          double pagado = value['total_pagado'];
          if (pagado >= costo) {
            value['estado'] = 'Completo';
          } else if (pagado > 0) {
            value['estado'] = 'Parcial';
          } else {
            value['estado'] = 'Pendiente';
          }
        });

        final listaFinal = agrupado.values.toList();
        _cacheDetallePagos[usuarioId] = listaFinal;
        notifyListeners();
        return listaFinal;
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo detalle pagos: $e');
      return _cacheDetallePagos[usuarioId] ?? [];
    }
  }

  // Registrar un nuevo pago (Solo Admin)
  Future<bool> registrarPago(Pago pago, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarPago', {
        'adminRol': adminEjecutor.rol,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'adminId': adminEjecutor.id,
        'adminNombre': adminEjecutor.nombre,
        'pago': {
           'actividadId': pago.actividadId,
           'usuarioId': pago.usuarioId,
           'monto': pago.montoPagado,
           'metodoPago': pago.metodoPago,
           'comprobanteUrl': null
        }
      });
      
      if (res['ok'] == true) {
        try {
          unawaited(GerenteNotificaciones.enviarPush(
              tokenDestino: '/topics/tesoreria', 
              titulo: '✅ Nuevo Pago Recibido', 
              cuerpo: 'Se ha registrado un pago de ${pago.montoPagado.toSoles()} del alumno.'
          ));
        } catch (_) {}
        
        // Auto-refresh: recargar todos los datos afectados
        invalidarCache();
        unawaited(cargarFinanzasUsuario(pago.usuarioId));
        unawaited(obtenerResumenFinanciero());
        unawaited(obtenerMovimientosKardex(reset: true));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registrando pago: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Edición rápida de monto (Solo Admin)
  Future<bool> editarPago(int pagoId, double nuevoMonto, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('editarPago', {
        'pagoId': pagoId,
        'nuevoMonto': nuevoMonto,
        'adminRol': adminEjecutor.rol,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'adminId': adminEjecutor.id,
      });

      if (res['ok'] == true) {
        // Auto-refresh: recargar todos los datos afectados
        invalidarCache();
        unawaited(obtenerResumenFinanciero());
        unawaited(obtenerMovimientosKardex(reset: true));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error editando pago: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Eliminar Pago (Solo Admin)
  // [CONTENIDO OMITIDO POR BREVEDAD - SIGUE IGUAL PERO CON LIMPIEZA DE CACHE]
  Future<bool> eliminarPago(int pagoId, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('eliminarPago', {
        'pagoId': pagoId,
        'adminRol': adminEjecutor.rol,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'adminId': adminEjecutor.id,
      });

      if (res['ok'] == true) {
         try {
            double monto = (res['monto'] as num).toDouble();
            await GerenteNotificaciones.enviarPush(
              tokenDestino: '/topics/tesoreria',
              titulo: '❌ Pago Anulado', 
              cuerpo: 'Un administrador ha anulado un registro de pago tuyo por ${monto.toSoles()}.'
            );
         } catch (_) {}
         
         // Auto-refresh: recargar todos los datos afectados
         invalidarCache();
         unawaited(obtenerResumenFinanciero());
         unawaited(obtenerMovimientosKardex(reset: true));
         return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error eliminando pago: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // EDICIÓN / ELIMINACIÓN UNIVERSAL (KARDEX)
  // ---------------------------------------------------------------------------

  Future<bool> editarMovimiento(String tipo, int movId, double nuevoMonto, Usuario adminEjecutor) async {
    if (tipo == 'I') {
      return editarPago(movId, nuevoMonto, adminEjecutor);
    }
    
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final endpoint = tipo == 'E' ? 'editarGasto' : 'editarIngresoExtra';
      final paramId = tipo == 'E' ? 'gastoId' : 'ingresoId';

      final res = await api.post(endpoint, {
        paramId: movId,
        'nuevoMonto': nuevoMonto,
        'adminRol': adminEjecutor.rol,
        'adminId': adminEjecutor.id,
      });

      if (res['ok'] == true) {
        invalidarCache();
        unawaited(obtenerResumenFinanciero());
        unawaited(obtenerMovimientosKardex(reset: true));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error editando movimiento extra: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> eliminarMovimiento(String tipo, int movId, Usuario adminEjecutor) async {
    if (tipo == 'I') {
      return eliminarPago(movId, adminEjecutor);
    }

    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final endpoint = tipo == 'E' ? 'eliminarGasto' : 'eliminarIngresoExtra';
      final paramId = tipo == 'E' ? 'gastoId' : 'ingresoId';

      final res = await api.post(endpoint, {
        paramId: movId,
        'adminRol': adminEjecutor.rol,
        'adminId': adminEjecutor.id,
      });

      if (res['ok'] == true) {
        invalidarCache();
        unawaited(obtenerResumenFinanciero());
        unawaited(obtenerMovimientosKardex(reset: true));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error eliminando movimiento extra: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // FASE 3: CAJA GENERAL Y GASTOS (MIGRADO A API CON BACKGROUND SYNC)
  // ---------------------------------------------------------------------------

  // 2. Registrar Gasto
  Future<bool> registrarGasto(Gasto gasto, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarGasto', {
        'adminRol': adminEjecutor.rol,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'adminId': adminEjecutor.id,
        'gasto': {
          'descripcion': gasto.descripcion,
          'monto': gasto.monto,
          'actividadId': gasto.actividadId,
          'comprobanteUrl': null
        }
      });
      
      if (res['ok'] == true) {
        // --- NOTIFICACIÓN GLOBAL ---
        try {
          unawaited(GerenteNotificaciones.enviarPush(
            tokenDestino: '/topics/tesoreria',
            titulo: '⚠️ Gasto / Salida de Caja', 
            cuerpo: 'Se ha registrado un gasto de ${gasto.monto.toSoles()} por: ${gasto.descripcion}',
          ));
        } catch (_) {}
        
        await obtenerResumenFinanciero();
        await obtenerMovimientosKardex(reset: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registrando gasto: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // --- REGISTRAR INGRESO EXTRA / DONACION ---
  Future<bool> registrarIngresoExtra(double monto, String descripcion, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarIngresoExtra', { // Asumiendo que existe o se mapea a registrarPago/Gasto
        'monto': monto,
        'descripcion': descripcion,
        'adminId': adminEjecutor.id,
        'accion': 'registrarIngresoExtra'
      });
      
      if (res['ok'] == true) {
        try {
          unawaited(GerenteNotificaciones.enviarPush(
            tokenDestino: '/topics/tesoreria',
            titulo: '🎉 Nuevo Ingreso a Caja', 
            cuerpo: '¡Hemos recibido un abono/donación de ${monto.toSoles()}! ($descripcion)',
          ));
        } catch (_) {}

        await obtenerResumenFinanciero();
        await obtenerMovimientosKardex(reset: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registrando ingreso extra: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 3. Obtener Reporte Avanzado (Por rango de fechas)
  Future<Map<String, dynamic>> obtenerReporteAvanzado(DateTime inicio, DateTime fin) async {
    _cargando = true;
    notifyListeners();
    
    final inicioStr = DateFormat('yyyy-MM-dd').format(inicio);
    final finStr = DateFormat('yyyy-MM-dd').format(fin);

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerReporteAvanzado', {
        'inicio': inicioStr,
        'fin': finStr
      });
      return res;
    } catch (e) {
      debugPrint('Error generando reporte avanzado: $e');
      return {'error': e.toString(), 'desglose': []};
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 2. Obtener Resumen Financiero (SUM Directo en API)
  Future<void> obtenerResumenFinanciero() {
    if (_futureResumenEnCurso != null) {
      return _futureResumenEnCurso!;
    }
    _futureResumenEnCurso = _obtenerResumenFinancieroInterno().whenComplete(() {
      _futureResumenEnCurso = null;
    });
    return _futureResumenEnCurso!;
  }

  Future<void> _obtenerResumenFinancieroInterno() async {
    // Solo cargando visible si no hay saldo previo
    if (_saldoCaja == 0) {
      _cargando = true;
      notifyListeners();
    }
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerResumenGeneral', {});

      if (res['ok'] == true) {
        _totalIngresos = (res['totalIngresos'] as num).toDouble();
        _totalGastos = (res['totalGastos'] as num).toDouble();
        _fondoBase = (res['fondoBase'] as num).toDouble();
        _fondoBaseMotivo = res['fondoBaseMotivo'].toString();
        _saldoCaja = (res['saldoCaja'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error obteniendo resumen: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // --- MÉTODOS PARA APERTURA DE CAJA ---
  Future<bool> establecerFondoBase(double monto, String motivo, Usuario admin) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('establecerFondoBase', {
        'monto': monto,
        'motivo': motivo,
        'adminRol': admin.rol,
        'adminId': admin.id
      });
      
      if (res['ok'] == true) {
        unawaited(ServicioAuditoria().registrarAccion(
          accion: 'Aperturar Caja',
          detalle: 'Monto: ${monto.toSoles()} - Motivo: $motivo',
        ));
        await obtenerResumenFinanciero();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en establecerFondoBase: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 3. Obtener Kardex (UNION de Pagos y Gastos) Paginado
  Future<void> obtenerMovimientosKardex({bool reset = false}) {
    if (_futureKardexEnCurso != null && !reset) {
       return _futureKardexEnCurso!;
    }
    _futureKardexEnCurso = _obtenerMovimientosKardexInterno(reset: reset).whenComplete(() {
       _futureKardexEnCurso = null;
    });
    return _futureKardexEnCurso!;
  }

  Future<void> _obtenerMovimientosKardexInterno({required bool reset}) async {
    if (reset) {
      _kardexPage = 0;
      _kardex = [];
      _hayMasKardex = true;
    }

    if (!_hayMasKardex) return;
    
    // Solo carga visual si es la primera página
    if (_kardex.isEmpty) {
      _cargando = true;
      notifyListeners();
    }
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerHistorialKardex', {
        'limit': _kardexItemsPerPage,
        'offset': _kardexPage * _kardexItemsPerPage
      });

      if (res['ok'] == true) {
        final nuevos = (res['datos'] as List<dynamic>).map((fila) => {
          'tipo': fila['tipo'],
          'id_movimiento': fila['id_movimiento'],
          'descripcion': fila['descripcion'],
          'monto': (fila['monto'] as num).toDouble(),
          'fecha': DateTime.tryParse(fila['fecha']) ?? DateTime.now(),
        }).toList();

        if (nuevos.isEmpty || nuevos.length < _kardexItemsPerPage) {
          _hayMasKardex = false;
        }

        _kardex.addAll(nuevos);
        _kardexPage++;
      }
    } catch (e) {
      debugPrint('Error obteniendo kardex: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 4. Reporte de Deudores
  Future<void> obtenerReporteDeudores() async {
    if (_listaDeudores.isEmpty) {
      _cargando = true;
      notifyListeners();
    }
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerReporteDeudores', {});
      
      if (res['ok'] == true) {
        final results = res['datos'] as List<dynamic>;
        _listaDeudores = results.map((fila) => {
          'id': fila['id'],
          'nombre': fila['nombre'].toString(),
          'foto_url': fila['foto_url'].toString(),
          'deuda': (fila['deuda'] as num).toDouble(),
          'estado': fila['estado'].toString()
        }).toList();
      }
    } catch (e) {
      debugPrint('Error obteniendo deudores: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // --- NUEVA FUNCIÓN: Alumno Offline ---
  Future<bool> registrarAlumnoOffline(String nombre) async {
    _cargando = true;
    notifyListeners();
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarAlumnoOffline', {'nombre': nombre});
      
      if (res['ok'] == true) {
        unawaited(ServicioAuditoria().registrarAccion(
          accion: 'Alumno Offline Creado',
          detalle: 'Nombre: $nombre',
        ));
        await obtenerReporteDeudores();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error registrando alumno offline: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 5. Obtener Metas por Actividad
  Future<void> obtenerMetasActividades() async {
    if (_metasActividades.isEmpty) {
      _cargando = true;
      notifyListeners();
    }
    
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerMetasActividades', {});
      
      if (res['ok'] == true) {
        final results = res['datos'] as List<dynamic>;
        _metasActividades = results.map((fila) => {
          'id': fila['id'],
          'titulo': fila['titulo'].toString(),
          'meta_total': (fila['meta_total'] as num).toDouble(),
          'recaudado': (fila['recaudado'] as num).toDouble(),
          'gastado': (fila['gastado'] as num).toDouble(),
          'saldo_disponible': (fila['saldo_disponible'] as num).toDouble(),
          'porcentaje_recaudacion': (fila['porcentaje_recaudacion'] as num).toDouble(),
        }).toList();
      }
    } catch (e) {
      debugPrint('Error obteniendo metas: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}

