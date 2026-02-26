import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../myPagesBack/b_controlador_finanzas.dart';
import '../../myPagesBack/modelo_gasto.dart';
import '../../myPagesBack/a_controlador_auth.dart';
import '../../myPagesTema/a_tema.dart';
import '../../myPagesTema/c_ui_kit.dart';

class RegistroGastos extends StatefulWidget {
  const RegistroGastos({super.key});

  @override
  State<RegistroGastos> createState() => _RegistroGastosState();
}

class _RegistroGastosState extends State<RegistroGastos> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  
  List<Map<String, dynamic>> _actividades = [];
  int? _actividadSeleccionadaId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  Future<void> _cargarActividades() async {
    final acts = await context.read<ControladorFinanzas>().obtenerActividadesSimplificadas();
    if (mounted) {
      setState(() {
        _actividades = acts;
      });
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _guardarGasto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto inválido'), backgroundColor: ColoresApp.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final auth = context.read<ControladorAuth>();
    if (auth.usuarioActual == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final adminId = auth.usuarioActual!.id;

    final gasto = Gasto(
      id: 0, 
      descripcion: _descripcionController.text.trim(), 
      monto: monto, 
      fechaGasto: DateTime.now(), 
      usuarioId: adminId,
      actividadId: _actividadSeleccionadaId
    );

    final exito = await context.read<ControladorFinanzas>().registrarGasto(gasto, auth.usuarioActual!);

    if (mounted) {
      setState(() => _isLoading = false);
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto registrado correctamente'), backgroundColor: ColoresApp.exito),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al registrar gasto'), backgroundColor: ColoresApp.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Gasto')),
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
                  const Icon(Icons.money_off, size: 60, color: ColoresApp.error),
                  const SizedBox(height: 16),
                  Text(
                    'Nueva Salida',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registra los detalles del gasto a continuación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del Gasto *',
                      hintText: 'Ej. Compra de suministros',
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa una descripción';
                      }
                      return null;
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
                      labelText: 'Monto Total (S/) *',
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

                  // Actividad
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Asociar a Actividad (Opcional)',
                      prefixIcon: Icon(Icons.event),
                      helperText: 'Útil para reportes de utilidad por evento'
                    ),
                    isExpanded: true,
                    initialValue: _actividadSeleccionadaId,
                    items: _actividades.map((act) {
                      return DropdownMenuItem<int>(
                        value: act['id'],
                        child: Text(
                          act['titulo'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _actividadSeleccionadaId = val),
                  ),
                  
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    BotonGradiente(
                      text: 'GUARDAR SALIDA',
                      icon: Icons.save,
                      onPressed: _guardarGasto,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
