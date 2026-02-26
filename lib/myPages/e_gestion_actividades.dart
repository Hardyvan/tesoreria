import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/c_controlador_actividades.dart';
import '../myPagesBack/a_controlador_auth.dart';
import '../myPagesTema/a_tema.dart';
import 'b_crear_actividad.dart';

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

  void _mostrarDialogoEditar(BuildContext context, int id, String tituloActual, double costoActual) {
    final ctrlTitulo = TextEditingController(text: tituloActual);
    final ctrlCosto = TextEditingController(text: costoActual.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Actividad'),
        content: Form(
          key: formKey,
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
                decoration: const InputDecoration(labelText: 'Meta Total', prefixText: 'S/ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
            ],
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
                
                final exito = await ctrl.editarActividad(id, ctrlTitulo.text, costoNuevo, auth.usuarioActual!);
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
                  subtitle: Text('Meta: S/ ${actividad.costo.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                        onPressed: () => _mostrarDialogoEditar(context, actividad.id, actividad.titulo, actividad.costo),
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
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearActividad())),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVA ACTIVIDAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
