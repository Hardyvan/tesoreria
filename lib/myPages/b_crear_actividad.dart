import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dsi/myPagesTema/a_tema.dart';
import 'package:dsi/myPagesTema/c_ui_kit.dart';

import '../myPagesBack/c_controlador_actividades.dart';
import '../myPagesBack/a_controlador_auth.dart';

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
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final costo = double.tryParse(_ctrlCosto.text) ?? 0.0;
    
    if (auth.usuarioActual == null) return;

    final exito = await ctrl.crearActividad(_ctrlTitulo.text, costo, auth.usuarioActual!);
    
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
