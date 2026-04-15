import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED FOR DYNAMIC CHARTS

import '../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import '../myPagesBack/g_servicio_excel.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Financiero'),
        centerTitle: true,
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
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              esAdmin 
                  ? 'Panel de control administrativo e informes financieros.'
                  : 'Aquí encontrarás herramientas e información útil sobre el estado de la tesorería.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ColoresApp.textoSecundarioClaro,
              ),
            ),
            
            const SizedBox(height: 24),

            // SECCIÓN: GRÁFICO DINÁMICO DE APORTES (NUEVO)
            Text(
              'Estado de Aportes',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_chart, color: Colors.green, size: 28),
                      ),
                      title: Text(
                        esAdmin ? 'Cierre Contable Completo' : 'Estado General de Tesorería',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        esAdmin 
                          ? 'Exporta la lista de deudores, pagos y gastos en un archivo de Excel (.xlsx)'
                          : 'Descarga un resumen oficial del estado de cuentas de la promoción en Excel.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          // Mostrar indicador
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generando archivo Excel... 📊'), duration: Duration(seconds: 2)),
                          );
                          
                          // Generar
                          bool exito = await ServicioExcel.exportarYCompartir(context);
                          
                          if (!exito && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al generar el reporte.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar Reporte Excel', style: TextStyle(fontWeight: FontWeight.bold)),
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
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              // Opciones para Alumnos (Podría ser accesos directos informativos)

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
                icon: const Icon(Icons.sync),
                label: const Text('Actualizar Datos'),
                style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
              ),
            ),
            const SizedBox(height: 20),
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
                 bool exito = await finanzas.registrarIngresoExtra(monto, motivo, auth.usuarioActual!);
                 if (exito && context.mounted) {
                    ManejadorErrores.mostrarMensajeExito(context, '✅ Ingreso registrado y notificado con éxito.');
                 } else if (context.mounted) {
                    ManejadorErrores.mostrarErrorCritico(context, 'Error', 'No se pudo guardar.');
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

  // WIDGET EXTRAIDO PARA EL GRÁFICO TIPO DONA
  Widget _construirGraficoAportes(int alDia, int conDeuda) {
    int total = alDia + conDeuda;
    if (total == 0) return const Text('No hay deudores ni aportantes.');

    return TarjetaPremium(
      usaGradientePrimario: false,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                   PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: [
                        if (alDia > 0)
                          PieChartSectionData(
                            color: ColoresApp.exito,
                            value: alDia.toDouble(),
                            title: '${((alDia / total) * 100).toStringAsFixed(0)}%',
                            radius: 45,
                            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (conDeuda > 0)
                          PieChartSectionData(
                            color: ColoresApp.error.withValues(alpha: 0.8),
                            value: conDeuda.toDouble(),
                            title: '${((conDeuda / total) * 100).toStringAsFixed(0)}%',
                            radius: 45,
                            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ]
                    )
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('$total', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ]
                  )
                ]
              ),
            ),
            const SizedBox(height: 16),
            // LEYENDA
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _indicador(ColoresApp.exito, 'Al día ($alDia)'),
                const SizedBox(width: 24),
                _indicador(ColoresApp.error, 'Con Deuda ($conDeuda)'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _indicador(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, 
          height: 12, 
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)
        ),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ColoresApp.sombraSuave,
          border: Border.all(color: colorBase.withValues(alpha: 0.3)),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
