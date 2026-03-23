import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/c_formatos.dart';
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
    start: DateTime.now().subtract(const Duration(days: 30)), 
    end: DateTime.now()
  );
  
  Map<String, dynamic> _datosReporte = {};
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Corregimos error "setState() called during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarReporte();
    });
  }

  Future<void> _cargarReporte() async {
    setState(() => _cargando = true);
    final datos = await context.read<ControladorFinanzas>()
        .obtenerReporteAvanzado(_rangoFechas.start, _rangoFechas.end);
    
    if (mounted) {
      setState(() {
        _datosReporte = datos;
        _cargando = false;
      });
    }
  }

  Future<void> _seleccionarFechas() async {
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
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor, // Color de cabecera y selección
              onPrimary: Colors.white, // Color texto en cabecera
              onSurface: Theme.of(context).primaryColor, // Color de textos generales
              surfaceContainer: Colors.white, // Fondo del diálogo (M3)
            ),
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent, // Evitar tinte rosado/azul en M3
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor, 
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            textTheme: TextTheme(
              headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Theme.of(context).primaryColor),
              titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Theme.of(context).primaryColor),
              bodyLarge: GoogleFonts.inter(color: Theme.of(context).primaryColor), // Días de la semana
              bodyMedium: GoogleFonts.inter(color: Theme.of(context).primaryColor), // Días del mes
              bodySmall: GoogleFonts.inter(color: Theme.of(context).primaryColor), // Otros textos
            ),
          ),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Bordes redondeados
            clipBehavior: Clip.antiAlias, // Recorta el contenido a los bordes
            child: SizedBox(
              width: 400, // Ancho máximo controlado
              height: 550, // Altura controlada (menos invasivo)
              child: child,
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _rangoFechas) {
      setState(() => _rangoFechas = picked);
      unawaited(_cargarReporte());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Avanzados'),
        bottom: TabBar(
          controller: _tabController,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))
            ),
            child: InkWell(
              onTap: _seleccionarFechas,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: ColoresApp.sombraSuave,
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Que el botón abrace su contenido
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      '${_rangoFechas.start.toFechaUsuario()}  →  ${_rangoFechas.end.toFechaUsuario()}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.unfold_more_rounded, size: 20, color: ColoresApp.textoSecundarioClaro),
                  ],
                ),
              ),
            ),
          ),

          // CONTENIDO
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _construirBalanceGeneral(),
                    _construirDesgloseActividad(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _construirBalanceGeneral() {
    if (_datosReporte.isEmpty) return const SizedBox();

    final ingresos = _datosReporte['totalIngresos'] ?? 0.0;
    final gastos = _datosReporte['totalGastos'] ?? 0.0;
    final utilidad = _datosReporte['utilidadNeta'] ?? 0.0;
    
    // Cálculo simple para gráfica de barras
    final double maxVal = ingresos > gastos ? ingresos : gastos;
    final double scale = maxVal > 0 ? maxVal : 1;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Resumen del Periodo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        
        // GRÁFICO DE BARRAS SIMPLE
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _barra('Ingresos', ingresos, ColoresApp.exito, ingresos / scale),
            _barra('Gastos', gastos, ColoresApp.error, gastos / scale),
          ],
        ),
        
        const SizedBox(height: 40),

        // TARJETAS DE RESULTADOS
        _cardResultado('Total Recaudado', ingresos, ColoresApp.exito, Icons.arrow_downward),
        const SizedBox(height: 16),
        _cardResultado('Total Gastado', gastos, ColoresApp.error, Icons.arrow_upward),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        _cardResultado('Utilidad Neta', utilidad, utilidad >= 0 ? Theme.of(context).primaryColor : ColoresApp.estadoPendiente, Icons.account_balance_wallet, destacado: true),
      ],
    );
  }

  Widget _barra(String label, double monto, Color color, double porcentajeHeight) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)
          ),
          child: Text(
            monto.toSoles(), 
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: color)
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 180 * porcentajeHeight, // Altura base
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
               BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _cardResultado(String label, double monto, Color color, IconData icon, {bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: destacado ? color.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: destacado ? color.withValues(alpha: 0.3) : Colors.transparent),
        boxShadow: destacado ? ColoresApp.sombraSuave : [
           BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
            ],
          ),
          Text(
            monto.toSoles(), 
            style: GoogleFonts.outfit(
              fontSize: 22, 
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
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No hay datos en este rango'),
          ]
        ),

      );
    }
    
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ColoresApp.sombraSuave,
          ),
          child: ExpansionTile(
            shape: const Border(), // Remueve las líneas superior e inferior feas de Material
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(item['titulo'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(context).primaryColor)),
            subtitle: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                 color: (util >= 0 ? ColoresApp.exito : ColoresApp.error).withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(12)
              ),
              child: Text(
                util >= 0 ? 'Utilidad: ${util.toSoles()}' : 'Pérdida: ${util.toSoles()}',
                style: GoogleFonts.inter(color: util >= 0 ? ColoresApp.exito : ColoresApp.error, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _datoMini('Ingresos', ingresos, ColoresApp.exito, Icons.arrow_downward),
                    Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _datoMini('Gastos', gastos, ColoresApp.error, Icons.arrow_upward),
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
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
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
    setState(() {
      _futureLogs = ServicioAuditoria().obtenerLogsAuditoria();
      _futureCaja = ServicioAuditoria().obtenerResumenCaja(DateTime.now());
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría (Super Admin)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
            const Text('Corte de Caja (Hoy)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureCaja,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) return const Text('No hay cobros registrados hoy.', style: TextStyle(color: Colors.grey));
                
                final caja = snapshot.data!;
                double totalDia = caja.fold(0, (sum, item) => sum + (item['total'] as double));

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...caja.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['admin'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text("S/ ${(item['total'] as double).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL RECAUDADO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('S/ ${totalDia.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            const Text('Historial de Acciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // --- LISTA DE LOGS ---
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureLogs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay registros de auditoría aún.'),
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

    IconData icono;
    Color color;

    if (accion.contains('Pago')) {
      icono = Icons.payments;
      color = Colors.green;
    } else if (accion.contains('Gasto')) {
      icono = Icons.money_off;
      color = Colors.red;
    } else if (accion.contains('Usuario') || accion.contains('Rol')) {
      icono = Icons.manage_accounts;
      color = Colors.orange;
    } else {
      icono = Icons.info;
      color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ColoresApp.sombraSuave,
        border: Border.all(color: Colors.grey.shade200),
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
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icono, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accion, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                  ),
                ),
                Text(
                  dateFormat.format(fecha),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  const TextSpan(text: 'Admin: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$admin '),
                  TextSpan(text: '($dispositivo)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detalle,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
