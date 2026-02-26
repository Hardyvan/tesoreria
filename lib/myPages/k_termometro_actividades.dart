import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../myPagesTema/a_tema.dart';

class TermometroActividades extends StatelessWidget {
  final List<Map<String, dynamic>> metas;
  final bool cargando;

  const TermometroActividades({super.key, required this.metas, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (metas.isEmpty) {
      return const SizedBox.shrink(); // No hay actividades activas
    }

    // Aumentamos la altura para acomodar el nuevo diseño premium y evitar el overflow
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar),
        itemCount: metas.length,
        itemBuilder: (context, index) {
          final meta = metas[index];
          return _buildTarjetaPremium(context, meta, index == metas.length - 1);
        },
      ),
    );
  }

  Widget _buildTarjetaPremium(BuildContext context, Map<String, dynamic> meta, bool isLast) {
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    
    double porcentaje = meta['porcentaje_recaudacion'];
    double metaTotal = meta['meta_total'];
    double recaudado = meta['recaudado'];
    double gastos = meta['gastado'];
    double saldoDisponible = meta['saldo_disponible'];
    String titulo = meta['titulo'];
    
    bool metaCumplida = porcentaje >= 1.0;
    bool enDeficit = saldoDisponible < 0;

    return Container(
      width: 310,
      margin: EdgeInsets.only(right: isLast ? 0 : 20, bottom: 12, top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColoresApp.sombraSuave,
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
        gradient: metaCumplida 
          ? LinearGradient(
              colors: [ColoresApp.exito.withValues(alpha: 0.08), Theme.of(context).cardColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      ),
      child: Stack(
        children: [
          // Fondo decorativo sutil
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.trending_up,
              size: 120,
              color: metaCumplida 
                 ? ColoresApp.exito.withValues(alpha: 0.05)
                 : Theme.of(context).primaryColor.withValues(alpha: 0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cabecera: Título y Meta
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Valor Total: ${currencyFormat.format(metaTotal)}',
                            style: GoogleFonts.inter(fontSize: 12, color: ColoresApp.textoSecundarioClaro, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Centro: Progreso
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (porcentaje * 100).toStringAsFixed(0),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, 
                            fontSize: 32, 
                            color: metaCumplida ? ColoresApp.exito : Theme.of(context).primaryColor,
                            height: 1.0
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 2),
                          child: Text('%', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: ColoresApp.textoSecundarioClaro)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ColoresApp.secundario.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                            'Generado: ${currencyFormat.format(recaudado)}',
                            style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        color: metaCumplida ? ColoresApp.exito : ColoresApp.secundario,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
                
                // Pie: Chips modernos de Balance
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceChip(
                        titulo: 'Gastado',
                        monto: gastos,
                        esNegativo: true,
                        formato: currencyFormat
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceChip(
                        titulo: 'Caja Real',
                        monto: saldoDisponible,
                        esNegativo: enDeficit,
                        formato: currencyFormat
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip({required String titulo, required double monto, required bool esNegativo, required NumberFormat formato}) {
    final colorPrimario = esNegativo ? ColoresApp.error : ColoresApp.exito;
    final colorFondo = colorPrimario.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorPrimario.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GoogleFonts.inter(fontSize: 11, color: ColoresApp.textoOscuro.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            formato.format(monto), 
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: colorPrimario),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
