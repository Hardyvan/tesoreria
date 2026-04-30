import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../myPagesBack/b_logica_estado_financiero.dart';
import '../../myPagesBack/a_logica_inicio_sesion.dart';
import '../../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesTema/e_termometro.dart';
import '../myPagesTema/c_formatos.dart'; // Import Added
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../myPagesBack/f_logica_perfil.dart';
import '../../myPagesBack/e_logica_actividades.dart';
import '../../myPagesBack/modelo_usuario.dart';
import '../../myPagesBack/modelo_actividad.dart';
import '../../myPagesBack/modelo_pago.dart';

class ListaDeudores extends StatefulWidget {
  const ListaDeudores({super.key});

  @override
  State<ListaDeudores> createState() => _ListaDeudoresState();
}

class _ListaDeudoresState extends State<ListaDeudores> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _cargarDatos);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final finanzas = context.read<ControladorFinanzas>();
    if (finanzas.listaDeudores.isEmpty || finanzas.metasActividades.isEmpty) {
      await Future.wait([
        finanzas.obtenerMetasActividades(),
        finanzas.obtenerReporteDeudores(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<ControladorFinanzas>();
    final esAdmin = context.read<ControladorAuth>().esAdmin;
    final proveedorTema = context.watch<ProveedorTema>();
    
    final bool esModoOscuro = proveedorTema.modoTema == ThemeMode.dark || 
                             (proveedorTema.modoTema == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final Color colorPrimarioBase = proveedorTema.colorTema;
    
    // Helper temporal para quitar acentos
    String quitarAcentos(String texto) {
      const conAcento = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
      const sinAcento = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
      String res = texto;
      for (int i = 0; i < conAcento.length; i++) {
        res = res.replaceAll(conAcento[i], sinAcento[i]);
      }
      return res;
    }

    final queryLimpio = quitarAcentos(_searchQuery.toLowerCase().trim());
    final palabrasBusqueda = queryLimpio.isEmpty ? <String>[] : queryLimpio.split(RegExp(r'\s+'));

    final deudoresFiltrados = palabrasBusqueda.isEmpty 
        ? finanzas.listaDeudores 
        : finanzas.listaDeudores.where((alumno) {
            final nombreCompleto = quitarAcentos(alumno['nombre'].toString().toLowerCase());
            // Verifica que TODAS las palabras ingresadas existan en alguna parte del nombre
            return palabrasBusqueda.every((palabra) => nombreCompleto.contains(palabra));
          }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _cargarDatosForzado();
      },
      child: finanzas.cargando && finanzas.listaDeudores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(
                top: DimensionesApp.paddingEstandar,
                bottom: 80, 
              ),
              itemCount: deudoresFiltrados.length + 3,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return TermometroActividades(metas: finanzas.metasActividades, cargando: finanzas.cargando);
                }
                
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar, vertical: 8).copyWith(bottom: 0),
                    child: Text(
                      'Estado Financiero', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: esModoOscuro ? Colors.white : colorPrimarioBase,
                      )
                    ),
                  );
                }

                if (index == 2) {
                   return Padding(
                     padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar, vertical: 12),
                     child: TextField(
                       controller: _searchCtrl,
                       onChanged: (val) {
                         setState(() {
                           _searchQuery = val;
                         });
                       },
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
                         border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(16),
                           borderSide: BorderSide.none,
                         ),
                       ),
                     )
                   );
                }

                final alumno = deudoresFiltrados[index - 3];
                final double? deuda = double.tryParse(alumno['deuda'].toString());
                final double montoDeuda = deuda ?? 0.0;
                final esDeudor = montoDeuda > 0;
                
                final Color colorAvatar = esModoOscuro ? Colors.white : colorPrimarioBase;
                final Color adaptiveTextColor = esModoOscuro ? Colors.white : Colors.black87;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DimensionesApp.paddingEstandar,
                    vertical: 8,
                  ),
                  child: TarjetaPremium(
                    usaGradientePrimario: false,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    onTap: !esAdmin ? null : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistroPagos(usuarioPreseleccionado: alumno['id'])
                        )
                      );
                      if (context.mounted) {
                        unawaited(context.read<ControladorFinanzas>().obtenerMetasActividades());
                        unawaited(context.read<ControladorFinanzas>().obtenerReporteDeudores());
                      }
                    },
                    child: Row(
                      children: [
                        AvatarUsuario(
                          nombre: alumno['nombre'],
                          fotoUrl: alumno['foto_url'],
                          radius: 26,
                          backgroundColor: colorAvatar.withValues(alpha: 0.1),
                          textColor: colorAvatar, 
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumno['nombre'].toString().toCapitalized(), 
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: adaptiveTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              BadgeEstado(
                                texto: esDeudor ? 'Debe ${montoDeuda.toSoles()}' : 'Al día',
                                colorBase: esDeudor ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
                        ),
                        if (esDeudor && esAdmin)
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 28),
                            onPressed: () async {
                               final telefono = alumno['celular']?.toString() ?? '';
                               if (telefono.isEmpty || telefono.length < 9) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El alumno no tiene un número válido registrado.')));
                                  return;
                               }
                               final numero = telefono.startsWith('51') ? telefono : '51$telefono';
                               final mensaje = 'Hola ${alumno['nombre']}, te escribe la tesorería del salón. Recuerda que tienes un saldo pendiente de ${montoDeuda.toSoles()}. Por favor, regulariza tu pago lo antes posible.';
                               final uri = Uri.parse('whatsapp://send?phone=$numero&text=${Uri.encodeComponent(mensaje)}');
                               if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                               } else {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
                               }
                            },
                          ),
                        if (esAdmin) 
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios, 
                              size: 14, 
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white54 
                                  : Colors.black38
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _cargarDatosForzado() async {
    final finanzas = context.read<ControladorFinanzas>();
    await Future.wait([
      finanzas.obtenerMetasActividades(),
      finanzas.obtenerReporteDeudores(),
    ]);
  }

}

class RegistroPagos extends StatefulWidget {
  final int? usuarioPreseleccionado;
  const RegistroPagos({super.key, this.usuarioPreseleccionado});

  @override
  State<RegistroPagos> createState() => _RegistroPagosState();
}

class _RegistroPagosState extends State<RegistroPagos> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedUsuarioId;
  int? _selectedActividadId;
  final TextEditingController _montoController = TextEditingController();
  String _metodoPagoSeleccionado = 'Efectivo';
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _selectedUsuarioId = widget.usuarioPreseleccionado;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControladorUsuarios>().listarUsuarios();
      context.read<ControladorActividades>().listarActividades();
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _guardarPago() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto válido'), backgroundColor: ColoresApp.error),
      );
      return;
    }

    _isLoading.value = true;

    final pago = Pago(
      id: 0, 
      usuarioId: _selectedUsuarioId!, 
      actividadId: _selectedActividadId!, 
      montoPagado: monto, 
      fechaPago: DateTime.now(), 
      confirmado: true,
      metodoPago: _metodoPagoSeleccionado
    );

    final auth = context.read<ControladorAuth>();
    if (auth.usuarioActual == null) {
      _isLoading.value = false;
      return;
    }

    final usuarios = context.read<ControladorUsuarios>().usuarios;
    final nombreAlumno = usuarios.firstWhere(
      (u) => u.id == _selectedUsuarioId,
      orElse: () => Usuario(id: 0, nombre: 'Alumno', celular: '', email: '', fotoUrl: '', rol: ''),
    ).nombre;
    final exito = await context.read<ControladorFinanzas>().registrarPago(pago, auth.usuarioActual!, nombreAlumno: nombreAlumno);

    if (mounted) {
      _isLoading.value = false;
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado correctamente'), backgroundColor: ColoresApp.exito),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al registrar el pago'), backgroundColor: ColoresApp.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = context.watch<ControladorUsuarios>().usuarios;
    final actividades = context.watch<ControladorActividades>().actividades;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Pago')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: TarjetaPremium(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.payments, size: 60, color: ColoresApp.exito),
                  const SizedBox(height: 16),
                  Text(
                    'Nuevo Ingreso',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registra el pago de un alumno a continuación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30),

                  // Alumno
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccione Alumno *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    initialValue: _selectedUsuarioId,
                    items: usuarios.where((u) => u.rol != 'SuperAdmin').map((Usuario user) {
                      return DropdownMenuItem<int>(
                        value: user.id,
                        child: Row(
                          children: [
                            AvatarUsuario(nombre: user.nombre, radius: 14),
                            const SizedBox(width: 12),
                            Expanded(child: Text(user.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (value) => value == null ? 'Por favor seleccione un alumno' : null,
                    onChanged: (val) {
                      setState(() => _selectedUsuarioId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Actividad
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccione Actividad *',
                      prefixIcon: Icon(Icons.event_note),
                    ),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    initialValue: _selectedActividadId,
                    items: actividades.map((Actividad act) {
                      return DropdownMenuItem<int>(
                        value: act.id,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.event, size: 16, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${act.titulo} (${act.costo.toSoles()})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (value) => value == null ? 'Por favor seleccione una actividad' : null,
                    onChanged: (val) {
                      setState(() {
                        _selectedActividadId = val;
                        if (val != null) {
                           final act = actividades.firstWhere((a) => a.id == val);
                           _montoController.text = act.costo.toStringAsFixed(2);
                        }
                      });
                    },
                  ),

                  // Banner de multa si la actividad tiene fecha_limite vencida
                  if (_selectedActividadId != null) ...[  
                    Builder(builder: (ctx) {
                      final actSel = actividades.firstWhere((a) => a.id == _selectedActividadId, orElse: () => actividades.first);
                      if (actSel.fechaLimite == null || actSel.multaPorDia <= 0) return const SizedBox.shrink();
                      final hoy = DateTime.now();
                      final diasAtraso = hoy.difference(actSel.fechaLimite!).inDays;
                      if (diasAtraso <= 0) return const SizedBox.shrink();
                      final montoMulta = diasAtraso * actSel.multaPorDia;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Pago tardío: $diasAtraso días × ${actSel.multaPorDia.toSoles()} = Mora ${montoMulta.toSoles()}\nSe añadirá automáticamente al registrar.',
                                style: const TextStyle(color: Colors.deepOrange, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // Monto
                  TextFormField(
                    controller: _montoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monto Recibido (S/) *',
                      hintText: '0.00',
                      prefixText: 'S/ ',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el monto';
                      }
                      final val = double.tryParse(value);
                      if (val == null || val <= 0) {
                        return 'Ingresa un monto válido mayor a 0';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Selector de Método de Pago
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      prefixIcon: Icon(Icons.wallet),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    initialValue: _metodoPagoSeleccionado,
                    items: const [
                      DropdownMenuItem(value: 'Efectivo', child: Text('💵  Efectivo', style: TextStyle(fontWeight: FontWeight.w500))),
                      DropdownMenuItem(value: 'Yape', child: Text('📱  Yape / Transferencia', style: TextStyle(fontWeight: FontWeight.w500))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _metodoPagoSeleccionado = val);
                    },
                  ),

                  const SizedBox(height: 32),

                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoading,
                    builder: (context, isLoading, child) {
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return BotonGradiente(
                        text: 'REGISTRAR PAGO',
                        icon: Icons.check_circle,
                        onPressed: _guardarPago,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class EditarPago extends StatefulWidget {
  final Map<String, dynamic> pago; // {id, descripcion, monto, fecha, ...}

  const EditarPago({super.key, required this.pago});

  @override
  State<EditarPago> createState() => _EditarPagoState();
}

class _EditarPagoState extends State<EditarPago> {
  late TextEditingController _montoCtrl;
  final ValueNotifier<bool> _guardando = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: (widget.pago['monto'] as num).toDouble().toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    String tipoMov = widget.pago['tipo'] ?? 'I';
    String etiqTipo = tipoMov == 'I' ? 'Pago' : (tipoMov == 'E' ? 'Gasto' : 'Ingreso Extra');

    return AlertDialog(
      title: Text('Editar $etiqTipo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Concepto: ${widget.pago['descripcion']}", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Nuevo Monto',
              border: OutlineInputBorder(),
              prefixText: 'S/ ',
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _guardando,
          builder: (context, guardando, child) {
            return TextButton.icon(
              onPressed: guardando ? null : _eliminarPago,
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              label: const Text('Anular', style: TextStyle(color: Colors.red)),
            );
          }
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _guardando,
              builder: (context, guardando, child) {
                return ElevatedButton(
                  onPressed: guardando ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  child: guardando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar', style: TextStyle(color: Colors.white)),
                );
              }
            ),
          ],
        )
      ],
    );
  }

  Future<void> _eliminarPago() async {
    final auth = context.read<ControladorAuth>();
    final finanzas = context.read<ControladorFinanzas>();

    if (auth.usuarioActual == null) return;

    String tipoMov = widget.pago['tipo'] ?? 'I';
    String etiqTipo = tipoMov == 'I' ? 'Pago' : (tipoMov == 'E' ? 'Gasto' : 'Ingreso Extra');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Anular registro de $etiqTipo?'),
        content: Text(
          tipoMov == 'I' 
            ? 'Esta acción eliminará el registro monetario del sistema permanentemente.\n\nSe enviará una notificación push instantánea al alumno informándole que este pago fue anulado de su estado de cuenta.'
            : 'Esta acción eliminará el registro de este $etiqTipo del balance financiero y se guardará el rastro en el registro de auditoría. ¿Continuar?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mantener')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text('Sí, Anular $etiqTipo', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirmar != true) return;

    _guardando.value = true;
    int pagoId = int.tryParse((widget.pago['id_movimiento'] ?? widget.pago['id']).toString()) ?? 0;
    final exito = await finanzas.eliminarMovimiento(tipoMov, pagoId, auth.usuarioActual!);

    if (mounted) {
      _guardando.value = false;
      if (exito) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$etiqTipo anulado correctamente.'), backgroundColor: Colors.green));
         Navigator.pop(context, true); // true actualiza la tabla inferior
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hubo un error al intentar anular el registro.'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _guardarCambios() async {
    final nuevoMonto = double.tryParse(_montoCtrl.text);
    if (nuevoMonto == null || nuevoMonto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser válido y mayor a 0'), backgroundColor: Colors.red),
      );
      return;
    }

    _guardando.value = true;

    final auth = context.read<ControladorAuth>();
    final finanzas = context.read<ControladorFinanzas>();

    // Usar usuarioActual! con seguridad porque Edit solo es para Admin logueado
    if (auth.usuarioActual == null) {
       Navigator.pop(context);
       return;
    }

    int pagoId = int.tryParse((widget.pago['id_movimiento'] ?? widget.pago['id']).toString()) ?? 0;
    String tipoMov = widget.pago['tipo'] ?? 'I';
    final exito = await finanzas.editarMovimiento(tipoMov, pagoId, nuevoMonto, auth.usuarioActual!);

    if (mounted) {
      _guardando.value = false;
      Navigator.pop(context, exito); // Retornar true si hubo éxito
    }
  }
}
