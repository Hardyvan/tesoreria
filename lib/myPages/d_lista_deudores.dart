import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../myPagesBack/b_controlador_finanzas.dart';
import '../../myPagesBack/a_controlador_auth.dart';
import '../../myPagesTema/a_tema.dart';
import '../../myPagesTema/c_ui_kit.dart';
import '../../globals.dart'; // Import Added
import 'c_registro_pagos.dart';
import 'k_termometro_actividades.dart';
import '../../myPagesTema/b_formato.dart'; // Import Added
import 'dart:async';

class ListaDeudores extends StatefulWidget {
  const ListaDeudores({super.key});

  @override
  State<ListaDeudores> createState() => _ListaDeudoresState();
}

class _ListaDeudoresState extends State<ListaDeudores> {
  
  @override
  void initState() {
    super.initState();
    // Cargar reporte al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControladorFinanzas>().obtenerMetasActividades();
      context.read<ControladorFinanzas>().obtenerReporteDeudores();
    });
  }


  @override
  Widget build(BuildContext context) {
    final finanzas = context.watch<ControladorFinanzas>();
    final coloresInsoft = Theme.of(context).extension<InsoftColors>()!;
    final esAdmin = context.read<ControladorAuth>().esAdmin;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado Financiero'),
        actions: const [ BannerSinConexion() ],
      ),
      body: finanzas.cargando && finanzas.listaDeudores.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              final finanzas = context.read<ControladorFinanzas>();
              await finanzas.obtenerMetasActividades();
              await finanzas.obtenerReporteDeudores();
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
                      'Estado por Alumnos', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  );
                }

                final alumno = finanzas.listaDeudores[index - 2];
                final double? deuda = double.tryParse(alumno['deuda'].toString());
                final double montoDeuda = deuda ?? 0.0;
                final esDeudor = montoDeuda > 0;
                
                // Definimos los colores dinámicos basados en tu tema
                final colorEstado = esDeudor ? coloresInsoft.estadoDeudor! : coloresInsoft.estadoPagado!;
                final colorFondoAvatar = colorEstado.withValues(alpha: 0.15); // Fondo muy suave
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar),
                  child: TarjetaPremium(
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
                        // --- EL NUEVO AVATAR CON INICIALES ---
                        AvatarUsuario(
                          nombre: alumno['nombre'],
                          fotoUrl: alumno['foto_url'],
                          radius: 24,
                          backgroundColor: colorFondoAvatar,
                          textColor: colorEstado,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alumno['nombre'].toString().toCapitalized(), 
                                style: Theme.of(context).textTheme.titleMedium
                              ),
                              const SizedBox(height: 4),
                              Text(
                                esDeudor ? 'Debe S/ ${montoDeuda.toStringAsFixed(2)}' : 'Al día',
                                style: TextStyle(
                                  color: colorEstado,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (esAdmin) 
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}
