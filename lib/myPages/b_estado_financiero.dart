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
  late Future<void> _futureDatos;

  @override
  void initState() {
    super.initState();
    _futureDatos = Future.delayed(Duration.zero, _cargarDatos);
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
    
    return FutureBuilder<void>(
        future: _futureDatos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _futureDatos = _cargarDatosForzado();
              });
              await _futureDatos;
            },
            child: ListView.builder(
              // Padding extendido para evitar que el FAB tape el último elemento
              padding: const EdgeInsets.only(
                top: DimensionesApp.paddingEstandar,
                bottom: 80, 
              ),
              itemCount: finanzas.listaDeudores.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return TermometroActividades(metas: finanzas.metasActividades, cargando: finanzas.cargando);
                }
                
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar, vertical: 8),
                    child: Text(
                      'Estado Financiero', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  );
                }

                final alumno = finanzas.listaDeudores[index - 2];
                final double? deuda = double.tryParse(alumno['deuda'].toString());
                final double montoDeuda = deuda ?? 0.0;
                final esDeudor = montoDeuda > 0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DimensionesApp.paddingEstandar,
                    vertical: 8,
                  ),
                  child: TarjetaPremium(
                    usaGradientePrimario: false, // <-- Card blanca y limpia
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    onTap: !esAdmin ? null : () async {
                      // Acción SOLO Admin: Registrar Pago para este alumno
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
                        // --- AVATAR CON COLORES PASTELES MODERNOS ---
                        AvatarUsuario(
                          nombre: alumno['nombre'],
                          fotoUrl: alumno['foto_url'],
                          radius: 26,
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          textColor: Theme.of(context).primaryColor, 
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumno['nombre'].toString().toCapitalized(), 
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Badge de estado moderno
                              BadgeEstado(
                                texto: esDeudor ? 'Debe S/ ${montoDeuda.toStringAsFixed(2)}' : 'Al día',
                                colorBase: esDeudor ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
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
        },
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

    final exito = await context.read<ControladorFinanzas>().registrarPago(pago, auth.usuarioActual!);

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
                    initialValue: _selectedUsuarioId,
                    items: usuarios.where((u) => u.rol != 'SuperAdmin').map((Usuario user) {
                      return DropdownMenuItem<int>(
                        value: user.id,
                        child: Text(user.nombre, overflow: TextOverflow.ellipsis),
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
                    initialValue: _selectedActividadId,
                    items: actividades.map((Actividad act) {
                      return DropdownMenuItem<int>(
                        value: act.id,
                        child: Text('${act.titulo} (S/ ${act.costo})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    validator: (value) => value == null ? 'Por favor seleccione una actividad' : null,
                    onChanged: (val) {
                      setState(() {
                        _selectedActividadId = val;
                        if (val != null) {
                           final act = actividades.firstWhere((a) => a.id == val);
                           _montoController.text = act.costo.toString();
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
                                '⚠️ Pago tardío: $diasAtraso días × S/ ${actSel.multaPorDia.toStringAsFixed(2)} = Multa S/ ${montoMulta.toStringAsFixed(2)}\nSe añadirá automáticamente al registrar.',
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
                    initialValue: _metodoPagoSeleccionado,
                    items: const [
                      DropdownMenuItem(value: 'Efectivo', child: Text('💵 Efectivo')),
                      DropdownMenuItem(value: 'Yape', child: Text('📱 Yape / Transferencia')),
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
    _montoCtrl = TextEditingController(text: widget.pago['monto'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Concepto: ${widget.pago['descripcion']}", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nuevo Monto',
              border: OutlineInputBorder(),
              prefixText: 'S/ ',
            ),
          ),
        ],
      ),
      actions: [
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
    );
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

    final exito = await finanzas.editarPago(widget.pago['id'], nuevoMonto, auth.usuarioActual!);

    if (mounted) {
      _guardando.value = false;
      Navigator.pop(context, exito); // Retornar true si hubo éxito
    }
  }
}
