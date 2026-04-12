import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../myPagesServer/b_base_datos_remota.dart';
import '../myPagesServer/c_base_datos_local.dart';
import 'modelo_pago.dart';
import 'modelo_gasto.dart';
import 'modelo_usuario.dart';
import 'i_servicio_notificaciones.dart';
import 'j_servicio_notificaciones_secundario.dart' as push;
import 'k_servicio_auditoria.dart';
import 'dart:async';
import 'dart:convert';
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
  
  // CACHE SISTEMA (MAPA)
  final Map<int, List<Map<String, dynamic>>> _cacheDetallePagos = {};

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

  // Cargar resumen financiero del usuario (FASE 5: Real)
  Future<void> cargarFinanzasUsuario(int usuarioId) async {
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. Obtener Totales (Deuda y Pagado)
      // Costo Total de Actividades
      final resultCosto = await conn.query('SELECT COALESCE(SUM(costo), 0) as total FROM DSI_salon_actividades');
      double totalCosto = (resultCosto.first['total'] ?? 0.0).toDouble();
      
      // Total Pagado por este usuario
      final resultPagado = await conn.query('SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE usuario_id = ? AND confirmado = 1', [usuarioId]);
      _totalPagado = (resultPagado.first['total'] ?? 0.0).toDouble();
      
      _deudaTotal = totalCosto - _totalPagado;
      if (_deudaTotal < 0) _deudaTotal = 0; // Por si acaso

      // --- RECORDATORIO DIARIO ---
      // Si debe dinero, programamos la alarma local. Si no, la cancelamos.
      if (_deudaTotal > 0) {
        unawaited(ServicioNotificaciones().programarRecordatorioDeuda(_deudaTotal));
      } else {
        unawaited(ServicioNotificaciones().cancelarRecordatorios());
      }
      
      // 2. Obtener Historial de Pagos Recientes
      final resultHistorial = await conn.query('''
        SELECT p.id, a.titulo as actividad, p.monto, p.fecha_pago 
        FROM DSI_salon_pagos p
        JOIN DSI_salon_actividades a ON p.actividad_id = a.id
        WHERE p.usuario_id = ? AND p.confirmado = 1
        ORDER BY p.fecha_pago DESC
      ''', [usuarioId]);
      
      _misPagos = resultHistorial.map((fila) => {
        'id': fila['id'],
        'actividad': fila['actividad'].toString(),
        'monto': (fila['monto'] ?? 0.0).toDouble(),
        'fecha': fila['fecha_pago']
      }).toList();
      
    } catch (e) {
      debugPrint('Error cargando finanzas usuario: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> obtenerDetallePagosPorActividad(int usuarioId, {bool forceRefresh = false}) async {
    // 1. Verificar CACHÉ (MAPA) para respuesta instantánea
    if (!forceRefresh && _cacheDetallePagos.containsKey(usuarioId)) {
      debugPrint('CACHE: Cargando historial desde memoria (instantáneo)');
      return _cacheDetallePagos[usuarioId]!;
    }

    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // Left Join para traer TODAS las actividades y sus pagos (si los hay)
      final results = await conn.query('''
        SELECT 
          a.id as actividad_id, 
          a.titulo, 
          a.costo, 
          p.id as pago_id, 
          p.monto, 
          p.monto_multa,
          p.fecha_pago
        FROM DSI_salon_actividades a
        LEFT JOIN DSI_salon_pagos p ON a.id = p.actividad_id AND p.usuario_id = ? AND p.confirmado = 1
        ORDER BY a.fecha_creacion DESC, p.fecha_pago DESC
      ''', [usuarioId]);

      // Agrupamiento en Dart
      Map<int, Map<String, dynamic>> agrupado = {};

      for (var row in results) {
        int idActividad = row['actividad_id'];
        
        if (!agrupado.containsKey(idActividad)) {
          agrupado[idActividad] = {
            'titulo': row['titulo'].toString(),
            'costo': (row['costo'] ?? 0.0).toDouble(),
            'pagos': <Map<String, dynamic>>[],
            'total_pagado': 0.0,
            'estado': 'Pendiente' // Pendiente, Parcial, Pagado
          };
        }

        if (row['pago_id'] != null) {
          double monto = (row['monto'] ?? 0.0).toDouble();
          double multa = (row['monto_multa'] ?? 0.0).toDouble();
          agrupado[idActividad]!['pagos'].add({
             'id': row['pago_id'],
             'fecha': row['fecha_pago'],
             'monto': monto,
             'multa': multa
          });
          agrupado[idActividad]!['total_pagado'] += monto;
        }
      }

      // Calcular estados finales
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
      
      // 2. Guardar en CACHÉ (MAPA)
      _cacheDetallePagos[usuarioId] = listaFinal;

      return listaFinal;
      
    } catch (e) {
      debugPrint('Error obteniendo detalle pagos: $e');
      return _cacheDetallePagos[usuarioId] ?? []; // Devolver caché si falla la red
    }
  }

  // Registrar un nuevo pago (Solo Admin)
  Future<bool> registrarPago(Pago pago, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. SEGURIDAD: Verificar si quien llama es Admin (Legacy o Firebase)
      bool esAdminSeguro = false;

      if (adminEjecutor.rol == 'Admin' || adminEjecutor.rol == 'SuperAdmin') {
        esAdminSeguro = true;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty) {
             final rolDb = resultRol.first['rol'].toString();
             if (rolDb == 'Admin' || rolDb == 'SuperAdmin') {
               esAdminSeguro = true;
             }
           }
        }
      }

      if (!esAdminSeguro) {
        debugPrint('SEGURIDAD: Intento de escritura no autorizado');
        return false;
      }
      
      // 2. Preventiva: Asegurar columna de metodo_pago
      try {
        await conn.query("ALTER TABLE DSI_salon_pagos ADD COLUMN metodo_pago VARCHAR(20) DEFAULT 'Efectivo'");
      } catch (_) {}

      // 3. CALCULO AUTOMATICO DE MULTA
      double montoMultaCalculada = 0.0;
      try {
        final resultActividad = await conn.query(
          'SELECT fecha_limite, multa_por_dia FROM DSI_salon_actividades WHERE id = ?',
          [pago.actividadId]
        );
        if (resultActividad.isNotEmpty) {
          final fechaLimiteRaw = resultActividad.first['fecha_limite'];
          final multaPorDia = (resultActividad.first['multa_por_dia'] ?? 0.0).toDouble();

          if (fechaLimiteRaw != null && multaPorDia > 0) {
            final fechaLimite = fechaLimiteRaw is DateTime
                ? fechaLimiteRaw
                : DateTime.tryParse(fechaLimiteRaw.toString());

            if (fechaLimite != null) {
              final hoy = DateTime.now();
              final diasAtraso = hoy.difference(fechaLimite).inDays;
              if (diasAtraso > 0) {
                montoMultaCalculada = (diasAtraso * multaPorDia).toDouble();
                debugPrint('Multa aplicada: $diasAtraso dias x S/ $multaPorDia = S/ $montoMultaCalculada');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Advertencia: no pudo calcular multa: $e'); // No es fatal
      }

      try {
        await conn.query('ALTER TABLE DSI_salon_pagos ADD COLUMN admin_id INT(11) NULL');
      } catch (_) {}

      // 4. Proceder con el registro (incluyendo multa si aplica y admin_id)
      await conn.query(
        'INSERT INTO DSI_salon_pagos (usuario_id, actividad_id, monto, monto_multa, fecha_pago, confirmado, metodo_pago, admin_id) VALUES (?, ?, ?, ?, NOW(), ?, ?, ?)',
        [pago.usuarioId, pago.actividadId, pago.montoPagado, montoMultaCalculada, true, pago.metodoPago, adminEjecutor.id]
      );

      // --- NOTIFICACIÃ“N GLOBAL ---
      // --- NOTIFICACIÃ“N INDIVIDUAL (FCM v1) ---
      try {
        // 1. Obtener el token FCM del alumno
        var resultToken = await conn.query(
          'SELECT fcm_token FROM DSI_salon_usuarios WHERE id = ?', 
          [pago.usuarioId]
        );

        if (resultToken.isNotEmpty && resultToken.first['fcm_token'] != null) {
          String tokenDestino = resultToken.first['fcm_token'].toString();
          
          // 2. Enviar Push usando la nueva API v1
          await push.ServicioNotificacionesSecundario.enviarPush(
            tokenDestino: tokenDestino,
            titulo: 'ðŸ’° Pago Validado', 
            cuerpo: 'Hemos registrado tu pago de S/ ${pago.montoPagado.toStringAsFixed(2)}.'
          );
        } else {
          debugPrint('âš ï¸ El usuario no tiene token FCM registrado.');
        }
      } catch (e) {
        debugPrint('Error enviando notificaciÃ³n push: $e');
      }
      // --- AUDITORÃA (NUEVO) ---
      // Registramos quiÃ©n hizo el pago y desde quÃ© dispositivo
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Registrar Pago',
        detalle: 'Monto: S/ ${pago.montoPagado.toStringAsFixed(2)} - Alumno ID: ${pago.usuarioId} - Actividad ID: ${pago.actividadId}',
      ));

      return true;
    } catch (e) {
      debugPrint('Error registrando pago en la nube: $e');
      // FALLBACK MODO OFFLINE
      debugPrint('Guardando pago localmente...');
      try {
        await BaseDatosLocal.instance.insertarPagoLocal(pago);
        debugPrint('Pago guardado offline con exito.');
        // Auditoria offline? Omitida por ahora.
        return true;
      } catch (eLocal) {
        debugPrint('Error registrando pago offline: $eLocal');
        return false;
      }
    } finally {
      notifyListeners();
    }
  }

  // --- EDITAR PAGO (Nueva FunciÃ³n) ---
  Future<bool> editarPago(int pagoId, double nuevoMonto, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // 1. SEGURIDAD: Verificar Admin
      bool esAdminSeguro = false;

      if (adminEjecutor.rol == 'Admin' || adminEjecutor.rol == 'SuperAdmin') {
        esAdminSeguro = true;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty) {
             final rolDb = resultRol.first['rol'].toString();
             if (rolDb == 'Admin' || rolDb == 'SuperAdmin') {
               esAdminSeguro = true;
             }
           }
        }
      }

      if (!esAdminSeguro) {
        debugPrint('SEGURIDAD: Intento de ediciÃ³n no autorizado');
        return false;
      }
      
      // 2. Actualizar en BD
      await conn.query(
        'UPDATE DSI_salon_pagos SET monto = ? WHERE id = ?',
        [nuevoMonto, pagoId]
      );
      
      // --- AUDITORÃA ---
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Editar Pago',
        detalle: 'Pago ID: $pagoId - Nuevo Monto: S/ ${nuevoMonto.toStringAsFixed(2)}',
      ));

      return true;
    } catch (e) {
      debugPrint('Error editando pago: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // FASE 3: CAJA GENERAL Y GASTOS (Consultas Optimizadas)
  // ---------------------------------------------------------------------------

  // --- REPORTES FINANCIEROS AVANZADOS (FASE 2) ---

  // 1. Obtener lista simple de actividades para el Dropdown
  Future<List<Map<String, dynamic>>> obtenerActividadesSimplificadas() async {
    try {
      final conn = await _db.obtenerConexion();
      final results = await conn.query('SELECT id, titulo FROM DSI_salon_actividades ORDER BY fecha_creacion DESC');
      
      return results.map((fila) => {
        'id': fila['id'],
        'titulo': fila['titulo'].toString()
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo actividades simples: $e');
      return [];
    }
  }

  // 2. Registrar Gasto (Actualizado con actividadId)
  Future<bool> registrarGasto(Gasto gasto, Usuario adminEjecutor) async {
    _cargando = true;
    notifyListeners();

    // Asegurar que la tabla tenga la columna nueva
    // await _db.autocorregirTablas(); // DESACTIVADO POR SEGURIDAD

    try {
      final conn = await _db.obtenerConexion();
      
      // SEGURIDAD: Verificar Admin
      bool esAdminSeguro = false;
      if (adminEjecutor.rol == 'Admin' || adminEjecutor.rol == 'SuperAdmin') {
        esAdminSeguro = true;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
           final resultRol = await conn.query('SELECT rol FROM DSI_salon_usuarios WHERE uid = ?', [uid]);
           if (resultRol.isNotEmpty) {
             final rolDb = resultRol.first['rol'].toString();
             if (rolDb == 'Admin' || rolDb == 'SuperAdmin') {
               esAdminSeguro = true;
             }
           }
        }
      }

      if (!esAdminSeguro) return false;

      // INSERT actualizado con actividad_id
      await conn.query(
        'INSERT INTO DSI_salon_gastos (descripcion, monto, fecha_gasto, usuario_id, actividad_id) VALUES (?, ?, NOW(), ?, ?)',
        [gasto.descripcion, gasto.monto, gasto.usuarioId, gasto.actividadId]
      );
      
      // Actualizar datos financieros automÃ¡ticamente
      await obtenerResumenFinanciero();
      await obtenerMovimientosKardex();
      
      // --- AUDITORÃA ---
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Registrar Gasto',
        detalle: 'Monto: S/ ${gasto.monto.toStringAsFixed(2)} - Desc: ${gasto.descripcion} - Actividad ID: ${gasto.actividadId}',
      ));

      return true;
    } catch (e) {
      debugPrint('Error registrando gasto: $e');
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
    
    // Ajustar fin al final del dÃ­a
    // Ajuste CRÃTICO: El driver de MySQL exige objetos DateTime.utc()
    // Pero queremos mantener la hora "Local" (Wall Clock) para que coincida con la BD.
    // Ejemplo: Si el usuario eligiÃ³ "20 Ene 00:00", enviamos "20 Ene 00:00 UTC".
    final inicioLocal = DateTime.utc(inicio.year, inicio.month, inicio.day);
    final finAjustado = DateTime.utc(fin.year, fin.month, fin.day, 23, 59, 59);

    try {
      final conn = await _db.obtenerConexion();
      
      // Asegurarnos de que admin_id exista antes de consultar
      try {
        await conn.query('ALTER TABLE DSI_salon_pagos ADD COLUMN admin_id INT(11) NULL');
      } catch (_) {}
      
      // A. TOTALES GENERALES EN EL RANGO
      final sqlIngresos = 'SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1 AND fecha_pago BETWEEN ? AND ?';
      final sqlGastos = 'SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos WHERE fecha_gasto BETWEEN ? AND ?';
      
      final resIngresos = await conn.query(sqlIngresos, [inicioLocal, finAjustado]);
      final resGastos = await conn.query(sqlGastos, [inicioLocal, finAjustado]);
      
      double totalIngresos = (resIngresos.first['total'] ?? 0.0).toDouble();
      double totalGastos = (resGastos.first['total'] ?? 0.0).toDouble();
      
      // B. DESGLOSE POR ACTIVIDAD (Ingresos - Gastos)
      // Esta query es compleja: Une actividades con sus pagos y sus gastos asociados
      String sqlDesglose = '''
        SELECT 
            a.id, 
            a.titulo,
            (SELECT COALESCE(SUM(p.monto), 0) FROM DSI_salon_pagos p WHERE p.actividad_id = a.id AND p.confirmado = 1 AND p.fecha_pago BETWEEN ? AND ?) as ingresos,
            (SELECT COALESCE(SUM(g.monto), 0) FROM DSI_salon_gastos g WHERE g.actividad_id = a.id AND g.fecha_gasto BETWEEN ? AND ?) as gastos
        FROM DSI_salon_actividades a
        ORDER BY a.fecha_creacion DESC
      ''';
      
      final resDesglose = await conn.query(sqlDesglose, [inicioLocal, finAjustado, inicioLocal, finAjustado]);
      
      List<Map<String, dynamic>> desglose = resDesglose.map((fila) {
        double ing = (fila['ingresos'] ?? 0.0).toDouble();
        double gas = (fila['gastos'] ?? 0.0).toDouble();
        return {
          'titulo': fila['titulo'].toString(),
          'ingresos': ing,
          'gastos': gas,
          'utilidad': ing - gas
        };
      }).toList();

      // C. RECAUDACIÓN POR ADMINISTRADOR (Auditoría)
      String sqlAdmins = '''
        SELECT 
            COALESCE(u.nombre, 'Sistema/Anterior') as admin_nombre,
            SUM(p.monto) as total_recaudado
        FROM DSI_salon_pagos p
        LEFT JOIN DSI_salon_usuarios u ON p.admin_id = u.id
        WHERE p.confirmado = 1 AND p.fecha_pago BETWEEN ? AND ?
        GROUP BY u.id, u.nombre
        ORDER BY total_recaudado DESC
      ''';
      
      final resAdmins = await conn.query(sqlAdmins, [inicioLocal, finAjustado]);
      
      List<Map<String, dynamic>> recaudacionAdmins = resAdmins.map((fila) {
        return {
          'admin_nombre': fila['admin_nombre'].toString(),
          'total': (fila['total_recaudado'] ?? 0.0).toDouble()
        };
      }).toList();

      return {
        'totalIngresos': totalIngresos,
        'totalGastos': totalGastos,
        'utilidadNeta': totalIngresos - totalGastos,
        'desglose': desglose,
        'recaudacionAdmins': recaudacionAdmins
      };
      
    } catch (e) {
      debugPrint('Error generando reporte avanzado: $e');
      return {'error': e.toString(), 'desglose': []};
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Instancia de Base de Datos
  final BaseDatosRemota _db = BaseDatosRemota();

  // 2. Obtener Resumen Financiero (SUM Directo en BD)
  Future<void> obtenerResumenFinanciero() async {
    _cargando = true;
    notifyListeners();
    
    try {
      await _db.inicializarTablaConfiguracion();

      final resultados = await Future.wait([
        _db.obtenerSumaIngresos(),
        _db.obtenerSumaGastos(),
        _db.obtenerConfiguracion('apertura_caja')
      ]);

      double totalPagos = resultados[0] as double;
      _totalGastos = resultados[1] as double;
      
      // Parsear Fondo Base si existe
      _fondoBase = 0.0;
      _fondoBaseMotivo = '';
      if (resultados[2] != null) {
         try {
           final baseData = jsonDecode(resultados[2] as String);
           _fondoBase = (baseData['monto'] ?? 0.0).toDouble();
           _fondoBaseMotivo = baseData['motivo']?.toString() ?? 'Sin motivo';
         } catch(e) {
           debugPrint('Error parseando fondo base: $e');
         }
      }

      _totalIngresos = totalPagos;
      _saldoCaja = _totalIngresos + _fondoBase - _totalGastos;
      
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
      if (admin.rol != 'SuperAdmin') {
         return false; // Solo SuperAdmin puede hacer esto.
      }

      final jsonDatos = jsonEncode({'monto': monto, 'motivo': motivo});
      final exito = await _db.guardarConfiguracion('apertura_caja', jsonDatos);
      
      if (exito) {
        unawaited(ServicioAuditoria().registrarAccion(
          accion: 'Aperturar Caja',
          detalle: 'Monto: S/ ${monto.toStringAsFixed(2)} - Motivo: $motivo',
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
  Future<void> obtenerMovimientosKardex({bool reset = false}) async {
    if (reset) {
      _kardexPage = 0;
      _kardex = [];
      _hayMasKardex = true;
    }

    if (!_hayMasKardex || _cargando) return;

    _cargando = true;
    notifyListeners();
    
    try {
      final nuevos = await _db.obtenerHistorialKardex(
        limit: _kardexItemsPerPage, 
        offset: _kardexPage * _kardexItemsPerPage
      );

      if (nuevos.isEmpty || nuevos.length < _kardexItemsPerPage) {
        _hayMasKardex = false;
      }

      _kardex.addAll(nuevos);
      _kardexPage++;

    } catch (e) {
      debugPrint('Error obteniendo kardex paginado: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }


  // 4. Reporte de Deudores (FASE 4)
  Future<void> obtenerReporteDeudores() async {
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // Asumimos: TODOS deben pagar TODAS las actividades
      // 1. Calculamos el costo total de todas las actividades
      // 2. Por cada alumno, sumamos sus pagos
      // 3. Deuda = CostoTotal - Pagos
      
      // Optimizamos en una sola query con subconsultas
      String sql = '''
        SELECT 
            u.id, 
            u.nombre, 
            u.foto_url,
            (SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) as total_a_pagar,
            (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
        FROM DSI_salon_usuarios u
        WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1
        ORDER BY (total_a_pagar - total_pagado) DESC
      ''';

      final results = await conn.query(sql);
      
      _listaDeudores = results.map((fila) {
        double totalPagar = (fila['total_a_pagar'] ?? 0.0).toDouble();
        double totalPagado = (fila['total_pagado'] ?? 0.0).toDouble();
        double deuda = totalPagar - totalPagado;
        
        // Ajuste por si pagÃ³ de mÃ¡s (opcional, por ahora deuda negativa es saldo a favor)
        // Pero para UI 'Debe' suele ser > 0
        
        return {
          'id': fila['id'],
          'nombre': fila['nombre'].toString(),
          'foto_url': fila['foto_url'].toString(),
          'deuda': deuda,
          'estado': deuda > 0 ? 'Deudor' : 'Al dÃ­a'
        };
      }).toList();
      
    } catch (e) {
      debugPrint('Error obteniendo deudores: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // --- NUEVA FUNCIÓN: Alumno Offline ---
  Future<bool> registrarAlumnoOffline(String nombre) async {
    final nombreFormateado = nombre.toCapitalized();
    _cargando = true;
    notifyListeners();
    try {
      final conn = await _db.obtenerConexion();
      
      String offlineUid = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      
      await conn.query(
        'INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, foto_url, rol) VALUES (?, ?, ?, ?, ?, ?)',
        [offlineUid, nombreFormateado, 'offline@tesoreriasalon.local', '000000000', '', 'Alumno']
      );

      // Auditoría
      unawaited(ServicioAuditoria().registrarAccion(
        accion: 'Alumno Offline Creado',
        detalle: 'Nombre: $nombreFormateado',
      ));

      return true;
    } catch (e) {
      debugPrint('Error registrando alumno offline: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 5. Obtener Metas por Actividad (NUEVO)
  Future<void> obtenerMetasActividades() async {
    _cargando = true;
    notifyListeners();
    
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      
      // La meta de la actividad se calcula: costo * (nro de alumnos + admins activos)
      // Excluimos al SuperAdmin con id = 1
      String sql = '''
        SELECT 
          a.id, 
          a.titulo, 
          a.costo,
          (SELECT COUNT(1) FROM DSI_salon_usuarios WHERE rol IN ('Alumno', 'Admin') AND estado = 1 AND id != 1) as total_alumnos,
          (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos p WHERE p.actividad_id = a.id AND p.confirmado = 1) as recaudado,
          (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_gastos g WHERE g.actividad_id = a.id) as gastado
        FROM DSI_salon_actividades a
        WHERE a.estado = 1
        ORDER BY a.fecha_creacion DESC
      ''';

      final results = await conn.query(sql);
      
      _metasActividades = results.map((fila) {
        double costo = (fila['costo'] ?? 0.0).toDouble();
        int totalAlumnos = fila['total_alumnos'] ?? 0;
        double recaudado = (fila['recaudado'] ?? 0.0).toDouble();
        double gastado = (fila['gastado'] ?? 0.0).toDouble();
        
        double metaTotal = costo * totalAlumnos;
        double saldoDisponible = recaudado - gastado;
        double progreso = metaTotal > 0 ? (recaudado / metaTotal) : 0.0;
        if (progreso > 1.0) progreso = 1.0;
        
        return {
          'id': fila['id'],
          'titulo': fila['titulo'].toString(),
          'meta_total': metaTotal,
          'recaudado': recaudado,
          'gastado': gastado,
          'saldo_disponible': saldoDisponible,
          'porcentaje_recaudacion': progreso,
        };
      }).toList();
      
    } catch (e) {
      debugPrint('Error obteniendo metas de actividades: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}

