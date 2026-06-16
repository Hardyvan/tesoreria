import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart' as api_ext;
import 'modelo_pago.dart';
import 'modelo_gasto.dart';
import 'modelo_usuario.dart';
import 'k_gerente_notificaciones.dart';
import 'k_servicio_auditoria.dart';
import 'dart:async';
import 'dart:convert';
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
  static const int _kardexItemsPerPage = 100;

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

  ControladorFinanzas() {
    unawaited(cargarCache());
  }

  Future<void> cargarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Cargar Resumen Financiero
      final cacheResumen = prefs.getString('cache_resumen_financiero');
      if (cacheResumen != null) {
        final Map<String, dynamic> data = jsonDecode(cacheResumen);
        _totalIngresos = (data['totalIngresos'] as num? ?? 0.0).toDouble();
        _totalGastos = (data['totalGastos'] as num? ?? 0.0).toDouble();
        _fondoBase = (data['fondoBase'] as num? ?? 0.0).toDouble();
        _fondoBaseMotivo = data['fondoBaseMotivo']?.toString() ?? '';
        _saldoCaja = (data['saldoCaja'] as num? ?? 0.0).toDouble();
      }

      // 2. Cargar Kardex
      final cacheKardex = prefs.getString('cache_kardex');
      if (cacheKardex != null) {
        final List<dynamic> datos = jsonDecode(cacheKardex);
        _kardex = datos.map((fila) => {
          'tipo': fila['tipo'],
          'id_movimiento': fila['id_movimiento'],
          'descripcion': fila['descripcion'],
          'monto': (fila['monto'] as num? ?? 0.0).toDouble(),
          'fecha': DateTime.tryParse(fila['fecha'].toString()) ?? DateTime.now(),
          'actividad_id': fila['actividad_id'],
        }).toList();
      }

      // 3. Cargar Deudores
      final cacheDeudores = prefs.getString('cache_deudores');
      if (cacheDeudores != null) {
        final List<dynamic> results = jsonDecode(cacheDeudores);
        _listaDeudores = results.map((fila) => {
          'id': fila['id'],
          'nombre': fila['nombre'].toString(),
          'foto_url': fila['foto_url'].toString(),
          'celular': fila['celular']?.toString() ?? '',
          'deuda': (fila['deuda'] as num? ?? 0.0).toDouble(),
          'estado': fila['estado'].toString()
        }).toList();
      }

      // 4. Cargar metas de actividades
      final cacheMetas = prefs.getString('cache_metas_actividades');
      if (cacheMetas != null) {
        final List<dynamic> datos = jsonDecode(cacheMetas);
        _metasActividades = datos.map((fila) => {
          'id': fila['id'],
          'titulo': fila['titulo'].toString(),
          'costo': (fila['costo'] as num? ?? 0.0).toDouble(),
          'meta_total': (fila['meta_total'] as num? ?? 0.0).toDouble(),
          'recaudado': (fila['recaudado'] as num? ?? 0.0).toDouble(),
          'gastado': (fila['gastado'] as num? ?? 0.0).toDouble(),
          'saldo_disponible': (fila['saldo_disponible'] as num? ?? 0.0).toDouble(),
          'porcentaje_recaudacion': (fila['porcentaje_recaudacion'] as num? ?? 0.0).toDouble(),
        }).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando cache local: $e');
    }
  }
  
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
    // 1. Cargar caché inmediatamente si existe y está vacío
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('cache_finanzas_usuario_$usuarioId');
      if (cacheData != null && _misPagos.isEmpty) {
        final Map<String, dynamic> data = jsonDecode(cacheData);
        _deudaTotal = (data['deudaTotal'] as num? ?? 0.0).toDouble();
        _totalPagado = (data['totalPagado'] as num? ?? 0.0).toDouble();
        final listado = data['misPagos'] as List<dynamic>;
        _misPagos = listado.map((fila) => {
          'id': fila['id'],
          'actividad': fila['actividad']?.toString() ?? '',
          'monto': (fila['monto'] as num).toDouble(),
          'fecha': DateTime.tryParse(fila['fecha_pago']?.toString() ?? '') ?? DateTime.now(),
        }).toList();
        notifyListeners();
      }
    } catch (_) {}

    // Solo mostramos carga si no hay datos previos
    if (_misPagos.isEmpty) {
      _cargando = true;
      notifyListeners();
    }

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerDatosFinanzasUsuario', {'usuarioId': usuarioId});
      
      if (res['ok'] == true) {
        final nuevaDeuda = (res['deudaTotal'] as num).toDouble();
        final nuevoPagado = (res['totalPagado'] as num).toDouble();
        
        final listado = res['misPagos'] as List<dynamic>;
        final nuevosPagos = listado.map((fila) => {
          'id': fila['id'],
          'actividad': fila['actividad'].toString(),
          'monto': (fila['monto'] as num).toDouble(),
          'fecha': (fila['fecha_pago'] is String) ? DateTime.tryParse(fila['fecha_pago']) ?? DateTime.now() : fila['fecha_pago'],
        }).toList();

        // Comparación inteligente para evitar rebuilds si los datos son idénticos
        bool hayCambios = false;
        if (nuevaDeuda != _deudaTotal || nuevoPagado != _totalPagado || _misPagos.length != nuevosPagos.length) {
          hayCambios = true;
        } else {
          try {
            final strPrevio = jsonEncode(_misPagos.map((p) => {
              ...p,
              'fecha': p['fecha'] is DateTime ? (p['fecha'] as DateTime).toIso8601String() : p['fecha'].toString()
            }).toList());
            final strNuevo = jsonEncode(nuevosPagos.map((p) => {
              ...p,
              'fecha': p['fecha'] is DateTime ? (p['fecha'] as DateTime).toIso8601String() : p['fecha'].toString()
            }).toList());
            if (strPrevio != strNuevo) {
              hayCambios = true;
            }
          } catch (_) {
            hayCambios = true;
          }
        }

        if (hayCambios) {
          _deudaTotal = nuevaDeuda;
          _totalPagado = nuevoPagado;
          _misPagos = nuevosPagos;
          notifyListeners();
          
          // Guardar en cache local por usuario ID
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cache_finanzas_usuario_$usuarioId', jsonEncode({
              'deudaTotal': nuevaDeuda,
              'totalPagado': nuevoPagado,
              'misPagos': listado.map((fila) => {
                'id': fila['id'],
                'actividad': fila['actividad']?.toString() ?? '',
                'monto': fila['monto'],
                'fecha_pago': fila['fecha_pago']?.toString() ?? '',
              }).toList()
            }));
          } catch (_) {}
        }

        // --- RECORDATORIO DIARIO ---
        if (nuevaDeuda > 0) {
          unawaited(GerenteNotificaciones().programarRecordatorioDeuda(nuevaDeuda));
        } else {
          unawaited(GerenteNotificaciones().cancelarRecordatorios());
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo finanzas usuario: $e');
    } finally {
      if (_cargando) {
        _cargando = false;
        notifyListeners();
      }
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
              'actividad_id': idActividad,
              'titulo': row['titulo'].toString(),
              'costo': (row['costo'] as num? ?? 0.0).toDouble(),
              'pagos': <Map<String, dynamic>>[],
              'total_pagado': 0.0,
              'estado': 'Pendiente',
              'exonerado': (row['exonerado'] as num? ?? 0) == 1,
            };
          }

          if (row['pago_id'] != null) {
            double monto = (row['monto'] as num? ?? 0.0).toDouble();
            double multa = (row['monto_multa'] as num? ?? 0.0).toDouble();
            agrupado[idActividad]!['pagos'].add({
               'id': row['pago_id'],
               'fecha': row['fecha_pago'],
               'monto': monto,
               'multa': multa,
               'metodo_pago': row['metodo_pago'] ?? 'Efectivo',
               'comprobante_url': row['comprobante_url']?.toString(),
            });
            agrupado[idActividad]!['total_pagado'] += monto;
          }
        }

        agrupado.forEach((key, value) {
          bool exonerado = value['exonerado'] ?? false;
          if (exonerado) {
            value['estado'] = 'Exonerado';
          } else {
            double costo = value['costo'];
            double pagado = value['total_pagado'];
            if (pagado >= costo) {
              value['estado'] = 'Completo';
            } else if (pagado > 0) {
              value['estado'] = 'Parcial';
            } else {
              value['estado'] = 'Pendiente';
            }
          }
        });

        final listaFinal = agrupado.values.toList();
        
        // Comparación inteligente antes de actualizar caché y notificar rebuilds
        final tieneCache = _cacheDetallePagos.containsKey(usuarioId);
        bool cambioDetectado = true;
        if (tieneCache) {
          final cachePrevio = _cacheDetallePagos[usuarioId]!;
          if (cachePrevio.length == listaFinal.length) {
            try {
              final jsonPrevio = jsonEncode(cachePrevio);
              final jsonNuevo = jsonEncode(listaFinal);
              if (jsonPrevio == jsonNuevo) {
                cambioDetectado = false;
              }
            } catch (_) {}
          }
        }

        if (cambioDetectado) {
          _cacheDetallePagos[usuarioId] = listaFinal;
          notifyListeners();
        }
        return listaFinal;
      }
      return [];
    } catch (e) {
      debugPrint('Error obteniendo detalle pagos: $e');
      return _cacheDetallePagos[usuarioId] ?? [];
    }
  }

  // Registrar un nuevo pago (Solo Admin)
  Future<bool> registrarPago(Pago pago, Usuario adminEjecutor, {String? nombreAlumno}) async {
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
           'comprobanteUrl': pago.comprobanteUrl
        }
      });
      
      if (res['ok'] == true) {
        unawaited(HapticFeedback.lightImpact());
        try {
          final tokenUsuario = res['fcmTokenUsuario'];
          final etiquetaAlumno = nombreAlumno ?? 'un alumno';
          
          if (tokenUsuario != null && tokenUsuario.toString().isNotEmpty) {
            unawaited(GerenteNotificaciones.enviarPush(
                tokenDestino: tokenUsuario.toString(), 
                titulo: '✅ Pago Registrado', 
                cuerpo: 'Hola ${etiquetaAlumno.toFirstName()}, se ha registrado tu abono de ${pago.montoPagado.toSoles()}.'
            ));
          } else {
            unawaited(GerenteNotificaciones.enviarPush(
                tokenDestino: '/topics/tesoreria', 
                titulo: '✅ Nuevo Pago Recibido', 
                cuerpo: 'Se ha registrado un pago de ${pago.montoPagado.toSoles()} de: ${etiquetaAlumno.toFirstName()}.'
            ));
          }
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

  Future<bool> editarMovimiento(
    String tipo, 
    int movId, 
    double nuevoMonto, 
    Usuario adminEjecutor, {
    String? nuevaDescripcion,
    int? nuevaActividadId,
  }) async {
    if (tipo == 'I') {
      return editarPago(movId, nuevoMonto, adminEjecutor);
    }
    
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final endpoint = tipo == 'E' ? 'editarGasto' : 'editarIngresoExtra';
      final paramId = tipo == 'E' ? 'gastoId' : 'ingresoId';

      final Map<String, dynamic> body = {
        paramId: movId,
        'nuevoMonto': nuevoMonto,
        'adminRol': adminEjecutor.rol,
        'adminId': adminEjecutor.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      };

      if (nuevaDescripcion != null) {
        body['nuevaDescripcion'] = nuevaDescripcion;
      }
      if (nuevaActividadId != null) {
        body['nuevaActividadId'] = nuevaActividadId;
      } else if (tipo == 'E') {
        body['nuevaActividadId'] = 0; // para marcarlo como general
      }

      final res = await api.post(endpoint, body);

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
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
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
        unawaited(HapticFeedback.lightImpact());
        // --- NOTIFICACIÓN GLOBAL ---
        try {
          unawaited(GerenteNotificaciones.enviarPush(
            tokenDestino: '/topics/tesoreria',
            titulo: '⚠️ Gasto / Salida de Caja', 
            cuerpo: 'Se ha registrado un gasto de ${gasto.monto.toSoles()} por: ${gasto.descripcion} (Registrado por ${adminEjecutor.nombre.toFirstName()})',
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
  Future<Map<String, dynamic>> registrarIngresoExtra(double monto, String descripcion, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarIngresoExtra', { 
        'monto': monto,
        'descripcion': descripcion,
        'adminId': adminEjecutor.id,
        'adminRol': adminEjecutor.rol,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'accion': 'registrarIngresoExtra'
      });
      
      if (res['ok'] == true) {
        try {
          unawaited(GerenteNotificaciones.enviarPush(
            tokenDestino: '/topics/tesoreria',
            titulo: '🎉 Nuevo Ingreso a Caja', 
            cuerpo: '¡Se ha añadido a la caja ${monto.toSoles()}! ($descripcion) - Registrado por ${adminEjecutor.nombre.toFirstName()}',
          ));
        } catch (_) {}

        await obtenerResumenFinanciero();
        await obtenerMovimientosKardex(reset: true);
        return {'ok': true};
      }
      return {'ok': false, 'msj': res['msj'] ?? 'Error desconocido'};
    } catch (e) {
      debugPrint('Error registrando ingreso extra: $e');
      return {'ok': false, 'msj': e.toString()};
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
      debugPrint('🔍 RESUMEN SERVIDOR: ${res.toString()}');

      if (res['ok'] == true && res['resumen'] != null) {
        final resumen = res['resumen'];
        final nuevoIngresos = (resumen['totalIngresos'] as num).toDouble();
        final nuevoGastos = (resumen['totalGastos'] as num).toDouble();
        final nuevoFondoBase = (resumen['fondoBase'] as num).toDouble();
        final nuevoFondoBaseMotivo = resumen['fondoBaseMotivo']?.toString() ?? '';
        final nuevoSaldoCaja = (resumen['saldoCaja'] as num).toDouble();

        // Comparación inteligente antes de asignar y notificar
        if (nuevoIngresos != _totalIngresos ||
            nuevoGastos != _totalGastos ||
            nuevoFondoBase != _fondoBase ||
            nuevoFondoBaseMotivo != _fondoBaseMotivo ||
            nuevoSaldoCaja != _saldoCaja) {
          _totalIngresos = nuevoIngresos;
          _totalGastos = nuevoGastos;
          _fondoBase = nuevoFondoBase;
          _fondoBaseMotivo = nuevoFondoBaseMotivo;
          _saldoCaja = nuevoSaldoCaja;
          notifyListeners();

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cache_resumen_financiero', jsonEncode({
              'totalIngresos': nuevoIngresos,
              'totalGastos': nuevoGastos,
              'fondoBase': nuevoFondoBase,
              'fondoBaseMotivo': nuevoFondoBaseMotivo,
              'saldoCaja': nuevoSaldoCaja,
            }));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo resumen: $e');
    } finally {
      if (_cargando) {
        _cargando = false;
        notifyListeners();
      }
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
        'adminId': admin.id,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      
      if (res['ok'] == true) {
        unawaited(HapticFeedback.lightImpact());
        unawaited(ServicioAuditoria().registrarAccion(
          accion: 'Aperturar Caja',
          detalle: 'Monto: ${monto.toSoles()} - Motivo: $motivo',
        ));
        
        try {
          unawaited(GerenteNotificaciones.enviarPush(
              tokenDestino: '/topics/tesoreria', 
              titulo: '🏦 Caja Aperturada', 
              cuerpo: 'La caja se ha inicializado con S/ ${monto.toStringAsFixed(2)} por ${admin.nombre.toFirstName()}. Detalle: $motivo'
          ));
        } catch (_) {}

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
          'actividad_id': fila['actividad_id'],
        }).toList();

        if (nuevos.isEmpty || nuevos.length < _kardexItemsPerPage) {
          _hayMasKardex = false;
        }

        if (reset) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cache_kardex', jsonEncode(nuevos.map((fila) => {
              'tipo': fila['tipo'],
              'id_movimiento': fila['id_movimiento'],
              'descripcion': fila['descripcion'],
              'monto': fila['monto'],
              'fecha': (fila['fecha'] as DateTime).toIso8601String(),
              'actividad_id': fila['actividad_id'],
            }).toList()));
          } catch (_) {}
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
  Future<void> obtenerReporteDeudores({int? actividadId}) async {
    // Siempre mostramos el cargando cuando se cambia de actividad o se refresca
    _cargando = true;
    notifyListeners();
    
    try {
      final api = api_ext.ApiClient();
      final Map<String, dynamic> body = {};
      if (actividadId != null) {
        body['actividad_id'] = actividadId;
      }
      final res = await api.post('obtenerReporteDeudores', body);
      
      if (res['ok'] == true) {
        final results = res['datos'] as List<dynamic>;
        _listaDeudores = results.map((fila) => {
          'id': fila['id'],
          'nombre': fila['nombre'].toString(),
          'foto_url': fila['foto_url'].toString(),
          'celular': fila['celular']?.toString() ?? '',
          'deuda': (fila['deuda'] as num).toDouble(),
          'estado': fila['estado'].toString()
        }).toList();

        if (actividadId == null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cache_deudores', jsonEncode(results));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo deudores: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // --- NUEVA FUNCIÓN: Alumno Offline ---
  Future<bool> registrarAlumnoOffline({
    required String nombre,
    String? email,
    String? celular,
  }) async {
    _cargando = true;
    notifyListeners();
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('registrarAlumnoOffline', {
        'nombre': nombre,
        'email': email ?? '',
        'celular': celular ?? '',
      });
      
      if (res['ok'] == true) {
        unawaited(ServicioAuditoria().registrarAccion(
          accion: 'Alumno Offline Creado',
          detalle: 'Nombre: $nombre${email != null && email.isNotEmpty ? ', Email: $email' : ''}',
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
        final nuevasMetas = results.map((fila) => {
          'id': fila['id'],
          'titulo': fila['titulo'].toString(),
          'costo': (fila['costo'] as num? ?? 0.0).toDouble(),
          'meta_total': (fila['meta_total'] as num).toDouble(),
          'recaudado': (fila['recaudado'] as num).toDouble(),
          'gastado': (fila['gastado'] as num).toDouble(),
          'saldo_disponible': (fila['saldo_disponible'] as num).toDouble(),
          'porcentaje_recaudacion': (fila['porcentaje_recaudacion'] as num).toDouble(),
        }).toList();

        // Comparar para evitar rebuilds innecesarios
        bool hayCambios = false;
        if (nuevasMetas.length != _metasActividades.length) {
          hayCambios = true;
        } else {
          try {
            final strPrevio = jsonEncode(_metasActividades);
            final strNuevo = jsonEncode(nuevasMetas);
            if (strPrevio != strNuevo) {
              hayCambios = true;
            }
          } catch (_) {
            hayCambios = true;
          }
        }

        if (hayCambios) {
          _metasActividades = nuevasMetas;
          notifyListeners();
          
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cache_metas_actividades', jsonEncode(results));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo metas: $e');
    } finally {
      if (_cargando) {
        _cargando = false;
        notifyListeners();
      }
    }
  }
  

  Future<bool> editarFondoBase(double nuevoMonto) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('editarFondoBase', {'nuevoMonto': nuevoMonto});
      if (res['ok'] == true) {
        await obtenerResumenFinanciero();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error editarFondoBase: $e');
      return false;
    }
  }

  Future<bool> vaciarFondoBase() async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('vaciarFondoBase', {});
      if (res['ok'] == true) {
        await obtenerResumenFinanciero();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error vaciarFondoBase: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> uploadImage(Uint8List bytes, String filename) async {
    try {
      final api = api_ext.ApiClient();
      return await api.uploadImage(bytes, filename);
    } catch (e) {
      return {'ok': false, 'msj': e.toString()};
    }
  }
}



