import 'package:flutter/material.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';

class ListaDeudores extends StatelessWidget {
  const ListaDeudores({super.key});

  @override
  Widget build(BuildContext context) {
    // Accedemos a los colores dinámicos del tema
    final coloresInsoft = Theme.of(context).extension<InsoftColors>()!;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Estado Financiero')),
      body: ListView.builder(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        itemCount: 10,
        itemBuilder: (context, index) {
          final esDeudor = index % 2 == 0; // Alternar para demo
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TarjetaPremium(
              child: Row(
                children: [
                  CircleAvatar(
                    // USAMOS LOS COLORES DINÁMICOS DEL EXTENSION
                    backgroundColor: esDeudor ? coloresInsoft.estadoDeudor : coloresInsoft.estadoPagado,
                    child: Icon(
                      esDeudor ? Icons.close : Icons.check, 
                      color: Colors.white
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alumno $index', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          esDeudor ? 'Debe S/ 50.00' : 'Al día',
                          style: TextStyle(
                            // USAMOS LOS COLORES DINÁMICOS
                            color: esDeudor ? coloresInsoft.estadoDeudor : coloresInsoft.estadoPagado,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
