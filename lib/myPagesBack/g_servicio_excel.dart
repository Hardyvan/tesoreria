import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart' as api_ext;

class ServicioExcel {
  
  /// Genera y comparte el Cierre Contable en Excel
  static Future<bool> exportarYCompartir(BuildContext context) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerDatosExcel', {});

      if (res['ok'] != true) {
        throw Exception('El servidor rechazó la descarga de datos.');
      }

      // Inicializar Excel
      var excel = Excel.createExcel();
      
      // La librería Excel crea "Sheet1" por defecto. La usaremos para el Resumen General.
      String sheetResumenName = 'Resumen General';
      excel.rename('Sheet1', sheetResumenName);
      Sheet sheetResumen = excel[sheetResumenName];
      excel.setDefaultSheet(sheetResumenName);

      final resumen = res['resumen'] ?? {};
      final deudoresLista = List<Map<String, dynamic>>.from(res['deudores'] ?? []);
      
      // Calcular deuda total de todos los alumnos
      double deudaTotalAlumnos = 0;
      for (var d in deudoresLista) {
        double tp = double.tryParse(d['total_a_pagar']?.toString() ?? '0') ?? 0.0;
        double tpagado = double.tryParse(d['total_pagado']?.toString() ?? '0') ?? 0.0;
        deudaTotalAlumnos += (tp - tpagado);
      }

      // -----------------------------------------------------
      // 0. PESTAÑA: RESUMEN GENERAL
      // -----------------------------------------------------
      sheetResumen.appendRow([TextCellValue('RESUMEN DE CAJA AL ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}')]);
      sheetResumen.appendRow([]);
      sheetResumen.appendRow([TextCellValue('Concepto'), TextCellValue('Monto (S/)')]);
      sheetResumen.appendRow([TextCellValue('(+) Fondo de Apertura (Total)'), DoubleCellValue(double.tryParse(resumen['fondoBase']?.toString() ?? '0') ?? 0.0)]);
      sheetResumen.appendRow([TextCellValue('(+) Ingresos (Pagos + Extras)'), DoubleCellValue(double.tryParse(resumen['totalIngresos']?.toString() ?? '0') ?? 0.0)]);
      sheetResumen.appendRow([TextCellValue('(-) Gastos Totales'), DoubleCellValue(double.tryParse(resumen['totalGastos']?.toString() ?? '0') ?? 0.0)]);
      sheetResumen.appendRow([TextCellValue('(=) SALDO ACTUAL EN CAJA'), DoubleCellValue(double.tryParse(resumen['saldoCaja']?.toString() ?? '0') ?? 0.0)]);
      sheetResumen.appendRow([]);
      sheetResumen.appendRow([TextCellValue('(*) Deuda Pendiente (Por cobrar)'), DoubleCellValue(deudaTotalAlumnos)]);

      // -----------------------------------------------------
      // 1. PESTAÑA: DEUDORES (ESTADO DE ALUMNOS)
      // -----------------------------------------------------
      Sheet sheetAlumnos = excel['Estado Alumnos'];
      // Cabecera Alumnos
      sheetAlumnos.appendRow([
        TextCellValue('ID'), 
        TextCellValue('Nombre'), 
        TextCellValue('Rol'), 
        TextCellValue('Celular'), 
        TextCellValue('Total Pagado (S/)'), 
        TextCellValue('Deuda Total (S/)'), 
        TextCellValue('Estado')
      ]);

      for (var row in deudoresLista) {
        double totalPagar = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
        double totalPagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
        double deuda = totalPagar - totalPagado;
        
        sheetAlumnos.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['nombre']?.toString() ?? ''),
          TextCellValue(row['rol']?.toString() ?? ''),
          TextCellValue(row['celular']?.toString() ?? ''),
          DoubleCellValue(totalPagado),
          DoubleCellValue(deuda),
          TextCellValue(deuda > 0 ? 'Deudor' : 'Al día'),
        ]);
      }

      // -----------------------------------------------------
      // 2. PESTAÑA: HISTORIAL DE PAGOS
      // -----------------------------------------------------
      Sheet sheetPagos = excel['Historial Pagos'];
      sheetPagos.appendRow([
        TextCellValue('ID Pago'), 
        TextCellValue('Alumno'), 
        TextCellValue('Actividad'), 
        TextCellValue('Método de Pago'), 
        TextCellValue('Monto Pagado (S/)'), 
        TextCellValue('Mora Pagada (S/)'), 
        TextCellValue('Recaudador / Cajero'),
        TextCellValue('Fecha de Pago')
      ]);

      final pagosLista = List<Map<String, dynamic>>.from(res['pagos'] ?? []);
      for (var row in pagosLista) {
        sheetPagos.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['alumno']?.toString() ?? ''),
          TextCellValue(row['actividad']?.toString() ?? ''),
          TextCellValue(row['metodo_pago']?.toString() ?? 'Efectivo'),
          DoubleCellValue(double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0),
          DoubleCellValue(double.tryParse(row['monto_multa']?.toString() ?? '0') ?? 0.0),
          TextCellValue(row['recaudador']?.toString() ?? 'Sistema (Anterior)'),
          TextCellValue(row['fecha_pago']?.toString() ?? ''),
        ]);
      }

      // -----------------------------------------------------
      // 3. PESTAÑA: HISTORIAL DE GASTOS
      // -----------------------------------------------------
      Sheet sheetGastos = excel['Historial Gastos'];
      sheetGastos.appendRow([
        TextCellValue('ID Gasto'), 
        TextCellValue('Descripción'), 
        TextCellValue('Actividad Imputada'), 
        TextCellValue('Responsable (Registrado por)'),
        TextCellValue('Monto Gastado (S/)'), 
        TextCellValue('Tiene Comprobante?'),
        TextCellValue('Fecha de Gasto')
      ]);

      final gastosLista = List<Map<String, dynamic>>.from(res['gastos'] ?? []);
      for (var row in gastosLista) {
        sheetGastos.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['descripcion']?.toString() ?? ''),
          TextCellValue(row['actividad']?.toString() ?? 'Gasto General'),
          TextCellValue(row['responsable']?.toString() ?? 'Sistema'),
          DoubleCellValue(double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0),
          TextCellValue((row['comprobante_url'] != null && row['comprobante_url'].toString().trim().isNotEmpty) ? 'Sí' : 'No'),
          TextCellValue(row['fecha_gasto']?.toString() ?? ''),
        ]);
      }

      // -----------------------------------------------------
      // 4. PESTAÑA: HISTORIAL DE DONACIONES / INGRESOS EXTRA
      // -----------------------------------------------------
      Sheet sheetExtras = excel['Ingresos Extra'];
      sheetExtras.appendRow([
        TextCellValue('ID Registro'), 
        TextCellValue('Descripción o Motivo'), 
        TextCellValue('Monto Ingresado (S/)'), 
        TextCellValue('Registrado por (Responsable)'),
        TextCellValue('Fecha de Registro')
      ]);

      final extrasLista = List<Map<String, dynamic>>.from(res['extras'] ?? []);
      for (var row in extrasLista) {
        sheetExtras.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['descripcion']?.toString() ?? ''),
          DoubleCellValue(double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0),
          TextCellValue(row['responsable']?.toString() ?? 'Sistema'),
          TextCellValue(row['fecha_ingreso']?.toString() ?? ''),
        ]);
      }

      // -----------------------------------------------------
      // 5. PESTAÑA: DETALLE APERTURA (FONDO BASE)
      // -----------------------------------------------------
      Sheet sheetFondo = excel['Detalle Apertura'];
      sheetFondo.appendRow([
        TextCellValue('Monto (S/)'), 
        TextCellValue('Motivo / Nombre'), 
        TextCellValue('Fecha de Apertura')
      ]);

      final fondoLista = List<Map<String, dynamic>>.from(res['fondo_base'] ?? []);
      for (var row in fondoLista) {
        sheetFondo.appendRow([
          DoubleCellValue(double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0),
          TextCellValue(row['motivo']?.toString() ?? ''),
          TextCellValue(row['fecha_apertura']?.toString() ?? ''),
        ]);
      }

      // -----------------------------------------------------
      // GUARDAR Y COMPARTIR
      // -----------------------------------------------------
      var fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Error al generar bytes de Excel');

      // Obtener ruta temporal
      final directory = await getTemporaryDirectory();
      String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      String filePath = '${directory.path}/Cierre_Contable_$timestamp.xlsx';
      
      File file = File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cierre Contable generado automáticamante.',
      );

      return true;

    } catch (e) {
      debugPrint('Error exportando a Excel: $e');
      return false;
    }
  }

}
