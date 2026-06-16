import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:fl_chart/fl_chart.dart';
import '../myPagesTema/c_formatos.dart';
import '../../myPagesBack/b_logica_estado_financiero.dart';
import '../../myPagesBack/g_servicio_excel.dart';
import '../../myPagesBack/h_servicio_pdf.dart';
import '../../myPagesBack/a_logica_inicio_sesion.dart';
import '../../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import 'b_estado_financiero.dart';
import 'e_actividades.dart';
import '../../myPagesTema/f_esqueletos.dart'; // IMPORTANTE

import '../myPagesTema/i_servicio_descargas.dart';

class ReporteFinanciero extends StatefulWidget {
  const ReporteFinanciero({super.key});

  @override
  State<ReporteFinanciero> createState() => _ReporteFinancieroState();
}

class _ReporteFinancieroState extends State<ReporteFinanciero> {
  Future<void>? _futureCarga;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _seccionTocada = -1;
  String _filtroSeleccionado = 'todos'; // 'todos', 'pagos', 'gastos', 'extras'

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
    _searchCtrl.dispose();
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

  String _quitarAcentos(String texto) {
    const conAcento = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const sinAcento = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    String res = texto;
    for (int i = 0; i < conAcento.length; i++) {
      res = res.replaceAll(conAcento[i], sinAcento[i]);
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<ControladorFinanzas>();
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM HH:mm');
    final esAdmin = context.read<ControladorAuth>().esAdmin;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final queryLimpio = _quitarAcentos(_searchQuery.toLowerCase().trim());
    final palabrasBusqueda = queryLimpio.isEmpty ? <String>[] : queryLimpio.split(RegExp(r'\s+'));

    final listaFiltrada = finanzas.kardex.where((mov) {
      // 1. Filtro por tipo
      bool cumpleTipo = true;
      if (_filtroSeleccionado == 'todos') {
        cumpleTipo = true;
      } else if (_filtroSeleccionado == 'pagos') {
        cumpleTipo = mov['tipo'] == 'I';
      } else if (_filtroSeleccionado == 'gastos') {
        cumpleTipo = mov['tipo'] == 'E';
      } else if (_filtroSeleccionado == 'extras') {
        cumpleTipo = mov['tipo'] == 'X';
      }
      
      if (!cumpleTipo) return false;

      // 2. Filtro por texto
      if (palabrasBusqueda.isNotEmpty) {
        final descripcion = _quitarAcentos(mov['descripcion'].toString().toLowerCase());
        final montoText = mov['monto']?.toString() ?? '';
        return palabrasBusqueda.every((palabra) => 
          descripcion.contains(palabra) || montoText.contains(palabra)
        );
      }
      return true;
    }).toList();

    // Auto-paginado inteligente: si el filtro actual tiene pocos elementos pero hay más registros
    // en el servidor, solicitamos la siguiente página automáticamente en segundo plano.
    if (_filtroSeleccionado != 'todos' && listaFiltrada.length < 8 && finanzas.hayMasKardex && !finanzas.cargando) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ControladorFinanzas>().obtenerMovimientosKardex(reset: false);
        }
      });
    }

    final mostrarCargandoMas = finanzas.hayMasKardex && _filtroSeleccionado == 'todos';
    final itemCount = listaFiltrada.isEmpty 
      ? 6 
      : listaFiltrada.length + 5 + (mostrarCargandoMas ? 1 : 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Kardex de Movimientos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (esAdmin) ...[
            IconButton(
              icon: const Icon(Icons.grid_on_rounded, color: Colors.white),
              tooltip: 'Exportar Excel Contable',
              onPressed: () async {
                unawaited(HapticFeedback.lightImpact());
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final exito = await ServicioExcel.exportarYCompartir();
                if (exito) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('¡Libro de Excel exportado con éxito!'), backgroundColor: ColoresApp.exito),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Error al generar el libro de Excel'), backgroundColor: ColoresApp.error),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              tooltip: 'Exportar PDF Consolidado',
              onPressed: () async {
                unawaited(HapticFeedback.lightImpact());
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                unawaited(showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                ));
                try {
                  final bytes = await ServicioPdf.generarPdfBytes(0); // 0 = Cierre Completo
                  navigator.pop();
                  if (bytes != null) {
                    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
                    final nomArchivo = 'Reporte_Cierre_Completo_$timestamp.pdf';
                    await navigator.push(
                      MaterialPageRoute(
                        builder: (ctx) => VistaPreviaPdfPage(
                          pdfBytes: bytes,
                          titulo: 'Cierre Completo',
                          nombreArchivo: nomArchivo,
                        ),
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Error al generar el PDF consolidado'), backgroundColor: ColoresApp.error),
                    );
                  }
                } catch (e) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Ocurrió un error: $e'), backgroundColor: ColoresApp.error),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white),
              tooltip: 'Centro de Descargas Premium (Excel/PDF)',
              onPressed: () {
                ServicioDescargas.mostrarMenuDescargas(context);
              },
            ),
          ],
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
                    padding: const EdgeInsets.only(top: 24, bottom: 4),
                    child: Text(
                      'Movimientos Recientes', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Theme.of(context).primaryColor,
                      )
                    ),
                  );
                }
                if (index == 3) {
                  return _buildSearchBar();
                }
                if (index == 4) {
                  return _buildFiltrosFila();
                }
                
                if (listaFiltrada.isEmpty && index == 5) {
                  return _buildEmptyState();
                }

                if (index - 5 < listaFiltrada.length) {
                  final mov = listaFiltrada[index - 5];
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Buscar por descripción o monto...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                }
              ) 
            : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFiltrosFila() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget buildChip(String label, String valor, IconData icon, Color color) {
      final seleccionado = _filtroSeleccionado == valor;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          avatar: Icon(
            icon, 
            color: seleccionado ? Colors.white : color.withValues(alpha: 0.8),
            size: 16
          ),
          label: Text(
            label,
            style: GoogleFonts.inter(
              color: seleccionado ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              fontSize: 12
            ),
          ),
          selected: seleccionado,
          selectedColor: color,
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
          onSelected: (bool selected) {
            if (selected) {
              setState(() {
                _filtroSeleccionado = valor;
              });
            }
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            buildChip('Todos', 'todos', Icons.grid_view, Theme.of(context).primaryColor),
            buildChip('Pagos', 'pagos', Icons.arrow_upward, ColoresApp.exito),
            buildChip('Gastos', 'gastos', Icons.arrow_downward, ColoresApp.error),
            buildChip('Aportes Extras', 'extras', Icons.star, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(ControladorFinanzas finanzas) {
    return RepaintBoundary(
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(-0.04)
          ..rotateX(0.02),
        alignment: FractionalOffset.center,
        child: Container(
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
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(5, 10),
            )
          ],
          // EFECTO PREMIUM: Borde interno sutil para simular volumen (Glassmorphism sutil)
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
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
                          child: const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 14),
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
                            child: const Icon(Icons.arrow_downward, color: Colors.redAccent, size: 14),
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
    ),
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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05), 
          width: 1,
        ),
        boxShadow: isDark ? [] : AppTokens.sombraSuave,
      ),
      child: Column(
        children: [
          Text(
            'Resumen de Gestión',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Theme.of(context).primaryColor,
            ),
          ),
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
      ),
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
    final esExtra  = mov['tipo'] == 'X';
    final esPositivo = esIngreso || esExtra;

    final colorIcono = esIngreso
        ? ColoresApp.exito
        : esExtra
            ? Colors.teal
            : ColoresApp.error;
    final colorFondoIcono = colorIcono.withValues(alpha: 0.12);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05), 
            width: 1,
          ),
          boxShadow: isDark ? [] : AppTokens.sombraSuave,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Barra vertical acentuada en la izquierda
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  color: colorIcono,
                ),
              ),
              Material(
                color: Colors.transparent, // Efecto Ripple correcto
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14).copyWith(left: 20),
                    child: Row(
                      children: [
                        // Icono circular
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorFondoIcono,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            esPositivo ? Icons.arrow_upward : Icons.arrow_downward, 
                            color: colorIcono,
                            size: 18
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov['descripcion'].toString().toCapitalized(), 
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                )
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormat.format(mov['fecha']),
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white70 : Colors.black54, 
                                  fontSize: 12,
                                )
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
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 10, color: Theme.of(context).primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Editar',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        )
                      ],
                    ),
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
