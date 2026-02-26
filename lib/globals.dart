import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'myPagesBack/a_servicio_conectividad.dart';
import 'myPagesTema/a_tema.dart';

// =============================================================================
// BANNER SIN CONEXIÓN GLOBAL 
// =============================================================================
class BannerSinConexion extends StatelessWidget {
  const BannerSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final conectividad = Provider.of<ServicioConectividad>(context);
    
    if (conectividad.tieneConexion) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: ColoresApp.error,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Text(
        'Sin conexión a internet',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
