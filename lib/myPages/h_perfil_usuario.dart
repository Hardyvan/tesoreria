import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // Picker
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';
import '../myPagesBack/a_controlador_auth.dart';

class PerfilUsuario extends StatelessWidget {
  const PerfilUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: ColoresApp.primario,
                  backgroundImage: (user?.fotoUrl ?? '').isNotEmpty 
                      ? NetworkImage(user!.fotoUrl) 
                      : null,
                  child: (user?.fotoUrl ?? '').isEmpty 
                      ? const Icon(Icons.person, size: 50, color: Colors.white) 
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 18, color: ColoresApp.primario),
                      onPressed: () {
                         // MOSTRAR SELECTOR (Cámara o Galería)
                         showModalBottomSheet(
                           context: context,
                           backgroundColor: Colors.white,
                           shape: const RoundedRectangleBorder(
                             borderRadius: BorderRadius.vertical(top: Radius.circular(20))
                           ),
                           builder: (ctx) => SafeArea(
                             child: Wrap(
                               children: [
                                 ListTile(
                                   leading: const Icon(Icons.photo_library),
                                   title: const Text('Galería'),
                                   onTap: () async {
                                     Navigator.pop(ctx);
                                     _seleccionarYSubirFoto(context, ImageSource.gallery);
                                   },
                                 ),
                                 ListTile(
                                   leading: const Icon(Icons.camera_alt),
                                   title: const Text('Cámara'),
                                   onTap: () async {
                                     Navigator.pop(ctx);
                                     _seleccionarYSubirFoto(context, ImageSource.camera);
                                   },
                                 ),
                               ],
                             ),
                           ),
                         );
                      },
                    ),
                  ),
                )
              ],
            ),
            
            if (auth.cargando) 
               const Padding(
                 padding: EdgeInsets.only(top: 10),
                 child: LinearProgressIndicator(), 
               ),
            const SizedBox(height: 16),
            Text(user?.nombre ?? 'Invitado', style: Theme.of(context).textTheme.headlineMedium),
            Text(user?.rol ?? '', style: Theme.of(context).textTheme.titleMedium),
            
            const SizedBox(height: 40),
            
            TarjetaPremium(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Celular'),
                    subtitle: Text(user?.celular ?? 'Sin registrar'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: ColoresApp.primario),
                      onPressed: () {
                        // Diálogo para editar celular
                        final ctrl = TextEditingController(text: user?.celular);
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text("Actualizar Celular"),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: "Nuevo Número"),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text("Cancelar"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  final exito = await auth.actualizarCelular(ctrl.text);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(exito ? "Celular actualizado" : "Error al actualizar"),
                                        backgroundColor: exito ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text("Guardar"),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: ColoresApp.error),
                    title: const Text('Cerrar Sesión', style: TextStyle(color: ColoresApp.error)),
                    onTap: () {
                      auth.cerrarSesion();
                      Navigator.pushNamedAndRemoveUntil(context, '/inicio_sesion', (route) => false);
                    },
                  ),
                  if (auth.esAdmin) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: ColoresApp.primario),
                      title: const Text('Gestión de Usuarios', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                         Navigator.pushNamed(context, '/gestion_usuarios');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MÉTODO AUXILIAR PARA SUBIR FOTO
  Future<void> _seleccionarYSubirFoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    
    try {
      // 1. Seleccionar con compresión
      final XFile? archivo = await picker.pickImage(
        source: source,
        maxWidth: 800,  // Reducir tamaño
        imageQuality: 60 // Calidad media (ahorro)
      );
      
      if (archivo == null) return; // Cancelado

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Subiendo foto... ☁️"), duration: Duration(seconds: 2))
        );
      }

      // 2. Subir a Firebase
      final url = await auth.subirImagenStorage(File(archivo.path));

      if (url != null) {
        // 3. Actualizar en BD (MySQL + SQLite)
        await auth.actualizarFoto(url);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("¡Foto actualizada! 📸"), backgroundColor: Colors.green)
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Error al subir imagen."), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      debugPrint("Error picker: $e");
    }
  }
}
