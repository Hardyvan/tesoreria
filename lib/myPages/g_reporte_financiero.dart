import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; 
import '../../myPagesTema/b_formato.dart';
import '../../myPagesBack/b_controlador_finanzas.dart';
import '../../myPagesBack/a_controlador_auth.dart';
import '../../myPagesTema/a_tema.dart';
import '../../myPagesTema/c_ui_kit.dart';
import 'c_editar_pago.dart';
import 'f_registro_gastos.dart';
import 'h_reportes_avanzados.dart';
import '../myPagesServer/g_servicio_excel.dart';
import '../../globals.dart';

class ReporteFinanciero extends StatefulWidget {
  const ReporteFinanciero({super.key});

  @override
  State<ReporteFinanciero> createState() => _ReporteFinancieroState();
}

class _ReporteFinancieroState extends State<ReporteFinanciero> {
  Future<void>? _futureCarga;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _futureCarga = _cargarDatos(reset: true);
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        final provider = context.read<ControladorFinanzas>();
        if (!provider.cargando && provider.hayMasKardex) {
           provider.obtenerMovimientosKardex(reset: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos({bool reset = false}) async {
    final provider = context.read<ControladorFinanzas>();
    await provider.obtenerResumenFinanciero();
    await provider.obtenerMovimientosKardex(reset: reset);
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<ControladorFinanzas>();
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM HH:mm');
    final esAdmin = context.read<ControladorAuth>().esAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja General'),
        actions: [
          if (esAdmin)
            IconButton(
              icon: const Icon(Icons.table_view_outlined),
              tooltip: 'Exportar Cierre Contable a Excel',
              onPressed: () async {
                ManejadorErrores.mostrarMensajeExito(context, 'Generando documento, por favor espera...');
                final exito = await ServicioExcel.exportarYCompartir(context);
                if (!exito && context.mounted) {
                   ManejadorErrores.mostrarErrorCritico(context, 'Error de Exportación', 'Hubo un error al generar o compartir el archivo Excel.');
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reportes Avanzados',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ReportesAvanzados())
              );
            },
          ),
          const BannerSinConexion() 
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(reset: true),
        child: FutureBuilder(
          future: _futureCarga,
          builder: (context, snapshot) {
            if (_futureCarga == null || (snapshot.connectionState == ConnectionState.waiting && finanzas.kardex.isEmpty)) {
               return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: ColoresApp.error, size: 60),
                      const SizedBox(height: 16),
                      Text('Ocurrió un error al cargar los datos.', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        onPressed: () => setState(() { _futureCarga = _cargarDatos(); }),
                      )
                    ],
                  ),
                )
              );
            }

            // Usamos ListView.builder para mejorar el rendimiento
            // Sumamos 2 items extra para la cabecera (Wallet + Título)
            // Y 1 adicional al final si hay más por cargar
            final itemCount = finanzas.kardex.isEmpty 
              ? 3 
              : finanzas.kardex.length + 2 + (finanzas.hayMasKardex ? 1 : 0);

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                top: DimensionesApp.paddingEstandar,
                left: DimensionesApp.paddingEstandar,
                right: DimensionesApp.paddingEstandar,
                bottom: 80
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildWalletCard(finanzas);
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Text(
                      'Movimientos Recientes', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  );
                }
                
                if (finanzas.kardex.isEmpty && index == 2) {
                  return _buildEmptyState();
                }

                if (index - 2 < finanzas.kardex.length) {
                  final mov = finanzas.kardex[index - 2];
                  return _buildMovimientoItem(mov, esAdmin, dateFormat, currencyFormat);
                } else {
                  // Elemento de cargando más...
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            );
          },
        ),
      ),
      floatingActionButton: !esAdmin ? null : FloatingActionButton.extended(
        heroTag: 'fab_gasto',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistroGastos()),
          ).then((_) => _cargarDatos());
        },
        backgroundColor: ColoresApp.error,
        icon: const Icon(Icons.money_off, color: Colors.white),
        label: Text('Registrar Gasto', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildWalletCard(ControladorFinanzas finanzas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ColoresApp.gradientePrimario,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        // EFECTO PREMIUM: Borde interno sutil para simular volumen (Glassmorphism sutil)
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo Disponible',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500
                ),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'S/ ${finanzas.saldoCaja.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text('Ingresos', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'S/ ${finanzas.totalIngresos.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Text('Gastos', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'S/ ${finanzas.totalGastos.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20), 
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, size: 64, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin movimientos', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Text(
              'Aún no hay ingresos ni gastos registrados.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500)
            ),
          ],
        )
      )
    );
  }

  Widget _buildMovimientoItem(Map<String, dynamic> mov, bool esAdmin, DateFormat dateFormat, NumberFormat currencyFormat) {
    final esIngreso = mov['tipo'] == 'I';
    final colorFondoIcono = esIngreso ? ColoresApp.exito.withValues(alpha: 0.1) : ColoresApp.error.withValues(alpha: 0.1);
    final colorIcono = esIngreso ? ColoresApp.exito : ColoresApp.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: Material(
        color: Colors.transparent, // Asegura que el InkWell muestre el efecto Ripple
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: (!esAdmin || !esIngreso) ? null : () async {
            final resultado = await showDialog<bool>(
              context: context, 
              builder: (_) => EditarPago(pago: mov)
            );
            if (resultado == true && mounted) {
               unawaited(_cargarDatos());
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorFondoIcono,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esIngreso ? Icons.arrow_downward : Icons.arrow_upward, 
                    color: colorIcono,
                    size: 20
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mov['descripcion'].toString().toCapitalized(), 
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(mov['fecha']),
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${esIngreso ? "+" : "-"} ${currencyFormat.format(mov['monto'])}',
                      style: GoogleFonts.inter(
                        color: colorIcono,
                        fontWeight: FontWeight.bold,
                        fontSize: 15
                      ),
                    ),
                    if (esAdmin && esIngreso) ...[
                      const SizedBox(height: 4),
                      Text('Editar', style: GoogleFonts.inter(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                    ]
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
