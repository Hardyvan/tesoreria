import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dsi/myPagesBack/b_logica_estado_financiero.dart';
import 'package:dsi/myPagesBack/a_logica_inicio_sesion.dart';
import 'package:dsi/myPagesBack/h_servicio_conectividad.dart';
import 'package:dsi/myPagesTema/b_ui_kit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
                                      Row(
                                        children: [
                                          if (p['comprobante_url'] != null && p['comprobante_url'].toString().trim().isNotEmpty) ...[
                                            InkWell(
                                              onTap: () => _mostrarComprobanteDialog(context, p['comprobante_url'].toString()),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                margin: const EdgeInsets.only(right: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: CachedNetworkImage(
                                                  imageUrl: p['comprobante_url'].toString(),
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => const Center(
                                                    child: SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => const Icon(
                                                    Icons.image_not_supported,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          Text(currencyFormat.format(p['monto']),
                                              style: const TextStyle(fontWeight: FontWeight.w500)),
                                        ],
                                      ),
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

  void _mostrarComprobanteDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long, color: Color(0xFF742284)),
                            SizedBox(width: 8),
                            Text(
                              'Comprobante de Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            placeholder: (context, url) => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade100,
                              padding: const EdgeInsets.all(32.0),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'No se pudo cargar la imagen',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                              // OK
                            } else {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('No se pudo abrir el enlace del comprobante')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Abrir en navegador'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarModalYape(BuildContext context, String actividad, double monto) {
    const numeroYape = '990292918'; 
    const titularYape = 'Ivan Velez Cruz';
    final currencyFormat = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final conexion = Provider.of<ServicioConectividad>(context, listen: false);
    final bool estaOnline = conexion.tieneConexion;

    final String emvcoString = _generarEMVCoYape(
      celular: numeroYape,
      nombre: titularYape,
      monto: monto,
      concepto: actividad,
    );

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
              const Expanded(child: Text('Pago con Yape / Plin', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escanea este QR desde otro cel o copia los datos:', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                
                // QR Dinámico (con autocompletado de monto)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: estaOnline
                      ? Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(emvcoString)}',
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFF742284)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/yape_qr.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/yape_qr.jpg',
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 12),
                const Text(titularYape, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF742284))),
                const Divider(height: 24),
                
                // Celular Destinatario (Con Copia)
                _construirFilaCopia(
                  label: 'Celular:',
                  value: numeroYape,
                  copyValue: numeroYape,
                  context: ctx,
                  color: const Color(0xFF742284),
                ),
                
                // Monto Exacto (Con Copia)
                _construirFilaCopia(
                  label: 'Monto a transferir:',
                  value: currencyFormat.format(monto),
                  copyValue: monto.toStringAsFixed(2),
                  context: ctx,
                  color: Colors.green,
                ),
                
                // Concepto / Actividad (Con Copia)
                _construirFilaCopia(
                  label: 'Concepto:',
                  value: actividad,
                  copyValue: actividad,
                  context: ctx,
                  color: Colors.blueGrey,
                  largeText: true,
                ),
                
                const SizedBox(height: 16),
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
                            'Una vez realizes el pago, envía la captura de pantalla por WhatsApp al administrador.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
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

  Widget _construirFilaCopia({
    required String label,
    required String value,
    required String copyValue,
    required BuildContext context,
    required Color color,
    bool largeText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: largeText ? 13 : 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: color.withValues(alpha: 0.7)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: copyValue));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copiado: $copyValue'),
                          backgroundColor: color,
                          duration: const Duration(seconds: 1),
                        )
                      );
                    }
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  int _calcularCRC16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      int byte = data.codeUnitAt(i);
      crc ^= (byte << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = crc << 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  String _generarEMVCoYape({
    required String celular,
    required String nombre,
    required double monto,
    required String concepto,
  }) {
    String emv = '000201';
    emv += '010212';
    
    String subtag00 = '0009pe.yape.app';
    String subtag01 = '0109$celular';
    String merchantInfo = subtag00 + subtag01;
    emv += '26${merchantInfo.length.toString().padLeft(2, '0')}$merchantInfo';
    
    emv += '52040000';
    emv += '5303604';
    
    String montoStr = monto.toStringAsFixed(2);
    emv += '54${montoStr.length.toString().padLeft(2, '0')}$montoStr';
    
    emv += '5802PE';
    
    String nombreSanitizado = nombre
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N');
    if (nombreSanitizado.length > 25) {
      nombreSanitizado = nombreSanitizado.substring(0, 25);
    }
    emv += '59${nombreSanitizado.length.toString().padLeft(2, '0')}$nombreSanitizado';
    
    emv += '6004Lima';
    
    String conceptoSanitizado = concepto
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll(' ', '_');
    if (conceptoSanitizado.length > 20) {
      conceptoSanitizado = conceptoSanitizado.substring(0, 20);
    }
    String subtag01Concepto = '01${conceptoSanitizado.length.toString().padLeft(2, '0')}$conceptoSanitizado';
    emv += '62${subtag01Concepto.length.toString().padLeft(2, '0')}$subtag01Concepto';

    emv += '6304';
    
    int crcVal = _calcularCRC16(emv);
    String crcHex = crcVal.toRadixString(16).toUpperCase().padLeft(4, '0');
    
    return emv + crcHex;
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
