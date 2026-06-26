import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';


import '../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesTema/i_servicio_descargas.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';

class PortalFinanciero extends StatefulWidget {
  const PortalFinanciero({super.key});

  @override
  State<PortalFinanciero> createState() => _PortalFinancieroState();
}

class _PortalFinancieroState extends State<PortalFinanciero> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fn = Provider.of<ControladorFinanzas>(context, listen: false);
      fn.obtenerReporteDeudores(); // Load users for the chart
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final fn = Provider.of<ControladorFinanzas>(context);
    final esAdmin = auth.usuarioActual?.rol == 'Admin' || auth.usuarioActual?.rol == 'SuperAdmin';
    final theme = Theme.of(context);

    // Calcular datos del grafico
    int alDia = 0;
    int conDeuda = 0;
    for (var d in fn.listaDeudores) {
      if (d['estado'] == 'Al día' || (d['deuda'] as double) <= 0) {
        alDia++;
      } else {
        conDeuda++;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Control de Caja',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MENSAJE DE BIENVENIDA
            Text(
              '¡Hola, ${auth.usuarioActual?.nombre.split(' ')[0] ?? 'Usuario'}!',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              esAdmin 
                  ? 'Panel de control administrativo e informes financieros.'
                  : 'Aquí encontrarás herramientas e información útil sobre el estado de la tesorería.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            
            const SizedBox(height: 24),

            // SECCIÓN: GRÁFICO DINÁMICO DE APORTES (NUEVO)
            Text(
              'Estado de Aportes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Theme.of(context).primaryColor
              ),
            ),
            const SizedBox(height: 16),
            if (fn.cargando && fn.listaDeudores.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else if (fn.listaDeudores.isNotEmpty)
              _construirGraficoAportes(alDia, conDeuda),
            
            const SizedBox(height: 32),

            // SECCIÓN: REPORTES (PARA TODOS, PERO DIFERENTE)
            Text(
              'Reportes y Descargas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Theme.of(context).primaryColor
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Descarga de Excel
            TarjetaPremium(
              usaGradientePrimario: false, // Usaremos un estilo sutil
              esBordeBrillante: true,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.download_for_offline_rounded, color: theme.primaryColor, size: 28),
                      ),
                      title: Text(
                        esAdmin ? 'Centro de Descargas Premium' : 'Estado General de Tesorería',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87
                        ),
                      ),
                      subtitle: Text(
                        esAdmin 
                          ? 'Exporta la lista de deudores, pagos y gastos en Excel estilizado o PDFs listos para imprimir.'
                          : 'Descarga un resumen oficial del estado de cuentas de la promoción en formato Excel o PDF.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          ServicioDescargas.mostrarMenuDescargas(context);
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Abrir Centro de Descargas', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // SECCIÓN: HERRAMIENTAS AVANZADAS (SOLO ADMINS)
            if (esAdmin) ...[
              Text(
                'Herramientas de Administración',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.primaryColor
                ),
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _TarjetaOpcionAdmin(
                    titulo: 'Gráficos\nAvanzados',
                    icono: Icons.pie_chart,
                    colorBase: Colors.blueAccent,
                    onTap: () => Navigator.pushNamed(context, '/reportes_avanzados'),
                  ),
                  _TarjetaOpcionAdmin(
                    titulo: 'Registrar\nIngreso Extra',
                    icono: Icons.volunteer_activism,
                    colorBase: Colors.green,
                    onTap: () => _mostrarDialogoDonacion(context),
                  ),
                  _TarjetaOpcionAdmin(
                    titulo: 'Gestión\nUsuarios',
                    icono: Icons.manage_accounts,
                    colorBase: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/gestion_usuarios'),
                  ),
                  _TarjetaOpcionAdmin(
                    titulo: 'Ajustes de\nAdministrador',
                    icono: Icons.admin_panel_settings_rounded,
                    colorBase: Colors.indigo,
                    onTap: () => Navigator.pushNamed(context, '/ajustes_admin'),
                  ),
                  if (auth.usuarioActual?.rol == 'SuperAdmin')
                    _TarjetaOpcionAdmin(
                      titulo: 'Auditoría\ndel Sistema',
                      icono: Icons.security,
                      colorBase: Colors.redAccent,
                      onTap: () => Navigator.pushNamed(context, '/auditoria'),
                    ),
                ],
              ),
            ] else ...[
              // Opciones para Alumnos (Accesos rápidos a reportes y análisis)
              Text(
                'Herramientas de Consulta',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.primaryColor
                ),
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _TarjetaOpcionAdmin(
                    titulo: 'Reporte\nFinanciero',
                    icono: Icons.assessment_outlined,
                    colorBase: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, '/reportes'),
                  ),
                  _TarjetaOpcionAdmin(
                    titulo: 'Gráficos\nAvanzados',
                    icono: Icons.pie_chart,
                    colorBase: Colors.blueAccent,
                    onTap: () => Navigator.pushNamed(context, '/reportes_avanzados'),
                  ),
                  _TarjetaOpcionAdmin(
                    titulo: 'InSOFT\nAnalytics',
                    icono: Icons.analytics,
                    colorBase: Colors.purple,
                    onTap: () => Navigator.pushNamed(context, '/insoft_analytics'),
                  ),
                ],
              ),
            ],
              
              const SizedBox(height: 32),
              
              // BOTÓN DE SINCRONIZACIÓN (TODOS)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    final finanzasController = Provider.of<ControladorFinanzas>(context, listen: false);
                    finanzasController.cargarFinanzasUsuario(auth.usuarioActual!.id);
                    finanzasController.obtenerMovimientosKardex(reset: true);
                    finanzasController.obtenerReporteDeudores(); // REFRESH GRÁFICO
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sincronizados datos financieros con el servidor.')),
                    );
                  },
                  icon: Icon(Icons.sync, color: isDark ? Colors.white : theme.primaryColor),
                  label: Text(
                    'Actualizar Datos', 
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.primaryColor
                    )
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : theme.primaryColor,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : theme.primaryColor.withValues(alpha: 0.25)
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: isDark ? 0 : 2,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

  // DIÁLOGO PARA REGISTRAR DONACIÓN O INGRESO EXTRA
  void _mostrarDialogoDonacion(BuildContext context) {
    final ctrlMonto = TextEditingController();
    final ctrlMotivo = TextEditingController();
    final finanzas = context.read<ControladorFinanzas>();
    final auth = context.read<ControladorAuth>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Ingreso Extra', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Añade un ingreso a caja que no proviene de una actividad regular (Ej. Donativos, Rifas).', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrlMonto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto Total (S/)', 
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 15, right: 10, top: 14), 
                  child: Text('S/', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                )
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrlMotivo,
              textCapitalization: TextCapitalization.sentences,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Motivo (Ej. Donación voluntaria)', prefixIcon: Icon(Icons.description)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              double? monto = double.tryParse(ctrlMonto.text);
              String motivo = ctrlMotivo.text.trim();
              
              if (monto != null && monto > 0 && motivo.isNotEmpty) {
                 Navigator.pop(ctx);
                 ManejadorErrores.mostrarMensajeExito(context, 'Registrando ingreso e informando a los usuarios...');
                 final resultado = await finanzas.registrarIngresoExtra(monto, motivo, auth.usuarioActual!);
                 if (resultado['ok'] == true && context.mounted) {
                    ManejadorErrores.mostrarMensajeExito(context, '✅ Ingreso registrado y notificado con éxito.');
                 } else if (context.mounted) {
                    ManejadorErrores.mostrarErrorCritico(context, 'Error', resultado['msj'] ?? 'No se pudo guardar.');
                 }
              } else {
                 ManejadorErrores.mostrarErrorCritico(context, 'Inválido', 'Asegúrate de poner un monto mayor a 0 y una descripción.');
              }
            },
            child: const Text('Ingresar Dinero'),
          )
        ]
      )
    );
  }

  // WIDGET EXTRAIDO PARA EL GRÁFICO TIPO DONA EN 3D
  Widget _construirGraficoAportes(int alDia, int conDeuda) {
    int total = alDia + conDeuda;
    if (total == 0) return const Text('No hay deudores ni aportantes.');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: TarjetaPremium(
        usaGradientePrimario: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sombra de toda la base del disco 3D
                    Positioned(
                      bottom: 12,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(0.65),
                        alignment: Alignment.center,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Borde de grosor 3D (Cuerpo cilíndrico del gráfico)
                    Positioned(
                      top: 14,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(0.65),
                        alignment: Alignment.center,
                        child: Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // La cara interactiva superior del gráfico en 3D
                    Positioned(
                      top: 6,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(0.65), // Inclinación isométrica
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 55,
                              sections: [
                                if (alDia > 0)
                                  PieChartSectionData(
                                    color: ColoresApp.exito,
                                    value: alDia.toDouble(),
                                    title: '${((alDia / total) * 100).toStringAsFixed(0)}%',
                                    radius: 35,
                                    titleStyle: GoogleFonts.outfit(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w800, 
                                      color: Colors.white
                                    ),
                                  ),
                                if (conDeuda > 0)
                                  PieChartSectionData(
                                    color: ColoresApp.error,
                                    value: conDeuda.toDouble(),
                                    title: '${((conDeuda / total) * 100).toStringAsFixed(0)}%',
                                    radius: 35,
                                    titleStyle: GoogleFonts.outfit(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w800, 
                                      color: Colors.white
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Centro de la dona (Tapa interna con simulación de profundidad)
                    Positioned(
                      top: 50, // Centrado con la perspectiva
                      child: Container(
                        width: 76,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 3),
                            )
                          ],
                       ),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text(
                             'Total', 
                             style: GoogleFonts.inter(
                               fontSize: 11, 
                               color: isDark ? Colors.white60 : Colors.black54,
                               fontWeight: FontWeight.w500
                             )
                           ),
                           const SizedBox(height: 2),
                           Text(
                             '$total', 
                             style: GoogleFonts.outfit(
                               fontSize: 24, 
                               fontWeight: FontWeight.bold,
                               color: isDark ? Colors.white : Colors.black87
                             )
                           ),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 16),
             // LEYENDA
             Wrap(
               alignment: WrapAlignment.center,
               spacing: 24,
               runSpacing: 8,
               children: [
                 _indicador(ColoresApp.exito, 'Al día ($alDia)'),
                 _indicador(ColoresApp.error, 'Con Deuda ($conDeuda)'),
               ],
             )
           ],
         ),
       ),
     ),
    );
   }

  Widget _indicador(Color color, String texto) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, 
          height: 12, 
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)
        ),
        const SizedBox(width: 8),
        Text(
          texto, 
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87
          )
        ),
      ],
    );
  }
}

class _TarjetaOpcionAdmin extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color colorBase;
  final VoidCallback onTap;

  const _TarjetaOpcionAdmin({
    required this.titulo,
    required this.icono,
    required this.colorBase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : ColoresApp.sombraSuave,
          border: Border.all(
            color: isDark ? colorBase.withValues(alpha: 0.3) : colorBase.withValues(alpha: 0.15)
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorBase.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorBase, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
