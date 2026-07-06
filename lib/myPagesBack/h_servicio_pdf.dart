import 'package:flutter/material.dart' show debugPrint;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart' as api_ext;

class ServicioPdf {
  
  /// Genera un reporte en formato PDF y devuelve sus bytes
  /// [opcion]: 
  ///   0 -> Cierre Contable Completo
  ///   1 -> Resumen General
  ///   2 -> Estado de Alumnos (Deudores)
  ///   3 -> Historial de Pagos
  ///   4 -> Historial de Gastos
  ///   5 -> Ingresos Extra
  ///   6 -> Detalle Apertura (Fondo Base)
  static Future<Uint8List?> generarPdfBytes(int opcion) async {
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
      final actividadesLista = List<Map<String, dynamic>>.from(res['actividades'] ?? []);

      // Cargar fuentes compatibles con Unicode para evitar errores de acentos/ñ
      final pw.Font unicodeFont = await PdfGoogleFonts.openSansRegular();
      final pw.Font unicodeFontBold = await PdfGoogleFonts.openSansBold();

      // Crear el documento PDF con el tema de fuente configurado
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: unicodeFont,
          bold: unicodeFontBold,
        ),
      );
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
      List<pw.Widget> buildResumenWidgets() {
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

        return [
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
        ];
      }

      // 1.2. Resumen por Actividades Widget
      List<pw.Widget> buildResumenActividadesWidgets() {
        List<pw.Widget> widgets = [];
        
        widgets.add(
          pw.Text(
            'Resumen Financiero por Actividad / Concepto',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1D3557'),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
        
        // Calcular datos
        // 1. Ingresos Extra (Donaciones / Extras)
        double totalExtras = 0.0;
        for (var ext in extrasLista) {
          totalExtras += double.tryParse(ext['monto']?.toString() ?? '0') ?? 0.0;
        }
        
        // 2. Por actividad
        Map<String, double> ingresosPorActividad = {};
        for (var p in pagosLista) {
          String act = p['actividad'] ?? '';
          double monto = double.tryParse(p['monto']?.toString() ?? '0') ?? 0.0;
          ingresosPorActividad[act] = (ingresosPorActividad[act] ?? 0.0) + monto;
        }
        
        Map<String, double> gastosPorActividad = {};
        double gastosGenerales = 0.0;
        for (var g in gastosLista) {
          String act = g['actividad'] ?? '';
          double monto = double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0;
          if (act.isEmpty || act == 'Gasto General' || act == 'General') {
            gastosGenerales += monto;
          } else {
            gastosPorActividad[act] = (gastosPorActividad[act] ?? 0.0) + monto;
          }
        }
        
        // Agrupar filas
        List<List<String>> rows = [];
        
        // Fila 1: Donaciones / Extras
        double utilidadExtras = totalExtras - 0.0;
        rows.add([
          'DONACIONES / EXTRAS',
          fmtMoney(totalExtras),
          fmtMoney(0.0),
          fmtMoney(utilidadExtras)
        ]);
        
        double sumaIngresos = totalExtras;
        double sumaGastos = 0.0;
        
        // Filas de actividades
        for (var act in actividadesLista) {
          String titulo = act['titulo'] ?? '';
          double ing = ingresosPorActividad[titulo] ?? 0.0;
          double gas = gastosPorActividad[titulo] ?? 0.0;
          double util = ing - gas;
          
          rows.add([
            titulo,
            fmtMoney(ing),
            fmtMoney(gas),
            fmtMoney(util)
          ]);
          
          sumaIngresos += ing;
          sumaGastos += gas;
        }
        
        // Fila Gasto General
        if (gastosGenerales > 0) {
          rows.add([
            'Gasto General',
            fmtMoney(0.0),
            fmtMoney(gastosGenerales),
            fmtMoney(-gastosGenerales)
          ]);
          sumaGastos += gastosGenerales;
        }
        
        // Fila de Total
        double utilidadTotal = sumaIngresos - sumaGastos;
        
        // Convertir a tabla de PDF
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Actividad / Concepto', 'Ingresos (S/)', 'Gastos (S/)', 'Utilidad / Pérdida (S/)'],
            data: rows,
            headerStyle: headerStyle,
            headerDecoration: tableHeaderDecoration,
            cellStyle: dataStyle,
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(3.2),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(2.0),
            },
          ),
        );
        
        widgets.add(pw.SizedBox(height: 12));
        
        // Mostrar resumen de totales
        widgets.add(
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColor.fromHex('#ECEFF1'),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Ingresos:', style: dataStyle),
                      pw.Text(fmtMoney(sumaIngresos), style: dataStyleBold),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Gastos:', style: dataStyle),
                      pw.Text(fmtMoney(sumaGastos), style: dataStyleBold),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Utilidad General:', style: dataStyleBold),
                      pw.Text(
                        fmtMoney(utilidadTotal),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: utilidadTotal >= 0 ? PdfColor.fromHex('#2E7D32') : PdfColor.fromHex('#C62828'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        
        return widgets;
      }

      // 2. Estado de Alumnos (Deudores) Widget
      List<pw.Widget> buildAlumnosWidgets() {
        double totalPagado = 0;
        double totalDeuda = 0;

        for (var row in deudoresLista) {
          double tp = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
          double tpagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
          totalPagado += tpagado;
          totalDeuda += (tp - tpagado);
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Estado Financiero de Alumnos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        const int filasPorHoja = 20;
        int index = 1;

        for (var i = 0; i < deudoresLista.length; i += filasPorHoja) {
          final chunk = deudoresLista.sublist(i, i + filasPorHoja > deudoresLista.length ? deudoresLista.length : i + filasPorHoja);

          widgets.add(
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
                ...chunk.map((row) {
                  double tp = double.tryParse(row['total_a_pagar']?.toString() ?? '0') ?? 0.0;
                  double tpagado = double.tryParse(row['total_pagado']?.toString() ?? '0') ?? 0.0;
                  double deuda = tp - tpagado;
                  
                  final isCebra = index % 2 == 0;
                  final cellDecor = pw.BoxDecoration(color: isCebra ? PdfColor.fromHex('#F8F9FA') : PdfColors.white);
                  final isDeudor = deuda > 0;

                  return pw.TableRow(
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
                }),
              ],
            )
          );

          if (i + filasPorHoja < deudoresLista.length) {
            widgets.add(pw.NewPage());
          }
        }

        // Totales al final
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
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
            ]
          )
        );
        widgets.add(pw.SizedBox(height: 20));
        return widgets;
      }

      // 3. Historial de Pagos Widget
      List<pw.Widget> buildPagosWidgets() {
        double totalMonto = 0;
        double totalMora = 0;

        for (var row in pagosLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
          totalMora += double.tryParse(row['monto_multa']?.toString() ?? '0') ?? 0.0;
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Historial General de Pagos Recibidos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        const int filasPorHoja = 20;
        int index = 1;

        for (var i = 0; i < pagosLista.length; i += filasPorHoja) {
          final chunk = pagosLista.sublist(i, i + filasPorHoja > pagosLista.length ? pagosLista.length : i + filasPorHoja);

          widgets.add(
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
                ...chunk.map((row) {
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
                }),
              ],
            )
          );

          if (i + filasPorHoja < pagosLista.length) {
            widgets.add(pw.NewPage());
          }
        }

        // Totales al final
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
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
            ]
          )
        );
        widgets.add(pw.SizedBox(height: 20));
        return widgets;
      }

      // 4. Historial de Gastos Widget
      List<pw.Widget> buildGastosWidgets() {
        double totalMonto = 0;
        for (var row in gastosLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Historial General de Egresos (Gastos)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        const int filasPorHoja = 20;
        int index = 1;

        for (var i = 0; i < gastosLista.length; i += filasPorHoja) {
          final chunk = gastosLista.sublist(i, i + filasPorHoja > gastosLista.length ? gastosLista.length : i + filasPorHoja);

          widgets.add(
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
                ...chunk.map((row) {
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
                }),
              ],
            )
          );

          if (i + filasPorHoja < gastosLista.length) {
            widgets.add(pw.NewPage());
          }
        }

        // Totales al final
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
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
            ]
          )
        );
        widgets.add(pw.SizedBox(height: 20));
        return widgets;
      }

      // 5. Ingresos Extra Widget
      List<pw.Widget> buildExtrasWidgets() {
        double totalMonto = 0;
        for (var row in extrasLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Detalle de Ingresos Extras y Donaciones', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        const int filasPorHoja = 20;
        int index = 1;

        for (var i = 0; i < extrasLista.length; i += filasPorHoja) {
          final chunk = extrasLista.sublist(i, i + filasPorHoja > extrasLista.length ? extrasLista.length : i + filasPorHoja);

          widgets.add(
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
                ...chunk.map((row) {
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
                }),
              ],
            )
          );

          if (i + filasPorHoja < extrasLista.length) {
            widgets.add(pw.NewPage());
          }
        }

        // Totales al final
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
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
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL INGRESOS EXTRA', style: dataStyleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                ],
              ),
            ]
          )
        );
        widgets.add(pw.SizedBox(height: 20));
        return widgets;
      }

      // 6. Detalle Apertura (Fondo Base) Widget
      List<pw.Widget> buildFondoWidgets() {
        double totalMonto = 0;
        for (var row in fondoLista) {
          totalMonto += double.tryParse(row['monto']?.toString() ?? '0') ?? 0.0;
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Fondo Inicial de Apertura', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        const int filasPorHoja = 20;
        int index = 1;

        for (var i = 0; i < fondoLista.length; i += filasPorHoja) {
          final chunk = fondoLista.sublist(i, i + filasPorHoja > fondoLista.length ? fondoLista.length : i + filasPorHoja);

          widgets.add(
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
                ...chunk.map((row) {
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
                }),
              ],
            )
          );

          if (i + filasPorHoja < fondoLista.length) {
            widgets.add(pw.NewPage());
          }
        }

        // Totales al final
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
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
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECEFF1')),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(fmtMoney(totalMonto), style: dataStyleBold, textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL FONDOS BASE', style: dataStyleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                ],
              ),
            ]
          )
        );
        widgets.add(pw.SizedBox(height: 20));
        return widgets;
      }

      // 7. Cuadro General de Pagos (Matriz) Widget
      List<pw.Widget> buildCuadroGeneralWidgets() {
        // Agrupar los pagos por alumno y actividad
        Map<String, double> mapaPagos = {};
        for (var pago in pagosLista) {
          String alumno = pago['alumno']?.toString() ?? '';
          String actividad = pago['actividad']?.toString() ?? '';
          double monto = double.tryParse(pago['monto']?.toString() ?? '0') ?? 0.0;
          
          String key = '${alumno}_$actividad';
          mapaPagos[key] = (mapaPagos[key] ?? 0.0) + monto;
        }

        List<pw.Widget> widgets = [];
        widgets.add(pw.Text('Cuadro General de Pagos (Matriz de Actividades)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557'))));
        widgets.add(pw.SizedBox(height: 8));

        List<List<String>> rows = [];
        
        // Cabecera
        List<String> headers = ['N°', 'Nombres y Apellidos'];
        for (var act in actividadesLista) {
          String titulo = act['titulo']?.toString() ?? '';
          // Reemplazar espacios por saltos de línea para apilar verticalmente
          titulo = titulo.trim().replaceAll(RegExp(r'\s+'), '\n');
          headers.add(titulo);
        }
        headers.add('Total\nGeneral');
        rows.add(headers);

        int correlativo = 1;
        List<double> totalesColumnasActividades = List.filled(actividadesLista.length, 0.0);
        double totalGeneralTodosAlumnos = 0.0;

        for (var user in deudoresLista) {
          String nombreAlumno = user['nombre']?.toString() ?? '';
          List<String> row = [
            (correlativo++).toString(),
            nombreAlumno,
          ];
          
          double totalPagadoPorAlumno = 0.0;
          
          for (int i = 0; i < actividadesLista.length; i++) {
            var act = actividadesLista[i];
            String tituloAct = act['titulo']?.toString() ?? '';
            
            String key = '${nombreAlumno}_$tituloAct';
            double montoPagado = mapaPagos[key] ?? 0.0;
            
            totalPagadoPorAlumno += montoPagado;
            totalesColumnasActividades[i] += montoPagado;
            
            row.add(montoPagado > 0 ? montoPagado.toStringAsFixed(0) : '-');
          }
          
          totalGeneralTodosAlumnos += totalPagadoPorAlumno;
          row.add(totalPagadoPorAlumno.toStringAsFixed(0));
          rows.add(row);
        }

        // Fila de Totales de Columnas al final
        List<String> footer = [
          '',
          'Total',
        ];
        for (double totAct in totalesColumnasActividades) {
          footer.add(totAct.toStringAsFixed(0));
        }
        footer.add(totalGeneralTodosAlumnos.toStringAsFixed(0));
        rows.add(footer);

        // Configurar anchos de columna dinámicos fijos para que la tabla sea compacta y se "pegue" a la izquierda
        Map<int, pw.TableColumnWidth> colWidths = {
          0: const pw.FixedColumnWidth(18), // N°
          1: const pw.FixedColumnWidth(160), // Nombres y Apellidos (ancho fijo y suficiente)
        };
        for (int i = 0; i < actividadesLista.length; i++) {
          colWidths[i + 2] = const pw.FixedColumnWidth(38); // Columnas estrechas para actividades
        }
        colWidths[actividadesLista.length + 2] = const pw.FixedColumnWidth(38); // Total

        widgets.add(
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.TableHelper.fromTextArray(
              headers: rows[0],
              data: rows.sublist(1),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: colWidths,
              headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: tableHeaderDecoration,
              cellStyle: const pw.TextStyle(fontSize: 6.5, color: PdfColors.black),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
              },
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8F9FA'),
              ),
              headerAlignment: pw.Alignment.center,
              headerAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
              },
            ),
          ),
        );

        return widgets;
      }

      // ------------------------------------------------------------------------
      // ASOCIACIÓN DE COMPONENTES A PÁGINAS DEL PDF SEGÚN OPCIÓN
      // ------------------------------------------------------------------------

      if (opcion == 0) {
        // CIERRE CONTABLE COMPLETO (PÁGINAS INDEPENDIENTES PARA CADA SECCIÓN)
        
        // Página 1: Resumen General
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => buildHeader('Cierre Contable Consolidado Completo - Resumen'),
            footer: (context) => buildFooter(context),
            build: (context) => [
              ...buildResumenWidgets(),
            ],
          ),
        );

        // Página 1.2: Resumen por Actividades
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => buildHeader('Cierre Contable Completo - Resumen por Actividades'),
            footer: (context) => buildFooter(context),
            build: (context) => [
              ...buildResumenActividadesWidgets(),
            ],
          ),
        );

        // Página 2: Estado de Alumnos (Deudores)
        if (deudoresLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Estado de Alumnos'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildAlumnosWidgets(),
              ],
            ),
          );
        }

        // Página: Cuadro General de Pagos (Landscape)
        if (deudoresLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Cuadro General de Pagos'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildCuadroGeneralWidgets(),
              ],
            ),
          );
        }

        // Página 3: Historial de Pagos
        if (pagosLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Historial de Pagos'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildPagosWidgets(),
              ],
            ),
          );
        }

        // Página 4: Historial de Gastos
        if (gastosLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Historial de Gastos'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildGastosWidgets(),
              ],
            ),
          );
        }

        // Página 5: Ingresos Extra
        if (extrasLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Ingresos Extras'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildExtrasWidgets(),
              ],
            ),
          );
        }

        // Página 6: Fondo Inicial de Apertura
        if (fondoLista.isNotEmpty) {
          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              header: (context) => buildHeader('Cierre Contable Completo - Fondo Inicial de Apertura'),
              footer: (context) => buildFooter(context),
              build: (context) => [
                ...buildFondoWidgets(),
              ],
            ),
          );
        }
      } else {
        // REPORTES INDIVIDUALES
        String label = 'Reporte Financiero';
        List<pw.Widget> Function() widgetBuilder;

        switch (opcion) {
          case 1:
            label = 'Resumen de Caja General';
            widgetBuilder = () => buildResumenWidgets();
            break;
          case 2:
            label = 'Estado General de Alumnos';
            widgetBuilder = () => buildAlumnosWidgets();
            break;
          case 3:
            label = 'Historial General de Pagos';
            widgetBuilder = () => buildPagosWidgets();
            break;
          case 4:
            label = 'Historial General de Gastos (Egresos)';
            widgetBuilder = () => buildGastosWidgets();
            break;
          case 5:
            label = 'Detalle de Ingresos Extras y Donaciones';
            widgetBuilder = () => buildExtrasWidgets();
            break;
          case 6:
            label = 'Historial de Fondo Inicial de Apertura';
            widgetBuilder = () => buildFondoWidgets();
            break;
          case 7:
            label = 'Cuadro General de Pagos';
            widgetBuilder = () => buildCuadroGeneralWidgets();
            break;
          case 8:
            label = 'Resumen por Actividades';
            widgetBuilder = () => buildResumenActividadesWidgets();
            break;
          default:
            throw Exception('Opción no configurada para PDF');
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: opcion == 7 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => buildHeader(label),
            footer: (context) => buildFooter(context),
            build: (context) => [
              ...widgetBuilder(),
            ],
          ),
        );
      }

      // Convertir el documento a bytes
      final Uint8List pdfBytes = await pdf.save();
      return pdfBytes;
    } catch (e) {
      debugPrint('Error exportando reporte a PDF: $e');
      return null;
    }
  }

  /// Mantiene compatibilidad con el código anterior de descarga directa
  static Future<bool> exportarYCompartir(int opcion) async {
    final pdfBytes = await generarPdfBytes(opcion);
    if (pdfBytes == null) return false;

    String nomArchivo = 'Reporte_Insoft_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: nomArchivo,
    );
    return true;
  }
}
