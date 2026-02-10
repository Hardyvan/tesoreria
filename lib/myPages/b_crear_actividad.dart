import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';
import '../myPagesBack/c_controlador_actividades.dart';

class CrearActividad extends StatefulWidget {
  const CrearActividad({super.key});

  @override
  State<CrearActividad> createState() => _CrearActividadState();
}

class _CrearActividadState extends State<CrearActividad> {
  final _ctrlTitulo = TextEditingController();
  final _ctrlCosto = TextEditingController();

  Future<void> _guardar() async {
    final ctrl = Provider.of<ControladorActividades>(context, listen: false);
    final costo = double.tryParse(_ctrlCosto.text) ?? 0.0;
    
    final exito = await ctrl.crearActividad(_ctrlTitulo.text, costo);
    
    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad Creada')));
      Navigator.pop(context); // Volver si se navegó aquí
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Actividad')),
      body: Padding(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          children: [
            CampoTextoPersonalizado(
              label: 'Título (Ej: Pollada Pro-Fondos)',
              prefixIcon: Icons.event,
              controller: _ctrlTitulo,
            ),
            const SizedBox(height: 20),
            CampoTextoPersonalizado(
              label: 'Costo General (S/.)',
              prefixIcon: Icons.monetization_on,
              controller: _ctrlCosto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 40),
            Consumer<ControladorActividades>(
              builder: (context, ctrl, _) {
                return BotonGradiente(
                  text: 'CREAR ACTIVIDAD',
                  isLoading: ctrl.cargando,
                  onPressed: _guardar,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
