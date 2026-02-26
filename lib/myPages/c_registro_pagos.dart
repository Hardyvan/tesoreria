import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../myPagesBack/d_controlador_usuarios.dart';
import '../../myPagesBack/c_controlador_actividades.dart';
import '../../myPagesBack/b_controlador_finanzas.dart';
import '../../myPagesBack/a_controlador_auth.dart';
import '../../myPagesBack/modelo_usuario.dart';
import '../../myPagesBack/modelo_actividad.dart';
import '../../myPagesBack/modelo_pago.dart';
import '../../myPagesTema/a_tema.dart';
import '../../myPagesTema/c_ui_kit.dart';

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
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

    final pago = Pago(
      id: 0, 
      usuarioId: _selectedUsuarioId!, 
      actividadId: _selectedActividadId!, 
      montoPagado: monto, 
      fechaPago: DateTime.now(), 
      confirmado: true
    );

    final auth = context.read<ControladorAuth>();
    if (auth.usuarioActual == null) {
      setState(() => _isLoading = false);
      return;
    }

    final exito = await context.read<ControladorFinanzas>().registrarPago(pago, auth.usuarioActual!);

    if (mounted) {
      setState(() => _isLoading = false);
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
                  
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    BotonGradiente(
                      text: 'REGISTRAR PAGO',
                      icon: Icons.check_circle,
                      onPressed: _guardarPago,
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
