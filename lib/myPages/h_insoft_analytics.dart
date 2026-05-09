import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../services/api_client.dart' as api_ext;
import '../myPagesTema/b_ui_kit.dart';

class InsoftAnalyticsDemo extends StatefulWidget {
  const InsoftAnalyticsDemo({super.key});

  @override
  State<InsoftAnalyticsDemo> createState() => _InsoftAnalyticsDemoState();
}

class _InsoftAnalyticsDemoState extends State<InsoftAnalyticsDemo> {
  String _anioSeleccionado = '2026';
  String _mesSeleccionado = 'TODOS';
  String _estadoSeleccionado = 'TODOS';
  String _tipoReporteSeleccionado = 'DEUDAS';

  bool _cargando = true;
  bool _exportando = false; 
  Map<String, dynamic>? _datosAnaliticos;

  final List<String> _meses = [
    'TODOS', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final api = api_ext.ApiClient();
      final data = await api.post('obtenerDashboardAnalytics', {
        'anio': _anioSeleccionado,
        'mes': _mesSeleccionado,
        'estado': _estadoSeleccionado,
      });

      if (data['ok'] == true) {
        setState(() {
          _datosAnaliticos = data;
        });
      } else {
        _mostrarError(data['msj'] ?? 'Error desconocido');
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msj) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msj),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed, // Evita el conflicto con los FABs apilados
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEscritorio = MediaQuery.of(context).size.width > 800;

    final contenidoTabs = _cargando 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : (_datosAnaliticos == null 
            ? const Center(child: Text('Error al cargar datos'))
            : Column(
                children: [
                  if (!esEscritorio) _buildFiltrosMovil(),
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const TabBar(
                      labelColor: Color(0xFF1D3557),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Métricas y Gráficos'),
                        Tab(text: 'Detalle de Usuarios'),
                        Tab(text: 'Alertas Cruzadas'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: TabBarView(
                        children: [
                          _buildGraficosYMetas(),
                          _buildTablaDatosPremium(),
                          _buildMapaPlaceholder(),
                        ],
                      ),
                    ),
                  ),
                ],
              ));

    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1D3557),
          title: const Text('Dashboard Ejecutivo - Tesorería', style: TextStyle(color: Colors.white, fontSize: 18)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarDatos),
          ],
        ),
        body: esEscritorio
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBarraLateral(),
                  Expanded(child: contenidoTabs),
                ],
              )
            : contenidoTabs,
        floatingActionButton: _cargando ? null : Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'btnExcel',
              onPressed: _exportando ? null : _exportarExcel,
              backgroundColor: _exportando ? Colors.grey : Colors.green.shade700,
              child: _exportando ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.table_view, color: Colors.white),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'btnPdf',
              onPressed: _exportando ? null : _exportarPDF,
              backgroundColor: _exportando ? Colors.grey : Colors.teal,
              icon: _exportando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('PDF', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES UI: GRÁFICOS Y METAS ---
  Widget _buildGraficosYMetas() {
    final kpis = _datosAnaliticos!['kpis'];
    final double progreso = (kpis['progreso'] as num).toDouble();
    final double meta = (kpis['meta'] as num).toDouble();
    final double ingresos = (kpis['ingresos'] as num).toDouble();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Meta Mensual (Progress Bar)
          TarjetaPremium(
            usaGradientePrimario: false,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meta de Recaudación (Deuda Total Estudiantil)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D3557))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('S/ ${ingresos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Text('de S/ ${meta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progreso > 1.0 ? 1.0 : progreso,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(progreso * 100).toStringAsFixed(1)}% Alcanzado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progreso >= 1.0 ? Colors.green : Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 2. Gráficos: Tendencias y Composición (Uno debajo del otro para mejor legibilidad en móvil)
          _buildGraficoTendencias(),
          const SizedBox(height: 16),
          _buildGraficoAnillo(),
        ],
      ),
    );
  }

  Widget _buildGraficoAnillo() {
    final dona = _datosAnaliticos!['dona'] as List;
    final valRecaudado = (dona[0]['valor'] as num).toDouble();
    final valDeuda = (dona[1]['valor'] as num).toDouble();
    
    return TarjetaPremium(
      usaGradientePrimario: false,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text('Composición Global', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D3557))),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.teal,
                    value: valRecaudado,
                    title: '${((valRecaudado/(valRecaudado+valDeuda+0.001))*100).toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: const Color(0xFFE63946),
                    value: valDeuda,
                    title: '${((valDeuda/(valRecaudado+valDeuda+0.001))*100).toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ]
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.circle, color: Colors.teal, size: 12),
              const SizedBox(width: 4),
              Flexible(child: Text('Recaudado (S/ ${valRecaudado.toStringAsFixed(0)})', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.circle, color: Color(0xFFE63946), size: 12),
              const SizedBox(width: 4),
              Flexible(child: Text('Deuda (S/ ${valDeuda.toStringAsFixed(0)})', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET: TABLA DE DATOS PREMIUM CON BOTTOM SHEET ---
  Widget _buildTablaDatosPremium() {
    final List usuarios = _datosAnaliticos!['usuarios'];

    return TarjetaPremium(
      usaGradientePrimario: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Detalle de Usuarios (Toca para ver info)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              itemExtent: 85, // Optimización: Bloquea las alturas a 85px para máximo rendimiento a 60FPS
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final u = usuarios[index];
                final estado = u['estado'].toString();
                final Color colorEstado = estado == 'AL DÍA' ? Colors.green : (estado == 'CRÍTICO' ? Colors.red : Colors.orange);

                return InkWell(
                  onTap: () => _mostrarDetalleUsuario(u),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        AvatarUsuario(
                          nombre: u['nombre'].toString(),
                          fotoUrl: u['foto_url']?.toString(),
                          radius: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(u['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Deuda: S/ ${(u['deuda'] as num).toDouble().toStringAsFixed(2)}  •  Faltas: ${u['faltas']}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 13)),
                            ],
                          ),
                        ),
                        BadgeEstado(
                          texto: estado,
                          colorBase: colorEstado,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleUsuario(Map<String, dynamic> u) {
    final deuda = (u['deuda'] as num).toDouble();
    final String celular = u['celular']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarUsuario(
                nombre: u['nombre'].toString(),
                fotoUrl: u['foto_url']?.toString(),
                radius: 40,
              ),
              const SizedBox(height: 16),
              Text(u['nombre'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Deuda Pendiente: S/ ${deuda.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600)),
              Text('Inasistencias Acumuladas: ${u['faltas']} faltas', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              BotonGradiente(
                text: 'Notificar Deuda por WhatsApp',
                icon: Icons.chat,
                useSecondaryColor: true,
                onPressed: () async {
                  if (celular.isEmpty) {
                    _mostrarError('El usuario no tiene celular registrado.');
                    return;
                  }
                  final numWhats = celular.startsWith('51') ? celular : '51$celular';
                  final uri = Uri.parse('whatsapp://send?phone=$numWhats&text=Hola ${u['nombre']}, te escribimos para recordarte tu deuda de S/ ${deuda.toStringAsFixed(2)}.');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    _mostrarError('No se pudo abrir WhatsApp');
                  }
                },
              ),
            ],
          ),
        );
      }
    );
  }

  // --- LÓGICA: EXPORTAR A EXCEL ---
  Future<void> _exportarExcel() async {
    setState(() => _exportando = true);
    // Añadimos un pequeño retraso para permitir que la UI se actualice y muestre el loading
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Tesoreria'];
      excel.setDefaultSheet('Tesoreria');

      // Cabeceras
      sheet.appendRow([
        TextCellValue('ID'), 
        TextCellValue('Usuario'), 
        TextCellValue('Deuda Total (S/)'), 
        TextCellValue('Faltas'), 
        TextCellValue('Estado')
      ]);

      // Datos
      final usuarios = _datosAnaliticos!['usuarios'] as List;
      for (var u in usuarios) {
        sheet.appendRow([
          IntCellValue(u['id'] as int),
          TextCellValue(u['nombre']),
          DoubleCellValue((u['deuda'] as num).toDouble()),
          IntCellValue(u['faltas'] as int),
          TextCellValue(u['estado']),
        ]);
      }

      // Guardar y Compartir
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/Reporte_Tesoreria.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(path)], text: 'Reporte Excel de Tesorería');
      }
    } catch (e) {
      _mostrarError('Error al exportar Excel: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _exportarPDF() async {
    setState(() => _exportando = true);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final doc = pw.Document();
      final List usuarios = _datosAnaliticos!['usuarios'] as List;
      const int filasPorPagina = 20;
      final int totalPaginas = (usuarios.length / filasPorPagina).ceil();

      if (usuarios.isEmpty) {
        _mostrarError('No hay usuarios para exportar');
        return;
      }

      for (int p = 0; p < totalPaginas; p++) {
        final int start = p * filasPorPagina;
        final int end = (start + filasPorPagina < usuarios.length) ? start + filasPorPagina : usuarios.length;
        final List datosPagina = usuarios.sublist(start, end);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Reporte Consolidado de Tesorería - Página ${p + 1} de $totalPaginas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    headers: ['Nº', 'Usuario', 'Deuda Total', 'Faltas', 'Estado'],
                    data: datosPagina.asMap().entries.map((entry) {
                      int idx = start + entry.key + 1;
                      var dato = entry.value;
                      return [idx.toString(), dato['nombre'], 'S/ ${(dato['deuda'] as num).toDouble().toStringAsFixed(2)}', dato['faltas'].toString(), dato['estado']];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1D3557)),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              );
            },
          ),
        );
      }
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Reporte_Tesoreria_$_anioSeleccionado.pdf');
    } catch(e) {
      _mostrarError('Error generando PDF: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Widget _buildGraficoTendencias() {
    final tendencias = _datosAnaliticos!['tendencias'];
    final List<double> ingresosMensuales = List<double>.from(tendencias['ingresos'].map((e) => (e as num).toDouble()));
    final List<double> gastosMensuales = List<double>.from(tendencias['gastos'].map((e) => (e as num).toDouble()));

    final List<FlSpot> spotsIngresos = [];
    final List<FlSpot> spotsGastos = [];

    for (int i = 0; i < 12; i++) {
      spotsIngresos.add(FlSpot(i.toDouble(), ingresosMensuales[i]));
      spotsGastos.add(FlSpot(i.toDouble(), gastosMensuales[i]));
    }

    const mesesCortos = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return TarjetaPremium(
      usaGradientePrimario: false,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flujo de Recaudación vs Gastos - $_anioSeleccionado', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D3557))),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 30, 
                      getTitlesWidget: (val, meta) {
                        int idx = val.toInt();
                        if (idx < 0 || idx >= 12) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(mesesCortos[idx], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        );
                      }
                    )
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsIngresos,
                    isCurved: true, color: Colors.teal, barWidth: 3, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.teal.withValues(alpha: 0.1)),
                  ),
                  LineChartBarData(
                    spots: spotsGastos,
                    isCurved: true, color: const Color(0xFFE63946), barWidth: 3, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFFE63946).withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendaChart('Ingresos', Colors.teal),
              const SizedBox(width: 16),
              _buildLegendaChart('Gastos', const Color(0xFFE63946)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendaChart(String t, Color c) {
    return Row(
      children: [
        Icon(Icons.circle, color: c, size: 10),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMapaPlaceholder() {
    final List alertas = _datosAnaliticos!['alertas'] ?? [];

    if (alertas.isEmpty) {
      return const TarjetaPremium(
        usaGradientePrimario: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
              SizedBox(height: 16),
              Text('No hay alertas críticas en este momento', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: alertas.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final a = alertas[index];
        final Color colorBase = a['nivel'] == 'danger' ? const Color(0xFFE63946) : Colors.orange;
        
        IconData icon;
        switch(a['tipo']) {
          case 'USUARIO': icon = Icons.person_off; break;
          case 'ACTIVIDAD': icon = Icons.event_busy; break;
          case 'CAJA': icon = Icons.account_balance_wallet; break;
          default: icon = Icons.notifications_active;
        }

        return TarjetaPremium(
          usaGradientePrimario: false,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colorBase.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: colorBase),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['titulo'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorBase)),
                    const SizedBox(height: 4),
                    Text(a['msj'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarraLateral() { 
    return Container(
      width: 250, 
      color: Colors.white, 
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtros Globales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          _crearDropdown('Año Fiscal', ['2024', '2025', '2026'], _anioSeleccionado, (val) => setState(() { _anioSeleccionado = val!; _cargarDatos(); })),
          _crearDropdown('Mes', _meses, _mesSeleccionado, (val) => setState(() { _mesSeleccionado = val!; _cargarDatos(); })),
          _crearDropdown('Reporte', ['DEUDAS', 'ASISTENCIA', 'INGRESOS'], _tipoReporteSeleccionado, (val) => setState(() => _tipoReporteSeleccionado = val!)),
          _crearDropdown('Estado', ['TODOS', 'MOROSOS', 'AL DÍA', 'CRÍTICO'], _estadoSeleccionado, (val) => setState(() { _estadoSeleccionado = val!; _cargarDatos(); })),
        ],
      )
    ); 
  }
  
  Widget _buildFiltrosMovil() { 
    return Container(
      color: Colors.white,
      child: ExpansionTile(
        title: const Text('Filtros Globales', style: TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _crearDropdown('Año', ['2024', '2025', '2026'], _anioSeleccionado, (val) => setState(() { _anioSeleccionado = val!; _cargarDatos(); })),
          _crearDropdown('Mes', _meses, _mesSeleccionado, (val) => setState(() { _mesSeleccionado = val!; _cargarDatos(); })),
          _crearDropdown('Estado', ['TODOS', 'MOROSOS', 'AL DÍA', 'CRÍTICO'], _estadoSeleccionado, (val) => setState(() { _estadoSeleccionado = val!; _cargarDatos(); })),
        ],
      ),
    ); 
  }

  Widget _crearDropdown(String titulo, List<String> opciones, String valorActual, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: valorActual,
                items: opciones.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
