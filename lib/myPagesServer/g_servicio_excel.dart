import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'b_base_datos_remota.dart';

class ServicioExcel {
  
  /// Genera y comparte el Cierre Contable en Excel
  static Future<bool> exportarYCompartir(BuildContext context) async {
    try {
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      // Inicializar Excel
      var excel = Excel.createExcel();
      
      // Configurar Formatos
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      
      // -----------------------------------------------------
      // 1. PESTAÑA: DEUDORES (ESTADO DE ALUMNOS)
      // -----------------------------------------------------
      Sheet sheetAlumnos = excel['Estado Alumnos'];
      excel.setDefaultSheet('Estado Alumnos');
      // No existe 'Sheet1' por defecto dependiendo de la versión, pero renombraremos las creadas.
      if (excel.tables.containsKey('Sheet1')) {
         excel.rename('Sheet1', 'Estado Alumnos');
         sheetAlumnos = excel['Estado Alumnos'];
      }

      // Cabecera Alumnos
      sheetAlumnos.appendRow([
        TextCellValue('ID'), 
        TextCellValue('Nombre'), 
        TextCellValue('Rol'), 
        TextCellValue('Celular'), 
        TextCellValue('Deuda Total (S/)'), 
        TextCellValue('Estado')
      ]);

      String sqlDeudores = '''
        SELECT 
            u.id, 
            u.nombre, 
            u.rol,
            u.celular,
            (SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) as total_a_pagar,
            (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
        FROM DSI_salon_usuarios u
        WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1
        ORDER BY (total_a_pagar - total_pagado) DESC
      ''';
      
      var resDeudores = await conn.query(sqlDeudores);
      for (var row in resDeudores) {
        double totalPagar = (row['total_a_pagar'] ?? 0.0).toDouble();
        double totalPagado = (row['total_pagado'] ?? 0.0).toDouble();
        double deuda = totalPagar - totalPagado;
        
        sheetAlumnos.appendRow([
          IntCellValue(row['id']),
          TextCellValue(row['nombre'].toString()),
          TextCellValue(row['rol'].toString()),
          TextCellValue(row['celular']?.toString() ?? ''),
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
        TextCellValue('Monto Pagado (S/)'), 
        TextCellValue('Fecha de Pago')
      ]);

      String sqlPagos = '''
        SELECT 
          p.id, u.nombre as alumno, a.titulo as actividad, p.monto, p.fecha_pago
        FROM DSI_salon_pagos p
        JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
        JOIN DSI_salon_actividades a ON p.actividad_id = a.id
        WHERE p.confirmado = 1
        ORDER BY p.fecha_pago DESC
      ''';
      
      var resPagos = await conn.query(sqlPagos);
      for (var row in resPagos) {
        sheetPagos.appendRow([
          IntCellValue(row['id']),
          TextCellValue(row['alumno'].toString()),
          TextCellValue(row['actividad'].toString()),
          DoubleCellValue((row['monto'] ?? 0.0).toDouble()),
          TextCellValue(row['fecha_pago'] != null ? dateFormat.format(row['fecha_pago'] as DateTime) : ''),
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
        TextCellValue('Fecha de Gasto')
      ]);

      String sqlGastos = '''
        SELECT 
          g.id, g.descripcion, a.titulo as actividad, u.nombre as responsable, g.monto, g.fecha_gasto
        FROM DSI_salon_gastos g
        LEFT JOIN DSI_salon_actividades a ON g.actividad_id = a.id
        LEFT JOIN DSI_salon_usuarios u ON g.usuario_id = u.id
        ORDER BY g.fecha_gasto DESC
      ''';
      
      var resGastos = await conn.query(sqlGastos);
      for (var row in resGastos) {
        sheetGastos.appendRow([
          IntCellValue(row['id']),
          TextCellValue(row['descripcion'].toString()),
          TextCellValue(row['actividad']?.toString() ?? 'Gasto General'),
          TextCellValue(row['responsable']?.toString() ?? 'Sistema'),
          DoubleCellValue((row['monto'] ?? 0.0).toDouble()),
          TextCellValue(row['fecha_gasto'] != null ? dateFormat.format(row['fecha_gasto'] as DateTime) : ''),
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

      // Usar share_plus para abrir selector y compartir a WhatsApp (número por defecto propuesto: 986342182)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cierre Contable generado automáticamante. (Sugerido para Teso: 986342182)',
      );

      return true;

    } catch (e) {
      debugPrint('Error exportando a Excel: $e');
      return false;
    }
  }

}
