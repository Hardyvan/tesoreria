import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:fl_chart/fl_chart.dart';
import '../myPagesTema/c_formatos.dart';
import '../../myPagesBack/b_logica_estado_financiero.dart';
import '../../myPagesBack/a_logica_inicio_sesion.dart';
import '../../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import 'b_estado_financiero.dart';
import 'e_actividades.dart';
import '../../myPagesTema/f_esqueletos.dart'; // IMPORTANTE

import '../../myPagesBack/g_servicio_excel.dart';

class ReporteFinanciero extends StatefulWidget {
  const ReporteFinanciero({super.key});

  @override
  State<ReporteFinanciero> createState() => _ReporteFinancieroState();
}

class _ReporteFinancieroState extends State<ReporteFinanciero> {
  Future<void>? _futureCarga;
  final ScrollController _scrollController = ScrollController();
  int _seccionTocada = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Lanzamos carga inicial (si está vacío, mostrará bloqueante)
        // Pero siempre refresca en segundo plano.
        _futureCarga = _cargarDatos(reset: true);
        setState(() {});
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
    
    // Almacenamos el future unificado de las dos dependencias para el FutureBuilder
    await Future.wait([
      provider.obtenerResumenFinanciero(),
      provider.obtenerMovimientosKardex(reset: reset),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<ControladorFinanzas>();
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM HH:mm');
    final esAdmin = context.read<ControladorAuth>().esAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Financiero'),
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
          const BannerSinConexion() 
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(reset: true),
        child: FutureBuilder(
          future: _futureCarga,
          builder: (context, snapshot) {
            // Si no hay datos cacheados y la carga está en progreso o no iniciada
            if (finanzas.kardex.isEmpty && (snapshot.connectionState == ConnectionState.waiting || _futureCarga == null)) {
               return const EsqueletoReporteFinanciero();
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
            // Sumamos 3 items extra para la cabecera (Wallet + Gráfico + Título)
            // Y 1 adicional al final si hay más por cargar
            final itemCount = finanzas.kardex.isEmpty 
              ? 4 
              : finanzas.kardex.length + 3 + (finanzas.hayMasKardex ? 1 : 0);

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
                  return _buildGraficoResumen(finanzas);
                }
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Text(
                      'Movimientos Recientes', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  );
                }
                
                if (finanzas.kardex.isEmpty && index == 3) {
                  return _buildEmptyState();
                }

                if (index - 3 < finanzas.kardex.length) {
                  final mov = finanzas.kardex[index - 3];
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
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withAlpha(200),
            const Color(0xFF1E3C72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
              if (context.read<ControladorAuth>().usuarioActual?.rol == 'SuperAdmin')
                InkWell(
                  onTap: () => _mostrarDialogoFondoBase(context, finanzas),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange, // <-- GRAN RESALTE NARANJA 
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_card, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Aperturar Caja', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              else
                Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          _ContadorAnimado(
            valorFinal: finanzas.saldoCaja,
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
                        Text('Pagos Alumnos', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ContadorAnimado(
                      valorFinal: finanzas.totalIngresos,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (finanzas.fondoBase > 0 || finanzas.fondoBaseMotivo.isNotEmpty) ...[
                       const SizedBox(height: 12),
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(4),
                             decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                             child: const Icon(Icons.account_balance, color: Colors.cyanAccent, size: 14),
                           ),
                           const SizedBox(width: 8),
                           Text('Fondo Base', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                         ],
                       ),
                       const SizedBox(height: 4),
                       _ContadorAnimado(
                         valorFinal: finanzas.fondoBase,
                         style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                       ),
                       Text(
                         finanzas.fondoBaseMotivo,
                         style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                         overflow: TextOverflow.ellipsis,
                         maxLines: 1,
                       ),
                    ],
                  ],
                ),
              ),
              Container(width: 1, height: finanzas.fondoBase > 0 ? 80 : 40, color: Colors.white.withValues(alpha: 0.2)),
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
                      _ContadorAnimado(
                        valorFinal: finanzas.totalGastos,
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

  // --- DIÁLOGO DE APERTURA DE CAJA (SOLO SUPERADMIN) ---
  void _mostrarDialogoFondoBase(BuildContext context, ControladorFinanzas finanzas) {
     final ctrlMonto = TextEditingController(text: finanzas.fondoBase > 0 ? finanzas.fondoBase.toStringAsFixed(2) : '');
     final ctrlMotivo = TextEditingController(text: finanzas.fondoBaseMotivo);

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Fondo de Apertura', style: TextStyle(fontWeight: FontWeight.bold)),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text('Registra aquí el dinero base con el que abre la caja fuerte (ej. de la directiva anterior).', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
               maxLines: 2,
               decoration: const InputDecoration(labelText: 'Detalle (ej. "Tesorera anterior")', prefixIcon: Icon(Icons.info_outline)),
             ),
           ],
         ),
          actions: [
            if (finanzas.fondoBase > 0)
              TextButton(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('¿Resetear Caja?'),
                      content: const Text('Esto borrará todo el dinero base registrado actualmente. ¿Continuar?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, borrar')),
                      ],
                    )
                  );
                  if (confirmar == true && context.mounted) {
                    Navigator.pop(ctx);
                    await finanzas.vaciarFondoBase();
                    if (context.mounted) ManejadorErrores.mostrarMensajeExito(context, 'Caja reseteada a S/ 0.00');
                  }
                }, 
                child: const Text('Limpiar Caja', style: TextStyle(color: Colors.red))
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                double? monto = double.tryParse(ctrlMonto.text);
                if (monto != null) {
                   final usr = context.read<ControladorAuth>().usuarioActual;
                   if (usr != null) {
                      ManejadorErrores.mostrarMensajeExito(context, 'Guardando configuración...');
                      bool exito = false;
                      if (finanzas.fondoBase > 0) {
                        exito = await finanzas.editarFondoBase(monto);
                      } else {
                        exito = await finanzas.establecerFondoBase(monto, ctrlMotivo.text.trim(), usr);
                      }
                      
                      if (exito && context.mounted) {
                         ManejadorErrores.mostrarMensajeExito(context, 'Fondo base actualizado correctamente.');
                      }
                   }
                } else {
                  if (context.mounted) ManejadorErrores.mostrarErrorCritico(context, 'Inválido', 'Ingrese un importe válido.');
                }
              },
              child: Text(finanzas.fondoBase > 0 ? 'Actualizar Fondo' : 'Guardar Fondo'),
            )
         ]
       )
     );
  }

  Widget _buildGraficoResumen(ControladorFinanzas finanzas) {
    if (finanzas.totalIngresos == 0 && finanzas.totalGastos == 0 && finanzas.fondoBase == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: Column(
        children: [
          Text('Resumen de Gestión', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _seccionTocada = -1;
                        return;
                      }
                      _seccionTocada = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.greenAccent.shade700,
                    value: finanzas.totalIngresos,
                    title: _seccionTocada == 0 ? 'S/${finanzas.totalIngresos.toStringAsFixed(0)}' : 'Ingresos',
                    radius: _seccionTocada == 0 ? 60.0 : 50.0,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.redAccent.shade700,
                    value: finanzas.totalGastos,
                    title: _seccionTocada == 1 ? 'S/${finanzas.totalGastos.toStringAsFixed(0)}' : 'Gastos',
                    radius: _seccionTocada == 1 ? 60.0 : 50.0,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutBack,
            ),
          ),
        ],
      )
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
    final esExtra  = mov['tipo'] == 'X';
    final esPositivo = esIngreso || esExtra;

    final colorIcono = esIngreso
        ? ColoresApp.exito
        : esExtra
            ? Colors.teal
            : ColoresApp.error;
    final colorFondoIcono = colorIcono.withValues(alpha: 0.1);

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
          onTap: !esAdmin ? null : () async {
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
                    esPositivo ? Icons.arrow_downward : Icons.arrow_upward, 
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
                      '${esPositivo ? "+" : "-"} ${currencyFormat.format(mov['monto'])}',
                      style: GoogleFonts.inter(
                        color: colorIcono,
                        fontWeight: FontWeight.bold,
                        fontSize: 15
                      ),
                    ),
                    if (esAdmin) ...[
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

class _ContadorAnimado extends StatelessWidget {
  final double valorFinal;
  final TextStyle style;
  const _ContadorAnimado({required this.valorFinal, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: valorFinal),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutQuart,
      builder: (context, val, _) {
        return Text('S/ ${val.toStringAsFixed(2)}', style: style);
      },
    );
  }
}
