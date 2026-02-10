import 'package:flutter/material.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';

class RegistroPagos extends StatelessWidget {
  const RegistroPagos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Pago')),
      body: Padding(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          children: [
             const Text('Seleccione Alumno y Actividad a pagar'),
             // Aquí irían Dropdowns / Selectores
             const Spacer(),
             BotonGradiente(
               text: 'REGISTRAR PAGO',
               onPressed: () {},
             ),
          ],
        ),
      ),
    );
  }
}
