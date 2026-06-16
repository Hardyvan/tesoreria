import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/c_formatos.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/k_servicio_auditoria.dart';


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

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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
        title: const Text('¿Vaciar todo el historial?'),
        content: const Text('Esta acción eliminará todos los registros de auditoría permanentemente. Solo quedará registro de este vaciado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: ColoresApp.error),
            child: const Text('VACIAR TODO'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final id = auth.usuarioActual?.id ?? 0;

      
      final exito = await ServicioAuditoria().vaciarHistorial('SuperAdmin', id);
      
      if (!mounted) return;

      if (exito) {
        messenger.showSnackBar(const SnackBar(content: Text('Historial vaciado')));
        _cargarDatos();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Error al vaciar historial'), backgroundColor: ColoresApp.error));
      }
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN CORTE DE CAJA (NUEVO) ---
            Text(
              'Corte de Caja (Hoy)', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Theme.of(context).primaryColor
              )
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureCaja,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No hay cobros registrados hoy.', 
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)
                    ),
                  );
                }
                
                final caja = snapshot.data!;
                double totalDia = caja.fold(0, (sum, item) => sum + (item['total'] as double));

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
                    boxShadow: isDark ? [] : AppTokens.sombraSuave,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        ...caja.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['admin'], style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                              Text((item['total'] as double).toSoles(), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                        )),
                        Divider(color: isDark ? Colors.white24 : Colors.black12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL RECAUDADO', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : ColoresApp.exito)
                            ),
                            Text(
                              totalDia.toSoles(), 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 18, 
                                color: isDark ? Colors.greenAccent : ColoresApp.exito
                              )
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            Text(
              'Historial de Acciones', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Theme.of(context).primaryColor
              )
            ),
            const SizedBox(height: 10),

            // --- LISTA DE LOGS ---
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureLogs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No hay registros de auditoría aún.',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  );
                }

                final logs = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true, // Importante para ScrollView
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _TarjetaLog(log: log, dateFormat: dateFormat);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _TarjetaLog extends StatelessWidget {
  final Map<String, dynamic> log;
  final DateFormat dateFormat;

  const _TarjetaLog({required this.log, required this.dateFormat});

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

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
          boxShadow: isDark ? [] : AppTokens.sombraSuave,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(icono, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      accion, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 15, 
                        color: isDark ? Colors.white : Colors.black87
                      )
                    ),
                  ),
                  Text(
                    dateFormat.format(fecha),
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
              Divider(height: 20, color: isDark ? Colors.white24 : Colors.black12),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Admin: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '$admin '),
                    TextSpan(text: '($dispositivo)', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11)),
                  ]
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detalle,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
