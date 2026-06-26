import 'package:flutter/material.dart' hide Border, BorderSide, BorderStyle;
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart' as api_ext;

class ServicioExcel {
  
  /// Genera y comparte el Cierre Contable en Excel
  static Future<bool> exportarYCompartir() async {
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
      // DEFINICIÓN DE ESTILOS PREMIUM
      // -----------------------------------------------------
      // -----------------------------------------------------
      // DEFINICIÓN DE ESTILOS PREMIUM
      // -----------------------------------------------------
      final borderGrisClaro = Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#CCCCCC'),
      );

      final borderE0E0E0 = Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#E0E0E0'),
      );

      final borderDobleTesoreria = Border(
        borderStyle: BorderStyle.Double,
        borderColorHex: ExcelColor.fromHexString('#1D3557'),
      );

      final borderThinTesoreria = Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#1D3557'),
      );

      final headerStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1D3557'), // Azul oscuro corporativo
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderGrisClaro,
        bottomBorder: borderGrisClaro,
        leftBorder: borderGrisClaro,
        rightBorder: borderGrisClaro,
      );

      final dataStyleLeft = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderE0E0E0,
        bottomBorder: borderE0E0E0,
        leftBorder: borderE0E0E0,
        rightBorder: borderE0E0E0,
      );

      final dataStyleRight = CellStyle(
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderE0E0E0,
        bottomBorder: borderE0E0E0,
        leftBorder: borderE0E0E0,
        rightBorder: borderE0E0E0,
      );

      final titleStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#1D3557'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final totalStyleLeft = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#ECEFF1'), // Fondo gris claro distinguido
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderDobleTesoreria, // Doble línea contable arriba
        bottomBorder: borderThinTesoreria,
        leftBorder: borderE0E0E0,
        rightBorder: borderE0E0E0,
      );

      final totalStyleRight = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#ECEFF1'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: borderDobleTesoreria,
        bottomBorder: borderThinTesoreria,
        leftBorder: borderE0E0E0,
        rightBorder: borderE0E0E0,
      );

      // Auxiliares para estilización automática
      void estilizarTabular(Sheet sheet, List<HorizontalAlign> alignments) {
        if (sheet.maxRows == 0) return;
        
        // 1. Cabecera (Fila 0)
        for (int col = 0; col < sheet.maxColumns; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
          cell.cellStyle = headerStyle;
        }
        
        // 2. Datos (Filas 1 a maxRows - 2)
        int lastRowIndex = sheet.maxRows - 1;
        for (int row = 1; row < lastRowIndex; row++) {
          for (int col = 0; col < sheet.maxColumns; col++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            HorizontalAlign align = col < alignments.length ? alignments[col] : HorizontalAlign.Left;
            
            cell.cellStyle = CellStyle(
              horizontalAlign: align,
              verticalAlign: VerticalAlign.Center,
              topBorder: borderE0E0E0,
              bottomBorder: borderE0E0E0,
              leftBorder: borderE0E0E0,
              rightBorder: borderE0E0E0,
            );
          }
        }
        
        // 3. Fila de Total (Fila lastRowIndex)
        for (int col = 0; col < sheet.maxColumns; col++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRowIndex));
          HorizontalAlign align = col < alignments.length ? alignments[col] : HorizontalAlign.Left;
          cell.cellStyle = (align == HorizontalAlign.Right) ? totalStyleRight : totalStyleLeft;
        }
      }

      void autoAjustarColumnas(Sheet sheet) {
        for (int col = 0; col < sheet.maxColumns; col++) {
          double maxLen = 10.0;
          for (int row = 0; row < sheet.maxRows; row++) {
            var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            if (cell.value != null) {
              String valStr = cell.value.toString();
              if (cell.value is DoubleCellValue) {
                valStr = 'S/ ${(cell.value as DoubleCellValue).value.toStringAsFixed(2)}';
              }
              // Medir la línea más larga en caso de textos multilínea (como cabeceras apiladas)
              double longestLine = 0.0;
              for (var line in valStr.split('\n')) {
                if (line.length > longestLine) {
                  longestLine = line.length.toDouble();
                }
              }
              if (longestLine > maxLen) {
                maxLen = longestLine;
              }
            }
          }
          sheet.setColumnWidth(col, maxLen + 4.0);
        }
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

      // Aplicar estilos a Resumen General
      sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = headerStyle;
      sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).cellStyle = headerStyle;
      
      final resumenRows = [3, 4, 5, 6, 8];
      for (var r in resumenRows) {
        sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = dataStyleLeft;
        sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = dataStyleRight;
      }
      autoAjustarColumnas(sheetResumen);

      // -----------------------------------------------------
      // 1. PESTAÑA: CUADRO GENERAL DE PAGOS (MATRIZ PREMIUM AUTOMÁTICA)
      // -----------------------------------------------------
      Sheet sheetMatriz = excel['Cuadro General Pagos'];
      
      final actividadesLista = List<Map<String, dynamic>>.from(res['actividades'] ?? []);
      
      // Crear cabecera de columnas apiladas verticalmente
      List<CellValue> headersMatriz = [
        TextCellValue('N°'),
        TextCellValue('NOMBRES Y APELLIDOS'),
      ];
      for (var act in actividadesLista) {
        // Romper el título de la actividad por palabras para que se apile verticalmente
        String titulo = act['titulo']?.toString() ?? '';
        titulo = titulo.trim().replaceAll(RegExp(r'\s+'), '\n');
        headersMatriz.add(TextCellValue(titulo));
      }
      headersMatriz.add(TextCellValue('Total\nGeneral\n(S/)'));
      sheetMatriz.appendRow(headersMatriz);

      // Agrupar los pagos por alumno y actividad
      Map<String, double> mapaPagos = {};
      final todosLosPagos = List<Map<String, dynamic>>.from(res['pagos'] ?? []);
      
      for (var pago in todosLosPagos) {
        String alumno = pago['alumno']?.toString() ?? '';
        String actividad = pago['actividad']?.toString() ?? '';
        double monto = double.tryParse(pago['monto']?.toString() ?? '0') ?? 0.0;
        
        String key = '${alumno}_$actividad';
        mapaPagos[key] = (mapaPagos[key] ?? 0.0) + monto;
      }

      int correlativoMatriz = 1;
      List<double> totalesColumnasActividades = List.filled(actividadesLista.length, 0.0);
      double totalGeneralTodosAlumnos = 0.0;

      for (var user in deudoresLista) {
        String nombreAlumno = user['nombre']?.toString() ?? '';
        
        List<CellValue> rowCells = [
          IntCellValue(correlativoMatriz++),
          TextCellValue(nombreAlumno),
        ];
        
        double totalPagadoPorAlumno = 0.0;
        
        for (int i = 0; i < actividadesLista.length; i++) {
          var act = actividadesLista[i];
          String tituloAct = act['titulo']?.toString() ?? '';
          
          String key = '${nombreAlumno}_$tituloAct';
          double montoPagado = mapaPagos[key] ?? 0.0;
          
          totalPagadoPorAlumno += montoPagado;
          totalesColumnasActividades[i] += montoPagado;
          
          if (montoPagado > 0) {
            rowCells.add(DoubleCellValue(montoPagado));
          } else {
            rowCells.add(TextCellValue('')); // Celda vacía como en su Excel
          }
        }
        
        totalGeneralTodosAlumnos += totalPagadoPorAlumno;
        rowCells.add(DoubleCellValue(totalPagadoPorAlumno));
        sheetMatriz.appendRow(rowCells);
      }

      // Fila de Totales de Columnas al final
      List<CellValue> footerRow = [
        TextCellValue(''),
        TextCellValue('Total'),
      ];
      for (double totAct in totalesColumnasActividades) {
        footerRow.add(DoubleCellValue(totAct));
      }
      footerRow.add(DoubleCellValue(totalGeneralTodosAlumnos));
      sheetMatriz.appendRow(footerRow);

      // Estilizar la Matriz de Pagos
      List<HorizontalAlign> alignmentsMatriz = [
        HorizontalAlign.Center, // N°
        HorizontalAlign.Left,   // Nombres y Apellidos
      ];
      for (int i = 0; i < actividadesLista.length; i++) {
        alignmentsMatriz.add(HorizontalAlign.Right);
      }
      alignmentsMatriz.add(HorizontalAlign.Right); // Total General
      
      estilizarTabular(sheetMatriz, alignmentsMatriz);
      autoAjustarColumnas(sheetMatriz);

      // -----------------------------------------------------
      // 2. PESTAÑA: DEUDORES (ESTADO DE ALUMNOS)
      // -----------------------------------------------------
      Sheet sheetAlumnos = excel['Estado Alumnos'];
      sheetAlumnos.appendRow([
        TextCellValue('ID'), 
        TextCellValue('Nombre'), 
        TextCellValue('Rol'), 
        TextCellValue('Celular'), 
        TextCellValue('Total Pagado (S/)'), 
        TextCellValue('Deuda Total (S/)'), 
        TextCellValue('Estado')
      ]);

      double totalPagadoAlumnos = 0;
      double totalDeudaAlumnos = 0;

      for (var row in deudoresLista) {
        double totalPagar = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
        double totalPagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
        double deuda = totalPagar - totalPagado;
        
        totalPagadoAlumnos += totalPagado;
        totalDeudaAlumnos += deuda;

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

      // Fila de Totales
      sheetAlumnos.appendRow([
        TextCellValue(''),
        TextCellValue('TOTAL GENERAL'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(totalPagadoAlumnos),
        DoubleCellValue(totalDeudaAlumnos),
        TextCellValue(''),
      ]);

      estilizarTabular(sheetAlumnos, [
        HorizontalAlign.Center,
        HorizontalAlign.Left,
        HorizontalAlign.Center,
        HorizontalAlign.Center,
        HorizontalAlign.Right,
        HorizontalAlign.Right,
        HorizontalAlign.Center
      ]);
      autoAjustarColumnas(sheetAlumnos);

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
      double totalPagosMonto = 0;
      double totalPagosMora = 0;

      for (var row in pagosLista) {
        double monto = double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        double multa = double.tryParse(row['monto_multa']?.toString() ?? '0') ?? 0.0;

        totalPagosMonto += monto;
        totalPagosMora += multa;

        sheetPagos.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['alumno']?.toString() ?? ''),
          TextCellValue(row['actividad']?.toString() ?? ''),
          TextCellValue(row['metodo_pago']?.toString() ?? 'Efectivo'),
          DoubleCellValue(monto),
          DoubleCellValue(multa),
          TextCellValue(row['recaudador']?.toString() ?? 'Sistema'),
          TextCellValue(row['fecha_pago']?.toString() ?? ''),
        ]);
      }

      // Fila de Totales
      sheetPagos.appendRow([
        TextCellValue(''),
        TextCellValue('TOTAL RECAUDADO'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(totalPagosMonto),
        DoubleCellValue(totalPagosMora),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      estilizarTabular(sheetPagos, [
        HorizontalAlign.Center,
        HorizontalAlign.Left,
        HorizontalAlign.Left,
        HorizontalAlign.Center,
        HorizontalAlign.Right,
        HorizontalAlign.Right,
        HorizontalAlign.Left,
        HorizontalAlign.Center
      ]);
      autoAjustarColumnas(sheetPagos);

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
      double totalGastosMonto = 0;

      for (var row in gastosLista) {
        double monto = double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        totalGastosMonto += monto;

        sheetGastos.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['descripcion']?.toString() ?? ''),
          TextCellValue(row['actividad']?.toString() ?? 'Gasto General'),
          TextCellValue(row['responsable']?.toString() ?? 'Sistema'),
          DoubleCellValue(monto),
          TextCellValue((row['comprobante_url'] != null && row['comprobante_url'].toString().trim().isNotEmpty) ? 'Sí' : 'No'),
          TextCellValue(row['fecha_gasto']?.toString() ?? ''),
        ]);
      }

      // Fila de Totales
      sheetGastos.appendRow([
        TextCellValue(''),
        TextCellValue('TOTAL GASTOS'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(totalGastosMonto),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      estilizarTabular(sheetGastos, [
        HorizontalAlign.Center,
        HorizontalAlign.Left,
        HorizontalAlign.Left,
        HorizontalAlign.Left,
        HorizontalAlign.Right,
        HorizontalAlign.Center,
        HorizontalAlign.Center
      ]);
      autoAjustarColumnas(sheetGastos);

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
      double totalExtrasMonto = 0;

      for (var row in extrasLista) {
        double monto = double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        totalExtrasMonto += monto;

        sheetExtras.appendRow([
          IntCellValue(int.tryParse(row['id']?.toString() ?? '0') ?? 0),
          TextCellValue(row['descripcion']?.toString() ?? ''),
          DoubleCellValue(monto),
          TextCellValue(row['responsable']?.toString() ?? 'Sistema'),
          TextCellValue(row['fecha_ingreso']?.toString() ?? ''),
        ]);
      }

      // Fila de Totales
      sheetExtras.appendRow([
        TextCellValue(''),
        TextCellValue('TOTAL INGRESOS EXTRA'),
        DoubleCellValue(totalExtrasMonto),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      estilizarTabular(sheetExtras, [
        HorizontalAlign.Center,
        HorizontalAlign.Left,
        HorizontalAlign.Right,
        HorizontalAlign.Left,
        HorizontalAlign.Center
      ]);
      autoAjustarColumnas(sheetExtras);

      // -----------------------------------------------------
      // 5. PESTAÑA: DETALLE APERTURA (FONDO BASE)
      // -----------------------------------------------------
      Sheet sheetFondo = excel['Detalle Apertura'];
      sheetFondo.appendRow([
        TextCellValue('Monto base (S/)'), 
        TextCellValue('Motivo / Nombre'), 
        TextCellValue('Fecha de Apertura')
      ]);

      final fondoLista = List<Map<String, dynamic>>.from(res['fondo_base'] ?? []);
      double totalFondoMonto = 0;

      for (var row in fondoLista) {
        double monto = double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        totalFondoMonto += monto;

        sheetFondo.appendRow([
          DoubleCellValue(monto),
          TextCellValue(row['motivo']?.toString() ?? ''),
          TextCellValue(row['fecha_apertura']?.toString() ?? ''),
        ]);
      }

      // Fila de Totales
      sheetFondo.appendRow([
        DoubleCellValue(totalFondoMonto),
        TextCellValue('TOTAL BASE DE APERTURA'),
        TextCellValue(''),
      ]);

      estilizarTabular(sheetFondo, [
        HorizontalAlign.Right,
        HorizontalAlign.Left,
        HorizontalAlign.Center
      ]);
      autoAjustarColumnas(sheetFondo);

      // -----------------------------------------------------
      // 6. PESTAÑA: RESUMEN DE ACTIVIDADES
      // -----------------------------------------------------
      Sheet sheetActividades = excel['Resumen de Actividades'];


      // Calcular ingresos y gastos por actividad
      Map<String, double> ingresosPorActividad = {};
      Map<String, double> gastosPorActividad = {};

      for (var p in pagosLista) {
        String act = p['actividad'] ?? 'Sin Actividad';
        double monto = double.tryParse(p['monto']?.toString() ?? '0') ?? 0.0;
        ingresosPorActividad[act] = (ingresosPorActividad[act] ?? 0.0) + monto;
      }

      for (var g in gastosLista) {
        String act = g['actividad'] ?? 'Sin Actividad';
        double monto = double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0;
        gastosPorActividad[act] = (gastosPorActividad[act] ?? 0.0) + monto;
      }

      double totalExtras = 0.0;
      for (var e in extrasLista) {
        double monto = double.tryParse(e['monto']?.toString() ?? '0') ?? 0.0;
        totalExtras += monto;
      }

      // Obtener lista única de actividades que tienen movimientos
      Set<String> todasLasActividades = {};
      todasLasActividades.addAll(ingresosPorActividad.keys);
      todasLasActividades.addAll(gastosPorActividad.keys);

      sheetActividades.appendRow([
        TextCellValue('ACTIVIDAD / CONCEPTO'),
        TextCellValue('INGRESOS (S/)'),
        TextCellValue('GASTOS (S/)'),
        TextCellValue('UTILIDAD / PÉRDIDA (S/)'),
      ]);

      double totalIngAct = 0.0;
      double totalGasAct = 0.0;
      double totalUtilAct = 0.0;

      // Si hay extras (donaciones), agregarlas primero
      if (totalExtras > 0) {
        sheetActividades.appendRow([
          TextCellValue('DONACIONES / EXTRAS'),
          DoubleCellValue(totalExtras),
          const DoubleCellValue(0.0),
          DoubleCellValue(totalExtras),
        ]);
        totalIngAct += totalExtras;
        totalUtilAct += totalExtras;
      }

      for (var act in todasLasActividades) {
        if (act == 'DONACIONES / EXTRAS') continue;
        
        double ing = ingresosPorActividad[act] ?? 0.0;
        double gas = gastosPorActividad[act] ?? 0.0;
        double util = ing - gas;

        sheetActividades.appendRow([
          TextCellValue(act),
          DoubleCellValue(ing),
          DoubleCellValue(gas),
          DoubleCellValue(util),
        ]);

        totalIngAct += ing;
        totalGasAct += gas;
        totalUtilAct += util;
      }

      // Fila de total
      sheetActividades.appendRow([
        TextCellValue('TOTAL GENERAL'),
        DoubleCellValue(totalIngAct),
        DoubleCellValue(totalGasAct),
        DoubleCellValue(totalUtilAct),
      ]);

      estilizarTabular(sheetActividades, [
        HorizontalAlign.Left,
        HorizontalAlign.Right,
        HorizontalAlign.Right,
        HorizontalAlign.Right,
      ]);
      autoAjustarColumnas(sheetActividades);

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
