import 'package:flutter/material.dart' show debugPrint;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart' as api_ext;

class ServicioPdf {
  
  /// Genera y comparte un reporte en formato PDF
  /// [opcion]: 
  ///   0 -> Cierre Contable Completo
  ///   1 -> Resumen General
  ///   2 -> Estado de Alumnos (Deudores)
  ///   3 -> Historial de Pagos
  ///   4 -> Historial de Gastos
  ///   5 -> Ingresos Extra
  ///   6 -> Detalle Apertura (Fondo Base)
  static Future<bool> exportarYCompartir(int opcion) async {
    try {
      final api = api_ext.ApiClient();
      final res = await api.post('obtenerDatosExcel', {});

      if (res['ok'] != true) {
        throw Exception('El servidor rechazó la descarga de datos.');
      }

      final resumen = res['resumen'] ?? {};
      final deudoresLista = List<Map<String, dynamic>>.from(res['deudores'] ?? []);
      final pagosLista = List<Map<String, dynamic>>.from(res['pagos'] ?? []);
      final gastosLista = List<Map<String, dynamic>>.from(res['gastos'] ?? []);
      final extrasLista = List<Map<String, dynamic>>.from(res['extras'] ?? []);
      final fondoLista = List<Map<String, dynamic>>.from(res['fondo_base'] ?? []);

      // Crear el documento PDF
      final pdf = pw.Document();
      final String timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Estilos de texto reutilizables
      final pw.TextStyle titleStyle = pw.TextStyle(
        fontSize: 18, 
        fontWeight: pw.FontWeight.bold, 
        color: PdfColor.fromHex('#1D3557'),
      );
      final pw.TextStyle subtitleStyle = const pw.TextStyle(
        fontSize: 10, 
        color: PdfColors.grey700,
      );
      final pw.TextStyle headerStyle = pw.TextStyle(
        fontSize: 9, 
        fontWeight: pw.FontWeight.bold, 
        color: PdfColors.white,
      );
      final pw.TextStyle dataStyle = const pw.TextStyle(
        fontSize: 8, 
        color: PdfColors.black,
      );
      final pw.TextStyle dataStyleBold = pw.TextStyle(
        fontSize: 8, 
        fontWeight: pw.FontWeight.bold, 
        color: PdfColors.black,
      );
      final pw.TextStyle footerStyle = pw.TextStyle(
        fontSize: 8, 
        fontStyle: pw.FontStyle.italic, 
        color: PdfColors.grey600,
      );

      // Decoración de cabecera de tabla
      final tableHeaderDecoration = pw.BoxDecoration(
        color: PdfColor.fromHex('#1D3557'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      );

      // Función auxiliar para formatear montos a moneda peruana (S/)
      String fmtMoney(dynamic val) {
        double dVal = double.tryParse(val?.toString() ?? '0') ?? 0.0;
        return 'S/ ${dVal.toStringAsFixed(2)}';
      }

      // ------------------------------------------------------------------------
      // COMPONENTES DE RENDERIZADO
      // ------------------------------------------------------------------------

      // Cabecera institucional premium
      pw.Widget buildHeader(String titleText) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('InSOFT TESORERÍA DSI', style: titleStyle),
                    pw.Text('Promoción DSI - Auditoría y Finanzas', style: subtitleStyle),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Fecha: $timestamp', style: subtitleStyle),
                    pw.Text('Estado: Activo / Auditado', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1D3557')),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(titleText.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#457B9D'))),
            ),
            pw.SizedBox(height: 15),
          ],
        );
      }

      // Pie de página premium
      pw.Widget buildFooter(pw.Context context) {
        return pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generado automáticamente por InSOFT - Sistema de Control y Auditoría', style: footerStyle),
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: footerStyle),
              ],
            ),
          ],
        );
      }

      // 1. Resumen de Caja General Widget
      pw.Widget buildResumenWidget() {
        double deudaTotal = 0;
        for (var d in deudoresLista) {
          double tp = double.tryParse(d['total_a_pagar']?.toString() ?? '0') ?? 0.0;
          double tpagado = double.tryParse(d['total_pagado']?.toString() ?? '0') ?? 0.0;
          deudaTotal += (tp - tpagado);
        }

        final items = [
          ['(+) Fondo de Apertura (Total)', fmtMoney(resumen['fondoBase'])],
          ['(+) Ingresos (Pagos + Extras)', fmtMoney(resumen['totalIngresos'])],
          ['(-) Gastos Totales', fmtMoney(resumen['totalGastos'])],
          ['(=) SALDO ACTUAL EN CAJA', fmtMoney(resumen['saldoCaja'])],
          ['(*) Deuda Pendiente (Por Cobrar)', fmtMoney(deudaTotal)],
        ];

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Resumen Consolidado de Fondos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Concepto Financiero', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monto (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...items.map((it) {
                  final bool esSaldo = it[0].contains('SALDO');
                  final cellDecor = esSaldo ? const pw.BoxDecoration(color: PdfColors.grey100) : null;
                  final textStyle = esSaldo ? dataStyleBold : const pw.TextStyle(fontSize: 8, color: PdfColors.black);

                  return pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it[0], style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it[1], style: textStyle, textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // 2. Estado de Alumnos (Deudores) Widget
      pw.Widget buildAlumnosWidget() {
        double totalPagado = 0;
        double totalDeuda = 0;

        for (var row in deudoresLista) {
          double tp = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
          double tpagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
          totalPagado += tpagado;
          totalDeuda += (tp - tpagado);
        }

        int index = 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Estado Financiero de Alumnos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(45),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(70),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(55),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nombres y Apellidos', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rol', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Celular', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Pagado (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Deuda (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Estado', style: headerStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                ...deudoresLista.map((row) {
                  double tp = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
                  double tpagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
                  double deuda = tp - tpagado;
                  
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);
                  final isDeudor = deuda > 0;

                  final widgetRow = pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${index++}', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['nombre']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['rol']?.toString() ?? '', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['celular']?.toString() ?? '-', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(tpagado), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(deuda), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(
                        isDeudor ? 'Deudor' : 'Al día', 
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: isDeudor ? PdfColors.red700 : PdfColors.green700),
                        textAlign: pw.TextAlign.center,
                      )),
                    ],
                  );
                  return widgetRow;
                }), // Totales
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL GENERAL', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalPagado), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalDeuda), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // 3. Historial de Pagos Widget
      pw.Widget buildPagosWidget() {
        double totalMonto = 0;
        double totalMora = 0;

        for (var row in pagosLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
          totalMora += double.tryParse(row['monto_multa']?.toString() ?? '0') ?? 0.0;
        }

        int index = 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Historial General de Pagos Recibidos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(55),
                5: const pw.FixedColumnWidth(50),
                6: const pw.FixedColumnWidth(55),
                7: const pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Alumno', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Actividad', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Método', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Monto (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Mora (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cajero', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha Pago', style: headerStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                ...pagosLista.map((row) {
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);
                  
                  return pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${index++}', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['alumno']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['actividad']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['metodo_pago']?.toString() ?? 'Efectivo', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(row['monto']), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(row['monto_multa']), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['recaudador']?.toString() ?? 'Sistema', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['fecha_pago']?.toString() ?? '', style: dataStyle, textAlign: pw.TextAlign.center)),
                    ],
                  );
                }), // Totales
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL PAGADO', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMora), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // 4. Historial de Gastos Widget
      pw.Widget buildGastosWidget() {
        double totalMonto = 0;
        for (var row in gastosLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        int index = 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Historial General de Egresos (Gastos)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(60),
                6: const pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Descripción', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Actividad Imputada', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Responsable', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Monto (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Comprobante', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha Gasto', style: headerStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                ...gastosLista.map((row) {
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);
                  final stringUrl = row['comprobante_url']?.toString().trim() ?? '';
                  final tieneComprobante = stringUrl.isNotEmpty;
                  
                  return pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${index++}', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['descripcion']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['actividad']?.toString() ?? 'Gasto General', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['responsable']?.toString() ?? 'Sistema', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(row['monto']), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(
                        tieneComprobante ? 'Sí' : 'No', 
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: tieneComprobante ? PdfColors.green700 : PdfColors.grey700), 
                        textAlign: pw.TextAlign.center,
                      )),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['fecha_gasto']?.toString() ?? '', style: dataStyle, textAlign: pw.TextAlign.center)),
                    ],
                  );
                }), // Totales
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL GASTOS', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // 5. Ingresos Extra Widget
      pw.Widget buildExtrasWidget() {
        double totalMonto = 0;
        for (var row in extrasLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        int index = 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Detalle de Ingresos Extras y Donaciones', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FixedColumnWidth(85),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Descripción / Motivo', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Monto Ingreso (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Responsable', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha Registro', style: headerStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                ...extrasLista.map((row) {
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);

                  return pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${index++}', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['descripcion']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(row['monto']), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['responsable']?.toString() ?? 'Sistema', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['fecha_ingreso']?.toString() ?? '', style: dataStyle, textAlign: pw.TextAlign.center)),
                    ],
                  );
                }), // Totales
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL INGRESOS EXTRA', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // 6. Detalle Apertura (Fondo Base) Widget
      pw.Widget buildFondoWidget() {
        double totalMonto = 0;
        for (var row in fondoLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        int index = 1;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Fondo Inicial de Apertura', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FixedColumnWidth(100),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(100),
              },
              children: [
                pw.TableRow(
                  decoration: tableHeaderDecoration,
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Monto Base (S/)', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Motivo / Notas', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha Apertura', style: headerStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                ...fondoLista.map((row) {
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);

                  return pw.TableRow(
                    decoration: cellDecor,
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${index++}', style: dataStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fmtMoney(row['monto']), style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['motivo']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row['fecha_apertura']?.toString() ?? '', style: dataStyle, textAlign: pw.TextAlign.center)),
                    ],
                  );
                }), // Totales
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL FONDOS BASE', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
        );
      }

      // ------------------------------------------------------------------------
      // ASOCIACIÓN DE COMPONENTES A PÁGINAS DEL PDF SEGÚN OPCIÓN
      // ------------------------------------------------------------------------

      if (opcion == 0) {
        // CIERRE CONTABLE COMPLETO (MULTIpágINA CONSOLIDADO)
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => buildHeader('Cierre Contable Consolidado Completo'),
            footer: (context) => buildFooter(context),
            build: (context) => [
              buildResumenWidget(),
              pw.SizedBox(height: 10),
              buildAlumnosWidget(),
              pw.SizedBox(height: 10),
              buildPagosWidget(),
              pw.SizedBox(height: 10),
              buildGastosWidget(),
              pw.SizedBox(height: 10),
              buildExtrasWidget(),
              pw.SizedBox(height: 10),
              buildFondoWidget(),
            ],
          ),
        );
      } else {
        // REPORTES INDIVIDUALES
        String label = 'Reporte Financiero';
        pw.Widget Function() widgetBuilder;

        switch (opcion) {
          case 1:
            label = 'Resumen de Caja General';
            widgetBuilder = () => buildResumenWidget();
            break;
          case 2:
            label = 'Estado General de Alumnos';
            widgetBuilder = () => buildAlumnosWidget();
            break;
          case 3:
            label = 'Historial General de Pagos';
            widgetBuilder = () => buildPagosWidget();
            break;
          case 4:
            label = 'Historial General de Gastos (Egresos)';
            widgetBuilder = () => buildGastosWidget();
            break;
          case 5:
            label = 'Detalle de Ingresos Extras y Donaciones';
            widgetBuilder = () => buildExtrasWidget();
            break;
          case 6:
            label = 'Historial de Fondo Inicial de Apertura';
            widgetBuilder = () => buildFondoWidget();
            break;
          default:
            throw Exception('Opción no configurada para PDF');
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => buildHeader(label),
            footer: (context) => buildFooter(context),
            build: (context) => [
              widgetBuilder(),
            ],
          ),
        );
      }

      // Convertir el documento a bytes
      final Uint8List pdfBytes = await pdf.save();

      // Definir nombre de archivo
      String nomArchivo = 'Reporte_Insoft_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      // Mostrar vista previa interactiva e impresión/compartición en el dispositivo
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: nomArchivo,
      );

      return true;
    } catch (e) {
      debugPrint('Error exportando reporte a PDF: $e');
      return false;
    }
  }
}
