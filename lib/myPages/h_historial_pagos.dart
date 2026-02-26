import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../myPagesBack/b_controlador_finanzas.dart';
import '../myPagesBack/a_controlador_auth.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/c_ui_kit.dart';
import '../../globals.dart';

class HistorialPagos extends StatefulWidget {
  const HistorialPagos({super.key});

  @override
  State<HistorialPagos> createState() => _HistorialPagosState();
}

class _HistorialPagosState extends State<HistorialPagos> {
  late Future<List<Map<String, dynamic>>> _futureHistorial;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() {
    final usuario = context.read<ControladorAuth>().usuarioActual;
    final finanzas = context.read<ControladorFinanzas>();
    
    if (usuario != null) {
      _futureHistorial = finanzas.obtenerDetallePagosPorActividad(usuario.id);
    } else {
      _futureHistorial = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pagos Detallados'),
        actions: const [ BannerSinConexion() ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureHistorial,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _VistaVacia();
          }

          final actividades = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
            itemCount: actividades.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = actividades[index];
              final pagos = item['pagos'] as List<Map<String, dynamic>>;
              final estado = item['estado'];
              final costo = item['costo'];
              final pagado = item['total_pagado'];
              final saldo = costo - pagado;

              Color colorEstado;
              switch (estado) {
                case 'Completo': colorEstado = Colors.green; break;
                case 'Parcial': colorEstado = Colors.orange; break;
                default: colorEstado = Colors.red;
              }

              return TarjetaPremium(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: colorEstado.withValues(alpha: 0.1),
                    child: Icon(
                      estado == 'Completo' ? Icons.check : Icons.access_time, 
                      color: colorEstado
                    ),
                  ),
                  title: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Pagado: ${currencyFormat.format(pagado)} / ${currencyFormat.format(costo)}',
                    style: TextStyle(color: colorEstado)
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    if (pagos.isNotEmpty) ...[
                       const Align(
                         alignment: Alignment.centerLeft, 
                         child: Text('Historial de Abonos:', style: TextStyle(fontWeight: FontWeight.bold))
                       ),
                       const SizedBox(height: 8),
                       ...pagos.map((p) => Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(dateFormat.format(p['fecha'])),
                           Text(currencyFormat.format(p['monto']), style: const TextStyle(fontWeight: FontWeight.w500)),
                         ],
                       )),
                       const Divider(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Pendiente:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          currencyFormat.format(saldo > 0 ? saldo : 0), 
                          style: TextStyle(
                            color: saldo > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirWhatsApp,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text('Consultar Admin', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _abrirWhatsApp() async {
    const String numero = '51990292918'; // Código país + número
    const mensaje = 'Hola, tengo una consulta sobre mis pagos.';
    final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error lanzando URL: $e');
    }
  }
}

class _VistaVacia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No tienes pagos registrados.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
