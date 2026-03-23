import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/e_logica_actividades.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesTema/a_tema.dart';
import 'package:flutter/services.dart';
import '../../myPagesBack/b_logica_estado_financiero.dart';
import '../../myPagesBack/modelo_gasto.dart';
import '../myPagesTema/b_ui_kit.dart';

class GestionActividades extends StatefulWidget {
  const GestionActividades({super.key});

  @override
  State<GestionActividades> createState() => _GestionActividadesState();
}

class _GestionActividadesState extends State<GestionActividades> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControladorActividades>().listarActividades();
    });
  }

  void _mostrarDialogoEditar(BuildContext context, actividad) {
    final ctrlTitulo = TextEditingController(text: actividad.titulo);
    final ctrlCosto = TextEditingController(text: actividad.costo.toString());
    final ctrlMulta = TextEditingController(text: actividad.multaPorDia > 0 ? actividad.multaPorDia.toString() : '');
    DateTime? fechaLimiteSeleccionada = actividad.fechaLimite;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Editar Actividad'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: ctrlTitulo,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ctrlCosto,
                    decoration: const InputDecoration(labelText: 'Costo por Alumno', prefixText: 'S/ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Multa por Atraso (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(height: 8),
                  // Selector de Fecha Límite
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: fechaLimiteSeleccionada ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setStateDialog(() => fechaLimiteSeleccionada = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Fecha Límite de Pago', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(
                        fechaLimiteSeleccionada != null
                          ? '${fechaLimiteSeleccionada!.day.toString().padLeft(2,'0')}/${fechaLimiteSeleccionada!.month.toString().padLeft(2,'0')}/${fechaLimiteSeleccionada!.year}'
                          : 'Sin fecha límite',
                        style: TextStyle(color: fechaLimiteSeleccionada != null ? null : Colors.grey),
                      ),
                    ),
                  ),
                  if (fechaLimiteSeleccionada != null) ...[  
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: ctrlMulta,
                      decoration: const InputDecoration(labelText: 'Multa por día vencido', prefixText: 'S/ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final auth = context.read<ControladorAuth>();
                  final ctrl = context.read<ControladorActividades>();
                  final costoNuevo = double.tryParse(ctrlCosto.text) ?? 0;
                  final multaNueva = double.tryParse(ctrlMulta.text) ?? 0.0;
                  
                  final exito = await ctrl.editarActividad(
                    actividad.id, ctrlTitulo.text, costoNuevo, auth.usuarioActual!,
                    fechaLimite: fechaLimiteSeleccionada,
                    multaPorDia: multaNueva,
                  );
                  if (exito && context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad actualizada')));
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al editar'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _confirmarBorrado(BuildContext context, int id, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Actividad'),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente "$titulo"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final auth = context.read<ControladorAuth>();
              final error = await context.read<ControladorActividades>().eliminarActividad(id, auth.usuarioActual!);
              if (context.mounted) {
                Navigator.pop(ctx);
                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad eliminada')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Actividades')),
      body: Consumer<ControladorActividades>(
        builder: (context, ctrl, _) {
          if (ctrl.cargando && ctrl.actividades.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.actividades.isEmpty) {
            return const Center(child: Text('No hay actividades registradas.'));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
            itemCount: ctrl.actividades.length,
            itemBuilder: (ctx, index) {
              final actividad = ctrl.actividades[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.assessment, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Costo: S/ ${actividad.costo.toStringAsFixed(2)}'),
                      if (actividad.fechaLimite != null)
                        Text(
                          '⚠️ Límite: ${actividad.fechaLimite!.day.toString().padLeft(2,'0')}/${actividad.fechaLimite!.month.toString().padLeft(2,'0')}/${actividad.fechaLimite!.year}  •  Multa: S/ ${actividad.multaPorDia.toStringAsFixed(2)}/día',
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                    ],
                  ),
                  isThreeLine: actividad.fechaLimite != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                        onPressed: () => _mostrarDialogoEditar(context, actividad),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmarBorrado(context, actividad.id, actividad.titulo),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_actividad',
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearActividad())),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVA ACTIVIDAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

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
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

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

    _isLoading.value = true;
    
    final auth = context.read<ControladorAuth>();
    if (auth.usuarioActual == null) {
      _isLoading.value = false;
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
      _isLoading.value = false;
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

                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoading,
                    builder: (context, isLoading, child) {
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return BotonGradiente(
                        text: 'GUARDAR SALIDA',
                        icon: Icons.save,
                        onPressed: _guardarGasto,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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


class CrearActividad extends StatefulWidget {
  const CrearActividad({super.key});

  @override
  State<CrearActividad> createState() => _CrearActividadState();
}

class _CrearActividadState extends State<CrearActividad> {
  final _ctrlTitulo = TextEditingController();
  final _ctrlCosto = TextEditingController();
  final _ctrlMulta = TextEditingController();
  DateTime? _fechaLimiteSeleccionada;

  Future<void> _guardar() async {
    final ctrl = Provider.of<ControladorActividades>(context, listen: false);
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final costo = double.tryParse(_ctrlCosto.text) ?? 0.0;
    final multa = double.tryParse(_ctrlMulta.text) ?? 0.0;
    
    if (auth.usuarioActual == null) return;

    final exito = await ctrl.crearActividad(
      _ctrlTitulo.text, costo, auth.usuarioActual!,
      fechaLimite: _fechaLimiteSeleccionada,
      multaPorDia: multa,
    );
    
    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad Creada')));
      Navigator.pop(context); // Volver si se navegó aquí
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Actividad')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/logo/DSI.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                     return Icon(Icons.business, size: 50, color: Theme.of(context).primaryColor);
                  },
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Nueva Gestión',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea una nueva actividad para empezar\na registrar pagos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              CampoTextoPersonalizado(
                label: 'Título (Ej: Pollada Pro-Fondos)',
                prefixIcon: Icons.title,
                controller: _ctrlTitulo,
              ),
              const SizedBox(height: 20),
              CampoTextoPersonalizado(
                label: 'Costo General',
                prefixText: 'S/ ',
                controller: _ctrlCosto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Multa por Atraso (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(height: 12),
              // Selector de Fecha
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimiteSeleccionada ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setState(() => _fechaLimiteSeleccionada = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha Límite de Pago', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(
                    _fechaLimiteSeleccionada != null
                      ? '${_fechaLimiteSeleccionada!.day.toString().padLeft(2,'0')}/${_fechaLimiteSeleccionada!.month.toString().padLeft(2,'0')}/${_fechaLimiteSeleccionada!.year}'
                      : 'Sin fecha límite',
                    style: TextStyle(color: _fechaLimiteSeleccionada != null ? null : Colors.grey),
                  ),
                ),
              ),
              if (_fechaLimiteSeleccionada != null) ...[  
                const SizedBox(height: 20),
                CampoTextoPersonalizado(
                  label: 'Multa por día vencido',
                  prefixText: 'S/ ',
                  controller: _ctrlMulta,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 40),
              Consumer<ControladorActividades>(
                builder: (context, ctrl, _) {
                  return BotonGradiente(
                    text: 'CREAR ACTIVIDAD',
                    isLoading: ctrl.cargando,
                    icon: Icons.add,
                    onPressed: _guardar,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
