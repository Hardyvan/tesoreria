import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dsi/myPagesBack/b_logica_estado_financiero.dart';
import 'package:dsi/myPagesBack/a_logica_inicio_sesion.dart';
import 'package:dsi/myPagesTema/b_ui_kit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import '../myPagesTema/c_formatos.dart';

class HistorialPagos extends StatelessWidget {
  const HistorialPagos({super.key});

  @override
  Widget build(BuildContext context) {
    return const _VistaListadoUsuarios();
  }
}

class _VistaListadoUsuarios extends StatefulWidget {
  const _VistaListadoUsuarios();

  @override
  State<_VistaListadoUsuarios> createState() => _VistaListadoUsuariosState();
}

class _VistaListadoUsuariosState extends State<_VistaListadoUsuarios> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  String quitarAcentos(String texto) {
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
    final queryLimpio = quitarAcentos(_searchQuery.toLowerCase().trim());
    final palabrasBusqueda = queryLimpio.isEmpty ? <String>[] : queryLimpio.split(RegExp(r'\s+'));

    final deudoresFiltrados = palabrasBusqueda.isEmpty 
        ? finanzas.listaDeudores 
        : finanzas.listaDeudores.where((alumno) {
            final nombreCompleto = quitarAcentos(alumno['nombre'].toString().toLowerCase());
            return palabrasBusqueda.every((palabra) => nombreCompleto.contains(palabra));
          }).toList();

    final auth = context.watch<ControladorAuth>();
    final esAdmin = auth.usuarioActual?.rol == 'Admin' || auth.usuarioActual?.rol == 'SuperAdmin';

    return Column(
      children: [
        if (!esAdmin && auth.usuarioActual != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12).copyWith(bottom: 0),
            child: BotonGradiente(
              text: 'VER MIS PAGOS 💳',
              icon: Icons.person,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Mis Pagos', style: TextStyle(fontSize: 16)),
                      ),
                      body: VistaDetalleHistorialUsuario(
                        usuarioId: auth.usuarioActual!.id,
                        esVistaPersonal: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar alumno...',
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
        ),
        Expanded(
          child: finanzas.cargando && finanzas.listaDeudores.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 80),
                itemCount: deudoresFiltrados.length,
                separatorBuilder: (cx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alumno = deudoresFiltrados[index];
                  final double deuda = double.tryParse(alumno['deuda'].toString()) ?? 0.0;
                  final esDeudor = deuda > 0;
                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return TarjetaPremium(
                    usaGradientePrimario: false,
                    leftAccentColor: esDeudor ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: Text('Pagos: ${alumno['nombre'].toString().toCapitalized()}', style: const TextStyle(fontSize: 16))),
                            body: VistaDetalleHistorialUsuario(
                              usuarioId: alumno['id'],
                              esVistaPersonal: false,
                            ),
                          )
                        )
                      );
                    },
                    child: Row(
                      children: [
                        AvatarUsuario(
                          nombre: alumno['nombre'],
                          fotoUrl: alumno['foto_url'],
                          radius: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumno['nombre'].toString().toCapitalized(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_android,
                                    size: 11,
                                    color: (alumno['celular'] != null && alumno['celular'].toString().isNotEmpty)
                                        ? (isDark ? Colors.white54 : Colors.black45)
                                        : Colors.orange.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (alumno['celular'] != null && alumno['celular'].toString().isNotEmpty)
                                        ? alumno['celular'].toString()
                                        : 'Sin celular',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (alumno['celular'] != null && alumno['celular'].toString().isNotEmpty)
                                          ? (isDark ? Colors.white54 : Colors.black54)
                                          : Colors.orange.withValues(alpha: 0.8),
                                      fontFamily: 'Inter',
                                      fontStyle: (alumno['celular'] != null && alumno['celular'].toString().isNotEmpty)
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              BadgeEstado(
                                texto: esDeudor ? 'Debe ${deuda.toSoles()}' : 'Al día',
                                colorBase: esDeudor ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}


class VistaDetalleHistorialUsuario extends StatefulWidget {
  final int usuarioId;
  final bool esVistaPersonal;

  const VistaDetalleHistorialUsuario({
    super.key,
    required this.usuarioId,
    required this.esVistaPersonal,
  });

  @override
  State<VistaDetalleHistorialUsuario> createState() => VistaDetalleHistorialUsuarioState();
}

class VistaDetalleHistorialUsuarioState extends State<VistaDetalleHistorialUsuario> {
  late Future<List<Map<String, dynamic>>> _futureHistorial;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() {
    final finanzas = context.read<ControladorFinanzas>();
    _futureHistorial = finanzas.obtenerDetallePagosPorActividad(widget.usuarioId);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    return RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _futureHistorial = context.read<ControladorFinanzas>()
                .obtenerDetallePagosPorActividad(widget.usuarioId, forceRefresh: true);
          });
          await _futureHistorial;
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
                final saldo = estado == 'Exonerado' ? 0.0 : costo - pagado;

                Color colorEstado;
                switch (estado) {
                  case 'Completo':
                    colorEstado = Colors.green;
                    break;
                  case 'Parcial':
                    colorEstado = Colors.orange;
                    break;
                  case 'Exonerado':
                    colorEstado = Colors.blue;
                    break;
                  default:
                    colorEstado = Colors.red;
                }

                return RepaintBoundary(
                  child: TarjetaPremium(
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: colorEstado.withValues(alpha: 0.1),
                        child: Icon(
                          estado == 'Completo' ? Icons.check : (estado == 'Exonerado' ? Icons.info_outline : Icons.access_time),
                          color: colorEstado,
                        ),
                      ),
                      title: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        estado == 'Exonerado'
                            ? 'Exonerado (Sin Deuda)'
                            : 'Pagado: ${currencyFormat.format(pagado)} / ${currencyFormat.format(costo)}',
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
                                      Row(
                                        children: [
                                          Text(dateFormat.format(DateTime.tryParse(p['fecha'].toString()) ?? DateTime.now())),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: p['metodo_pago'] == 'Yape' ? const Color(0xFF742284).withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p['metodo_pago']?.toString() ?? 'Efectivo',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: p['metodo_pago'] == 'Yape' ? const Color(0xFF742284) : Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                              label: Text(widget.esVistaPersonal ? 'Pagar con Yape' : 'Ver QR Yape',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  ),
                );
              },
            );
          },
        ),
    );
  }

  Future<void> _abrirWhatsApp() async {
    const String numero = '51990292918'; 
    final mensaje = widget.esVistaPersonal ? 'Hola, tengo una consulta sobre mis pagos.' : 'Hola, te escribo como administrador del aula respecto a tus pagos.';
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
              Text(widget.esVistaPersonal ? 'Pagar ${currencyFormat.format(monto)}' : 'Deuda de ${currencyFormat.format(monto)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('por concepto de:', style: TextStyle(color: Colors.grey)),
              Text(actividad, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              
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
              
              if (widget.esVistaPersonal)
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
            if (widget.esVistaPersonal)
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
          Text('No hay pagos registrados.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
