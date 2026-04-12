import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesTema/b_ui_kit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';


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
        title: const Text('Mis Pagos y Ayuda'),
        actions: const [BannerSinConexion()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final usuario = context.read<ControladorAuth>().usuarioActual;
          if (usuario != null) {
            setState(() {
              _futureHistorial = context.read<ControladorFinanzas>()
                  .obtenerDetallePagosPorActividad(usuario.id, forceRefresh: true);
            });
            await _futureHistorial;
          }
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureHistorial,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  _VistaVacia(),
                ],
              );
            }

            final actividades = snapshot.data!;

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
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
                  case 'Completo':
                    colorEstado = Colors.green;
                    break;
                  case 'Parcial':
                    colorEstado = Colors.orange;
                    break;
                  default:
                    colorEstado = Colors.red;
                }

                return TarjetaPremium(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: colorEstado.withValues(alpha: 0.1),
                      child: Icon(
                        estado == 'Completo' ? Icons.check : Icons.access_time,
                        color: colorEstado,
                      ),
                    ),
                    title: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Pagado: ${currencyFormat.format(pagado)} / ${currencyFormat.format(costo)}',
                      style: TextStyle(color: colorEstado),
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      if (pagos.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Historial de Abonos:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        ...pagos.map((p) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateFormat.format(p['fecha'])),
                                    Text(currencyFormat.format(p['monto']),
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                if (p['multa'] != null && p['multa'] > 0)
                                  Text(
                                    'Incluye mora: ${currencyFormat.format(p['multa'])}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                                  ),
                                const SizedBox(height: 4),
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
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (saldo > 0) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostrarModalYape(context, item['titulo'], saldo),
                            icon: const FaIcon(FontAwesomeIcons.mobileScreen, color: Colors.white, size: 18),
                            label: const Text('Pagar con Yape',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF742284), // Morado Yape
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_whatsapp',
        onPressed: _abrirWhatsApp,
        backgroundColor: const Color(0xFF25D366), // Color oficial de WhatsApp
        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
        label: const Text('Consultar Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _mostrarModalYape(BuildContext context, String actividad, double monto) {
    // Número a nombre del tesorero.
    const numeroYape = '990292918'; 
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFF742284), shape: BoxShape.circle),
                child: const FaIcon(FontAwesomeIcons.mobileScreen, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Depósito Yape', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pagar ${currencyFormat.format(monto)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('por concepto de:', style: TextStyle(color: Colors.grey)),
              Text(actividad, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              
              // Código QR Real
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/yape_qr.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Ivan Giovany Velez Cruz', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('O deposita al número:', style: TextStyle(fontWeight: FontWeight.w500)),
              
              // Botón de Copiar
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF742284).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: numeroYape));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Número copiado al portapapeles'), 
                          backgroundColor: Color(0xFF742284),
                          duration: Duration(seconds: 2),
                        )
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(numeroYape, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF742284))),
                        const SizedBox(width: 16),
                        Icon(Icons.copy, color: const Color(0xFF742284).withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Instrucción Final
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Una vez realizes el pago, envía la captura pantalla por WhatsApp al administrador.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _abrirWhatsApp();
              },
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.white),
              label: const Text('Enviar Captura', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            ),
          ],
        );
      }
    );
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
