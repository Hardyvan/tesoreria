import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/modelo_actividad.dart';
import '../myPagesBack/e_logica_actividades.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesTema/c_formatos.dart';

class PantallaAsistencia extends StatefulWidget {
  final Actividad actividad;

  const PantallaAsistencia({super.key, required this.actividad});

  @override
  State<PantallaAsistencia> createState() => _PantallaAsistenciaState();
}

class _PantallaAsistenciaState extends State<PantallaAsistencia> {
  List<Map<String, dynamic>> _alumnos = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarAsistencias();
  }

  Future<void> _cargarAsistencias() async {
    final ctrl = context.read<ControladorActividades>();
    final data = await ctrl.obtenerAsistencia(widget.actividad.id);
    if (mounted) {
      setState(() {
        _alumnos = data;
        _cargando = false;
      });
    }
  }

  void _cambiarEstado(int index, String nuevoEstado) {
    setState(() {
      _alumnos[index]['estado'] = nuevoEstado;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    
    // Preparar payload
    final asistenciasList = _alumnos.map((a) => {
      'usuarioId': a['usuario_id'],
      'estado': a['estado'],
    }).where((a) => a['estado'] != 'pendiente').toList();

    final auth = context.read<ControladorAuth>();
    final ctrl = context.read<ControladorActividades>();
    
    final exito = await ctrl.guardarAsistenciaLote(widget.actividad.id, asistenciasList, auth.usuarioActual!);
    
    if (mounted) {
      setState(() => _guardando = false);
      if (exito) {
        context.read<ControladorFinanzas>().invalidarCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia guardada correctamente'), backgroundColor: ColoresApp.exito),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar asistencia'), backgroundColor: ColoresApp.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Encabezado
                Padding(
                  padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
                  child: TarjetaPremium(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.assignment_ind, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.actividad.titulo, 
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Multa por inasistencia: ${widget.actividad.multaInasistencia.toSoles()}', 
                          style: const TextStyle(color: ColoresApp.error, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Marcar "Faltó" generará automáticamente la deuda en el sistema.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                
                // Lista interactiva
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: DimensionesApp.paddingEstandar),
                    itemCount: _alumnos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final alumno = _alumnos[index];
                      final estadoActual = alumno['estado'];
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(alumno['nombre'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          estadoActual == 'pendiente' ? 'Sin marcar' : estadoActual.toString().toUpperCase(),
                          style: TextStyle(
                            color: estadoActual == 'asistio' ? ColoresApp.exito
                                : estadoActual == 'falto' ? ColoresApp.error
                                : estadoActual == 'permiso' ? ColoresApp.estadoPendiente
                                : Colors.grey,
                            fontWeight: estadoActual != 'pendiente' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBotonAsistencia(index, 'asistio', Icons.check_circle, ColoresApp.exito, estadoActual),
                            const SizedBox(width: 8),
                            _buildBotonAsistencia(index, 'falto', Icons.cancel, ColoresApp.error, estadoActual),
                            const SizedBox(width: 8),
                            _buildBotonAsistencia(index, 'permiso', Icons.pause_circle_filled, ColoresApp.estadoPendiente, estadoActual),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Boton Guardar
                Container(
                  padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                    ],
                  ),
                  child: BotonGradiente(
                    text: 'GUARDAR ASISTENCIAS',
                    icon: Icons.save,
                    isLoading: _guardando,
                    onPressed: _guardar,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBotonAsistencia(int index, String tipo, IconData icon, Color color, String estadoActual) {
    final seleccionado = estadoActual == tipo;
    return GestureDetector(
      onTap: () => _cambiarEstado(index, tipo),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: seleccionado ? color : Colors.grey.shade300),
        ),
        child: Icon(icon, color: seleccionado ? color : Colors.grey.shade400, size: 24),
      ),
    );
  }
}
