import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/c_formatos.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/k_servicio_auditoria.dart';
import '../myPagesBack/g_servicio_excel.dart';


class ReportesAvanzados extends StatefulWidget {
  const ReportesAvanzados({super.key});

  @override
  State<ReportesAvanzados> createState() => _ReportesAvanzadosState();
}

class _ReportesAvanzadosState extends State<ReportesAvanzados> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1), 
    end: DateTime.now()
  );
  
  Map<String, dynamic> _datosReporte = {};
  late Future<void> _futureReporte;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _futureReporte = Future.delayed(Duration.zero, _cargarReporte);
  }

  Future<void> _cargarReporte() async {
    final datos = await context.read<ControladorFinanzas>()
        .obtenerReporteAvanzado(_rangoFechas.start, _rangoFechas.end);
    
    if (mounted) {
      _datosReporte = datos;
    }
  }

  Future<void> _seleccionarFechas() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).colorScheme.secondary;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _rangoFechas,
      saveText: 'FILTRAR',
      helpText: 'SELECCIONAR PERIODO',
      locale: const Locale('es', 'PE'), // Forzar español
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    secondary: accentColor,
                    onSecondary: Colors.black,
                    surface: const Color(0xFF1E293B), // superficieOscura
                    onSurface: Colors.white,
                    surfaceContainer: const Color(0xFF0F172A),
                    surfaceContainerHighest: const Color(0xFF334155),
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    secondary: accentColor,
                    onSecondary: Colors.white,
                    surface: Colors.white,
                    onSurface: primaryColor,
                    surfaceContainer: const Color(0xFFF1F5F9),
                    surfaceContainerHighest: primaryColor.withValues(alpha: 0.08),
                  ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              headerBackgroundColor: primaryColor,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
              headerHelpStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white70,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white70 : Colors.black87;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
              rangeSelectionBackgroundColor: primaryColor.withValues(alpha: 0.15),
              rangeSelectionOverlayColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : primaryColor, 
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            textTheme: TextTheme(
              headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: isDark ? Colors.white : primaryColor),
              titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : primaryColor),
              bodyLarge: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54), // Días de la semana
              bodyMedium: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87), // Días del mes
              bodySmall: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black54), // Otros textos
            ),
          ),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Bordes redondeados
            clipBehavior: Clip.antiAlias, // Recorta el contenido a los bordes
            elevation: 8,
            child: SizedBox(
              width: 440, // Más ancho para evitar que se vea apretado
              height: 580, // Más alto para que respire mejor
              child: child,
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _rangoFechas) {
      setState(() {
        _rangoFechas = picked;
        _futureReporte = _cargarReporte();
      });
    }
  }

  Future<void> _exportarActividadesPDF() async {
    setState(() => _exportando = true);
    try {
      // Cargar fuentes compatibles con Unicode para evitar errores de acentos/ñ
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();
      
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );

      final DateFormat formatter = DateFormat('dd/MM/yyyy');
      final String periodoStr = '${formatter.format(_rangoFechas.start)} al ${formatter.format(_rangoFechas.end)}';
      final String timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final titleStyle = pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#1D3557'),
      );
      final subtitleStyle = const pw.TextStyle(
        fontSize: 10,
        color: PdfColors.grey700,
      );
      final headerStyle = pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final dataStyle = const pw.TextStyle(
        fontSize: 9,
        color: PdfColors.black,
      );
      final dataStyleBold = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      final listado = _datosReporte['desglose'] as List<dynamic>? ?? [];
      
      double totalIngresos = 0.0;
      double totalGastos = 0.0;
      double totalUtilidad = 0.0;
      
      for (var item in listado) {
        totalIngresos += (item['ingresos'] as num? ?? 0).toDouble();
        totalGastos += (item['gastos'] as num? ?? 0).toDouble();
        totalUtilidad += (item['utilidad'] as num? ?? 0).toDouble();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
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
                      pw.Text('Reporte de Actividades', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#457B9D'))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1D3557')),
              pw.SizedBox(height: 12),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generado automáticamente por InSOFT', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.Text(
              'REPORTE DE BALANCE POR ACTIVIDADES',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D3557')),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Periodo Seleccionado: $periodoStr',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1D3557'),
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('Actividad / Concepto', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('Ingresos', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('Gastos', style: headerStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('Utilidad/Pérdida', style: headerStyle, textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...listado.map((item) {
                  final ing = (item['ingresos'] as num? ?? 0).toDouble();
                  final gas = (item['gastos'] as num? ?? 0).toDouble();
                  final util = (item['utilidad'] as num? ?? 0).toDouble();
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text(item['titulo']?.toString() ?? '', style: dataStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('S/ ${ing.toStringAsFixed(2)}', style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('S/ ${gas.toStringAsFixed(2)}', style: dataStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: pw.Text(
                          'S/ ${util.toStringAsFixed(2)}', 
                          style: pw.TextStyle(
                            fontSize: 9, 
                            fontWeight: pw.FontWeight.bold,
                            color: util >= 0 ? PdfColors.green700 : PdfColors.red700,
                          ),
                          textAlign: pw.TextAlign.right
                        )
                      ),
                    ],
                  );
                }),
                // Fila de Total
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#ECEFF1'),
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('TOTAL GENERAL', style: dataStyleBold)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('S/ ${totalIngresos.toStringAsFixed(2)}', style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8), child: pw.Text('S/ ${totalGastos.toStringAsFixed(2)}', style: dataStyleBold, textAlign: pw.TextAlign.right)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: pw.Text(
                        'S/ ${totalUtilidad.toStringAsFixed(2)}', 
                        style: pw.TextStyle(
                          fontSize: 9, 
                          fontWeight: pw.FontWeight.bold,
                          color: totalUtilidad >= 0 ? PdfColors.green700 : PdfColors.red700,
                        ),
                        textAlign: pw.TextAlign.right
                      )
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      final String filename = 'Reporte_Actividades_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    } catch (e) {
      debugPrint('Error exportando PDF de actividades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: ColoresApp.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _ejecutarDescargaExcel() async {
    setState(() => _exportando = true);
    try {
      final exito = await ServicioExcel.exportarYCompartir();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exito ? 'Excel compartido con éxito' : 'Error al generar Excel'),
            backgroundColor: exito ? ColoresApp.exito : ColoresApp.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exportando Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar Excel: $e'),
            backgroundColor: ColoresApp.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  void _mostrarOpcionesExportacion(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportar Reportes',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona el formato en el que deseas exportar los datos contables.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                  ),
                  title: Text(
                    'Reporte PDF de Actividades',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Tabla de balance de todas las actividades filtradas.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _exportarActividadesPDF();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_view_rounded, color: Colors.green),
                  ),
                  title: Text(
                    'Libro de Excel Consolidado',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Incluye matriz de pagos y resumen de actividades.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _ejecutarDescargaExcel();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Balance por Fechas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_exportando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Exportar Reportes',
              onPressed: () => _mostrarOpcionesExportacion(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Balance General'),
            Tab(text: 'Por Actividad'),
          ],
        ),
      ),
      body: Column(
        children: [
          // FILTRO DE FECHAS PREMIUM
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _seleccionarFechas,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Theme.of(context).primaryColor.withValues(alpha: 0.2)),
                      boxShadow: isDark ? [] : AppTokens.sombraSuave,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // Que el botón abrace su contenido
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 20, color: isDark ? Colors.white : Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          '${_rangoFechas.start.toFechaUsuario()}  →  ${_rangoFechas.end.toFechaUsuario()}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Theme.of(context).primaryColor),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.unfold_more_rounded, size: 20, color: isDark ? Colors.white70 : Theme.of(context).primaryColor.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO
          Expanded(
            child: FutureBuilder<void>(
              future: _futureReporte,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TabBarView(
                  controller: _tabController,
                  children: [
                    KeepAliveWrapper(child: _construirBalanceGeneral()),
                    KeepAliveWrapper(child: _construirDesgloseActividad()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBalanceGeneral() {
    if (_datosReporte.isEmpty) return const SizedBox();

    final double ingresos = (_datosReporte['totalIngresos'] as num?)?.toDouble() ?? 0.0;
    final double gastos = (_datosReporte['totalGastos'] as num?)?.toDouble() ?? 0.0;
    final double utilidad = (_datosReporte['utilidadNeta'] as num?)?.toDouble() ?? 0.0;
    
    // Cálculo simple para gráfica de barras
    final double maxVal = ingresos > gastos ? ingresos : gastos;
    final double scale = maxVal > 0 ? maxVal : 1;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Resumen del Periodo',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: isDark ? Colors.white : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        
        // GRÁFICO DE BARRAS 3D PREMIUM (CILINDROS)
        RepaintBoundary(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _barra3D('Ingresos', ingresos, ColoresApp.exito, ingresos / scale),
              _barra3D('Gastos', gastos, ColoresApp.error, gastos / scale),
            ],
          ),
        ),
        
        const SizedBox(height: 40),

        // TARJETAS DE RESULTADOS
        _cardResultado('Total Recaudado', ingresos, ColoresApp.exito, Icons.arrow_upward),
        const SizedBox(height: 16),
        _cardResultado('Total Gastado', gastos, ColoresApp.error, Icons.arrow_downward),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        _cardResultado('Utilidad Neta', utilidad, utilidad >= 0 ? Theme.of(context).primaryColor : ColoresApp.estadoPendiente, Icons.account_balance_wallet, destacado: true),
        
        const SizedBox(height: 32),
        Text(
          'Recaudado por Administrador',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...(_datosReporte['recaudacionAdmins'] as List<dynamic>? ?? []).map((admin) {
          final nombre = admin['admin_nombre'].toString();
          final total = (admin['total'] as num).toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
              boxShadow: isDark ? [] : AppTokens.sombraSuave,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      nombre,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
                Text(total.toSoles(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : ColoresApp.exito)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _barra3D(String label, double monto, Color color, double porcentajeHeight) {
    final double baseHeight = 180.0;
    final double barHeight = baseHeight * porcentajeHeight;
    final double width = 50.0;
    final double capHeight = 12.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Etiqueta del monto
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            monto.toSoles(), 
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 13, 
              color: color
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Contenedor del gráfico 3D
        SizedBox(
          width: width + 20,
          height: baseHeight + capHeight + 10,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Sombra en la base de la barra
              Positioned(
                bottom: 4,
                child: Container(
                  width: width + 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(width + 8, 8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              ),
              if (barHeight > 0) ...[
                // Cuerpo de la barra 3D (Cilindro)
                Positioned(
                  bottom: 8,
                  child: SizedBox(
                    width: width,
                    height: barHeight + (capHeight / 2),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // El cuerpo principal del cilindro
                        Container(
                          width: width,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.9), // Lado brillante
                                color.withValues(alpha: 0.75),
                                color.withValues(alpha: 0.5),  // Lado sombreado
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.elliptical(width / 2, capHeight / 2),
                            ),
                          ),
                        ),
                        // El cap superior (tapa del cilindro)
                        Positioned(
                          top: -(capHeight / 2),
                          child: Container(
                            width: width,
                            height: capHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.4),
                                  color.withValues(alpha: 0.95),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(width / 2, capHeight / 2),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label, 
          style: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87, 
            fontWeight: FontWeight.bold, 
            fontSize: 13
          )
        ),
      ],
    );
  }

  Widget _cardResultado(String label, double monto, Color color, IconData icon, {bool destacado = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: destacado 
            ? color.withValues(alpha: isDark ? 0.15 : 0.1) 
            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: destacado 
              ? color.withValues(alpha: 0.4) 
              : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05))
        ),
        boxShadow: isDark ? [] : AppTokens.sombraSuave,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                label, 
                style: GoogleFonts.inter(
                  fontSize: 15, 
                  fontWeight: FontWeight.w600, 
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
            ],
          ),
          Text(
            monto.toSoles(), 
            style: GoogleFonts.outfit(
              fontSize: 20, 
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5
            )
          ),
        ],
      ),
    );
  }

  Widget _construirDesgloseActividad() {
    final listado = _datosReporte['desglose'] as List<dynamic>? ?? [];

    if (_datosReporte.containsKey('error')) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(24.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.error_outline, size: 48, color: ColoresApp.error),
               const SizedBox(height: 16),
               Text(
                 "Error obteniendo datos:\n${_datosReporte['error']}",
                 textAlign: TextAlign.center,
                 style: const TextStyle(color: ColoresApp.error),
               ),
             ],
           ),
         ),
       );
    }
    
    if (listado.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No hay datos en este rango'),
          ]
        ),

      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listado.length,
      itemBuilder: (context, index) {
        final item = listado[index];
        final util = (item['utilidad'] as num? ?? 0).toDouble();
        final ingresos = (item['ingresos'] as num? ?? 0).toDouble();
        final gastos = (item['gastos'] as num? ?? 0).toDouble();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
            boxShadow: isDark ? [] : AppTokens.sombraSuave,
          ),
          child: ExpansionTile(
            collapsedIconColor: isDark ? Colors.white : Colors.black87,
            iconColor: isDark ? Colors.white : Theme.of(context).primaryColor,
            shape: const Border(), // Remueve las líneas superior e inferior feas de Material
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              item['titulo'], 
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, 
                fontSize: 17, 
                color: isDark ? Colors.white : Colors.black87
              )
            ),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                   color: (util >= 0 ? ColoresApp.exito : ColoresApp.error).withValues(alpha: 0.15),
                   borderRadius: BorderRadius.circular(12)
                ),
                child: Text(
                  util >= 0 ? 'Utilidad: ${util.toSoles()}' : 'Pérdida: ${util.toSoles()}',
                  style: GoogleFonts.inter(
                    color: util >= 0 ? (isDark ? Colors.greenAccent : ColoresApp.exito) : ColoresApp.error, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 13
                  ),
                ),
              ),
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _datoMini('Ingresos', ingresos, ColoresApp.exito, Icons.arrow_upward),
                    Container(
                      height: 40, 
                      width: 1, 
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)
                    ),
                    _datoMini('Gastos', gastos, ColoresApp.error, Icons.arrow_downward),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _datoMini(String label, double monto, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(monto.toSoles(), style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}

class AuditoriaAdmin extends StatefulWidget {
  const AuditoriaAdmin({super.key});

  @override
  State<AuditoriaAdmin> createState() => _AuditoriaAdminState();
}

class _AuditoriaAdminState extends State<AuditoriaAdmin> {
  late Future<List<Map<String, dynamic>>> _futureLogs;
  late Future<List<Map<String, dynamic>>> _futureCaja;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _cargarDatos() {
    if (mounted) {
      setState(() {
        _futureLogs = ServicioAuditoria().obtenerLogsAuditoria();
        _futureCaja = ServicioAuditoria().obtenerResumenCaja(DateTime.now());
      });
    }
  }

  Future<void> _confirmarVaciado(ControladorAuth auth) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ColoresApp.error, size: 28),
            const SizedBox(width: 10),
            Text('¿Vaciar historial?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Esta acción eliminará todos los registros de auditoría permanentemente. Solo quedará registro de este vaciado.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('VACIAR TODO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final id = auth.usuarioActual?.id ?? 0;
      final exito = await ServicioAuditoria().vaciarHistorial('SuperAdmin', id);
      
      if (!mounted) return;

      if (exito) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Historial de auditoría vaciado correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _cargarDatos();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Error al vaciar historial de auditoría.'), 
            backgroundColor: ColoresApp.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFilterChip(String type, IconData icon) {
    final isSelected = _filterType == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color activeColor;
    switch (type) {
      case 'Pagos':
        activeColor = ColoresApp.exito;
        break;
      case 'Gastos':
        activeColor = ColoresApp.error;
        break;
      case 'Cuentas':
        activeColor = Colors.orange;
        break;
      case 'Mantenimiento':
        activeColor = Colors.indigo;
        break;
      default:
        activeColor = theme.primaryColor;
    }

    return ChoiceChip(
      avatar: Icon(
        icon, 
        size: 16, 
        color: isSelected 
            ? Colors.white 
            : (isDark ? Colors.white70 : Colors.black54)
      ),
      label: Text(type),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _filterType = type);
        }
      },
      selectedColor: activeColor,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12.5,
        color: isSelected 
            ? Colors.white 
            : (isDark ? Colors.white70 : Colors.black87)
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? Colors.transparent 
              : (isDark ? Colors.white10 : Colors.grey.shade200)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    
    // PROTECCIÓN DE RUTA: Solo SuperAdmin
    if (auth.usuarioActual?.rol != 'SuperAdmin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(child: Text('No tienes permisos para ver esta sección.')),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Auditoría de Sistema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // BOTÓN VACIAR (Solo SuperAdmin)
          if (auth.usuarioActual?.rol == 'SuperAdmin')
            IconButton(
              tooltip: 'Vaciar Historial',
              icon: const Icon(Icons.delete_sweep_rounded, color: ColoresApp.error),
              onPressed: () => _confirmarVaciado(auth),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_futureCaja, _futureLogs]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Map<String, dynamic>> caja = (snapshot.data?[0] as List<Map<String, dynamic>>?) ?? [];
          final List<Map<String, dynamic>> logs = (snapshot.data?[1] as List<Map<String, dynamic>>?) ?? [];

          // Calcular totales
          double totalRecaudadoHoy = caja.fold(0.0, (sum, item) => sum + (item['total'] as double));
          int totalLogs = logs.length;

          // Filtrar logs en memoria
          final filteredLogs = logs.where((log) {
            final accion = log['accion'].toString().toLowerCase();
            final admin = log['admin'].toString().toLowerCase();
            final detalle = log['detalle'].toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            
            final matchesSearch = query.isEmpty || 
                accion.contains(query) || 
                admin.contains(query) || 
                detalle.contains(query);
                
            if (!matchesSearch) return false;
            
            if (_filterType == 'Todos') return true;
            if (_filterType == 'Pagos') return log['accion'].toString().contains('Pago');
            if (_filterType == 'Gastos') return log['accion'].toString().contains('Gasto');
            if (_filterType == 'Cuentas') return log['accion'].toString().contains('Usuario') || log['accion'].toString().contains('Rol');
            if (_filterType == 'Mantenimiento') {
              final a = log['accion'].toString();
              return !a.contains('Pago') && !a.contains('Gasto') && !a.contains('Usuario') && !a.contains('Rol');
            }
            
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TARJETAS DE ESTADÍSTICAS RÁPIDAS
                Row(
                  children: [
                    Expanded(
                      child: TarjetaPremium(
                        esBordeBrillante: false,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ColoresApp.exito.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.monetization_on_rounded, color: ColoresApp.exito, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recaudado Hoy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    totalRecaudadoHoy.toSoles(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TarjetaPremium(
                        esBordeBrillante: false,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_toggle_off_rounded, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logs Totales',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    totalLogs.toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. SECCIÓN CORTE DE CAJA (Hoy)
                Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Corte de Caja (Hoy)', 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : Theme.of(context).primaryColor
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                if (caja.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No hay cobros registrados hoy.', 
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)
                    ),
                  )
                else
                  TarjetaPremium(
                    esBordeBrillante: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...caja.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              AvatarUsuario(
                                nombre: item['admin'],
                                radius: 16,
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                textColor: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['admin'], 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white : Colors.black87
                                      )
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Administrador', 
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: isDark ? Colors.white60 : Colors.black54
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                (item['total'] as double).toSoles(), 
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : Colors.black87
                                )
                              ),
                            ],
                          ),
                        )),
                        const Divider(),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL DEL DÍA', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : ColoresApp.exito, fontSize: 13)
                            ),
                            BadgeEstado(
                              texto: totalRecaudadoHoy.toSoles(),
                              colorBase: isDark ? Colors.greenAccent : ColoresApp.exito,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // 3. SECCIÓN HISTORIAL
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Historial de Acciones', 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : Theme.of(context).primaryColor
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // BUSCADOR EN TIEMPO REAL
                TextFormField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar logs por acción, admin o detalle...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CHIPS DE FILTRADO
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', Icons.list_alt_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pagos', Icons.payments_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('Gastos', Icons.money_off_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('Cuentas', Icons.manage_accounts_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('Mantenimiento', Icons.settings_suggest_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // LISTA DE LOGS FILTRADOS
                if (filteredLogs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron coincidencias.',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return _TarjetaLog(log: log, dateFormat: dateFormat);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaLog extends StatelessWidget {
  final Map<String, dynamic> log;
  final DateFormat dateFormat;

  const _TarjetaLog({required this.log, required this.dateFormat});

  void _mostrarDetalleLog(BuildContext context, Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color activeColor;
    IconData iconData;
    final a = log['accion'].toString();
    if (a.contains('Pago')) {
      activeColor = isDark ? Colors.greenAccent : ColoresApp.exito;
      iconData = Icons.payments;
    } else if (a.contains('Gasto')) {
      activeColor = ColoresApp.error;
      iconData = Icons.money_off;
    } else if (a.contains('Usuario') || a.contains('Rol')) {
      activeColor = Colors.orange;
      iconData = Icons.manage_accounts;
    } else {
      activeColor = Colors.indigo;
      iconData = Icons.settings_suggest_rounded;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: activeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                log['accion'],
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detalleFila(Icons.person_outline_rounded, 'Ejecutor', '${log['admin']} (${log['rol']})'),
              const SizedBox(height: 10),
              _detalleFila(Icons.calendar_today_rounded, 'Fecha y Hora', dateFormat.format(log['fecha'])),
              const SizedBox(height: 10),
              _detalleFila(Icons.devices_rounded, 'Dispositivo', log['dispositivo']),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Descripción Detallada:',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: SelectableText(
                  log['detalle'],
                  style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log['detalle']));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copiado al portapapeles'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('COPIAR DETALLE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CERRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detalleFila(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accion = log['accion'];
    final admin = log['admin'];
    final fecha = log['fecha'];
    final dispositivo = log['dispositivo'];
    final detalle = log['detalle'];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icono;
    Color color;

    if (accion.contains('Pago')) {
      icono = Icons.payments;
      color = isDark ? Colors.greenAccent : ColoresApp.exito;
    } else if (accion.contains('Gasto')) {
      icono = Icons.money_off;
      color = ColoresApp.error;
    } else if (accion.contains('Usuario') || accion.contains('Rol')) {
      icono = Icons.manage_accounts;
      color = Colors.orange;
    } else {
      icono = Icons.info;
      color = Colors.grey;
    }

    IconData dispositivoIcono;
    if (dispositivo.toLowerCase().contains('celular') || dispositivo.toLowerCase().contains('móvil') || dispositivo.toLowerCase().contains('android') || dispositivo.toLowerCase().contains('ios')) {
      dispositivoIcono = Icons.phone_android_rounded;
    } else {
      dispositivoIcono = Icons.computer_rounded;
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TarjetaPremium(
          leftAccentColor: color,
          padding: const EdgeInsets.all(14),
          onTap: () => _mostrarDetalleLog(context, log),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(icono, color: color, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accion,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              admin,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('•', style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26)),
                            const SizedBox(width: 4),
                            Icon(dispositivoIcono, size: 11, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                dispositivo,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateFormat.format(fecha),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
