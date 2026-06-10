import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../myPagesBack/g_servicio_excel.dart';
import '../myPagesBack/h_servicio_pdf.dart';
import 'b_ui_kit.dart';
import 'a_tema.dart';

class ServicioDescargas {
  
  /// Muestra el Centro de Descargas Premium como un Bottom Sheet
  static void mostrarMenuDescargas(BuildContext context) {
    HapticFeedback.mediumImpact(); // Retroalimentación táctil inicial

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext bc) {
        return const _MenuDescargasBottomSheet();
      },
    );
  }
}

class _MenuDescargasBottomSheet extends StatefulWidget {
  const _MenuDescargasBottomSheet();

  @override
  State<_MenuDescargasBottomSheet> createState() => _MenuDescargasBottomSheetState();
}

class _MenuDescargasBottomSheetState extends State<_MenuDescargasBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  bool _generandoExcel = false;
  bool _generandoPdfCompleto = false;
  int? _indicePdfGenerando; // Almacena el índice de la opción PDF que se está generando

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarDescargaExcel() async {
    setState(() => _generandoExcel = true);
    await HapticFeedback.lightImpact();
    
    final exito = await ServicioExcel.exportarYCompartir();
    
    if (mounted) {
      setState(() => _generandoExcel = false);
      if (exito) {
        ManejadorErrores.mostrarMensajeExito(context, '¡Libro de Excel exportado con éxito!');
      } else {
        ManejadorErrores.mostrarErrorMensaje(context, 'Error al generar el libro de Excel');
      }
    }
  }

  Future<void> _ejecutarDescargaPdf(int opcion, String titulo) async {
    setState(() {
      if (opcion == 0) {
        _generandoPdfCompleto = true;
      } else {
        _indicePdfGenerando = opcion;
      }
    });
    await HapticFeedback.lightImpact();

    final bytes = await ServicioPdf.generarPdfBytes(opcion);

    if (mounted) {
      setState(() {
        if (opcion == 0) {
          _generandoPdfCompleto = false;
        } else {
          _indicePdfGenerando = null;
        }
      });
      if (bytes != null) {
        // Cerrar el Bottom Sheet primero
        Navigator.pop(context);
        
        String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
        String nomArchivo = 'Reporte_${titulo.replaceAll(' ', '_')}_$timestamp.pdf';
        
        // Navegar a la pantalla de vista previa del PDF
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VistaPreviaPdfPage(
              pdfBytes: bytes,
              titulo: titulo,
              nombreArchivo: nomArchivo,
            ),
          ),
        );
      } else {
        ManejadorErrores.mostrarErrorMensaje(context, 'Error al generar el PDF de "$titulo"');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Transform.translate(
          offset: Offset(0, _slideAnim.value * screenHeight * 0.4),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark ? ColoresApp.superficieOscura : ColoresApp.superficieClara,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(DimensionesApp.radioGrande * 1.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              
              // Cabecera del Centro de Descargas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.paddingEstandar),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centro de Descargas',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Inter',
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exportación de libros contables y reportes',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Contenido con scroll flexible
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.paddingEstandar),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECCIÓN 1: DESCARGAS CONSOLIDADAS COMPLETAS
                      Text(
                        'CIERRE CONTABLE CONSOLIDADO (TODAS LAS PESTAÑAS)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [
                          // Botón Excel Completo (Grid/Recuadro Premium)
                          Expanded(
                            child: TarjetaPremium(
                              onTap: _generandoExcel ? null : _ejecutarDescargaExcel,
                              backgroundColor: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE8F5E9),
                              esBordeBrillante: true,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _generandoExcel
                                      ? const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(color: Colors.green, strokeWidth: 3),
                                        )
                                      : const Icon(Icons.grid_on_rounded, size: 36, color: Colors.green),
                                  const SizedBox(height: 10),
                                  Text(
                                    '📊 EXCEL COMPLETO',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green.shade700,
                                      fontFamily: 'Inter',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '6 pestañas con recuadro contable',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: isDark ? Colors.white70 : Colors.green.shade900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          
                          // Botón PDF Consolidado
                          Expanded(
                            child: TarjetaPremium(
                              onTap: _generandoPdfCompleto ? null : () => _ejecutarDescargaPdf(0, 'Cierre Completo'),
                              backgroundColor: isDark ? const Color(0xFF3E1F1F) : const Color(0xFFFFEBEE),
                              esBordeBrillante: true,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _generandoPdfCompleto
                                      ? const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
                                        )
                                      : const Icon(Icons.picture_as_pdf_rounded, size: 36, color: Colors.red),
                                  const SizedBox(height: 10),
                                  Text(
                                    '📄 PDF CONSOLIDADO',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red.shade700,
                                      fontFamily: 'Inter',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Documento multipágina para impresión',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: isDark ? Colors.white70 : Colors.red.shade900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // SECCIÓN 2: REPORTES INDIVIDUALES EN PDF
                      Text(
                        'REPORTES INDIVIDUALES (FORMATO PDF CORPORATIVO)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Lista de reportes individuales PDF
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 1,
                        titulo: 'Resumen General',
                        subtitulo: 'Saldos totales en caja y deuda general',
                        icono: Icons.pie_chart_rounded,
                        colorIcono: Colors.blue,
                      ),
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 2,
                        titulo: 'Estado de Alumnos (Deudores)',
                        subtitulo: 'Listado completo, saldos pagados y deudas',
                        icono: Icons.people_alt_rounded,
                        colorIcono: Colors.teal,
                      ),
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 3,
                        titulo: 'Historial de Pagos',
                        subtitulo: 'Registro de cobros ordinarios y multas',
                        icono: Icons.monetization_on_rounded,
                        colorIcono: Colors.amber.shade800,
                      ),
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 4,
                        titulo: 'Historial de Gastos',
                        subtitulo: 'Egresos, facturas, compras y responsables',
                        icono: Icons.shopping_bag_rounded,
                        colorIcono: Colors.indigo,
                      ),
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 5,
                        titulo: 'Ingresos Extra / Donaciones',
                        subtitulo: 'Actividades extras, aportes y saldos extras',
                        icono: Icons.card_giftcard_rounded,
                        colorIcono: Colors.purple,
                      ),
                      _buildFilaReporteIndividual(
                        context: context,
                        opcion: 6,
                        titulo: 'Detalle de Apertura (Fondo Base)',
                        subtitulo: 'Fondos iniciales auditados de la caja',
                        icono: Icons.vpn_key_rounded,
                        colorIcono: Colors.blueGrey,
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilaReporteIndividual({
    required BuildContext context,
    required int opcion,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final esGenerandoEste = _indicePdfGenerando == opcion;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaPremium(
        onTap: (_indicePdfGenerando != null || _generandoPdfCompleto || _generandoExcel) 
            ? null 
            : () => _ejecutarDescargaPdf(opcion, titulo),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icono del Reporte
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: colorIcono, size: 24),
            ),
            const SizedBox(width: 14),
            
            // Textos del Reporte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Botón de Descarga / Spinner
            esGenerandoEste
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  )
                : Icon(
                    Icons.download_rounded,
                    color: isDark ? Colors.white30 : Colors.black26,
                    size: 22,
                  ),
          ],
        ),
      ),
    );
  }
}

class VistaPreviaPdfPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String titulo;
  final String nombreArchivo;

  const VistaPreviaPdfPage({
    super.key,
    required this.pdfBytes,
    required this.titulo,
    required this.nombreArchivo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vista Previa: $titulo',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        pdfFileName: nombreArchivo,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
