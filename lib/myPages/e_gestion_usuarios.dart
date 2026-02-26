import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dsi/myPagesTema/a_tema.dart';
import 'package:dsi/myPagesTema/c_ui_kit.dart';
import 'package:dsi/myPagesTema/b_formato.dart'; // Import Added
import '../myPagesBack/d_controlador_usuarios.dart';
import '../myPagesBack/modelo_usuario.dart';


class GestionUsuarios extends StatefulWidget {
  const GestionUsuarios({super.key});

  @override
  State<GestionUsuarios> createState() => _GestionUsuariosState();
}

class _GestionUsuariosState extends State<GestionUsuarios> {
  @override
  void initState() {
    super.initState();
    // Cargar usuarios al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ControladorUsuarios>(context, listen: false).listarUsuarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuariosCtrl = Provider.of<ControladorUsuarios>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
      ),
      body: usuariosCtrl.cargando
          ? const Center(child: CircularProgressIndicator())
          : usuariosCtrl.usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No hay usuarios registrados', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 16),
                  itemCount: usuariosCtrl.usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = usuariosCtrl.usuarios[index];
                    return _TarjetaUsuario(usuario: usuario);
                  },
                ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final Usuario usuario;

  const _TarjetaUsuario({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esAdmin = usuario.rol == 'Admin';
    final esActivo = usuario.estado == 'activo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaPremium(
        child: Row(
          children: [
            // AVATAR CON INDICADOR DE ESTADO INTEGRADO
            AvatarUsuario(
              nombre: usuario.nombre,
              fotoUrl: usuario.fotoUrl,
              radius: 24,
              backgroundColor: esAdmin ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.surface,
              textColor: esAdmin ? Colors.white : ColoresApp.textoSecundarioClaro,
              activo: esActivo, // NUEVO: El widget maneja el puntito verde/rojo
            ),
            const SizedBox(width: 16),
            
            // DATOS BÁSICOS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombre.toCapitalized(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: !esActivo ? TextDecoration.lineThrough : null, // Tachado si bloqueado
                      color: !esActivo ? Colors.grey : null,
                    ),
                  ),
                  Text(
                    usuario.email.isNotEmpty ? usuario.email : 'Sin correo',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 4),
                  // CHIP DE ROL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // MÁS AIRE
                    decoration: BoxDecoration(
                      color: usuario.rol == 'SuperAdmin' 
                          ? Colors.purple.withValues(alpha: 0.1) 
                          : (esAdmin ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: esAdmin ? Theme.of(context).primaryColor.withValues(alpha: 0.3) : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      usuario.rol.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: usuario.rol == 'SuperAdmin' 
                            ? Colors.purple 
                            : (esAdmin ? Theme.of(context).primaryColor : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ACCIONES
            PopupMenuButton<String>(
              onSelected: (accion) => _manejarAccion(context, accion, usuario),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'ver', child: ListTile(leading: Icon(Icons.visibility), title: Text('Ver Perfil'))),
                const PopupMenuItem(value: 'rol', child: ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Cambiar Rol'))),
                PopupMenuItem(
                  value: 'bloqueo', 
                  child: ListTile(
                    leading: Icon(esActivo ? Icons.block : Icons.check_circle, color: esActivo ? Colors.red : Colors.green), 
                    title: Text(esActivo ? 'Bloquear Cuenta' : 'Desbloquear')
                  )
                ),
                const PopupMenuItem(value: 'pass', child: ListTile(leading: Icon(Icons.lock_reset), title: Text('Restablecer Pass'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Colors.red), title: Text('Eliminar Usuario', style: TextStyle(color: Colors.red)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _manejarAccion(BuildContext context, String accion, Usuario usuario) {
    switch (accion) {
      case 'ver':
        _mostrarPerfilCompleto(context, usuario);
        break;
      case 'rol':
        _mostrarDialogoRol(context, usuario);
        break;
      case 'bloqueo':
        _confirmarBloqueo(context, usuario);
        break;
      case 'pass':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se enviaría un correo de reset (Demo)')));
        break;
      case 'delete':
        _confirmarEliminacion(context, usuario);
        break;
    }
  }

  void _confirmarEliminacion(BuildContext context, Usuario usuario) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de que quieres eliminar a ${usuario.nombre} PERMANENTEMENTE?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final exito = await Provider.of<ControladorUsuarios>(context, listen: false)
                  .eliminarUsuario(usuario.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(exito ? 'Usuario eliminado' : 'Error al eliminar'),
                    backgroundColor: exito ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          )
        ],
      ),
    );
  }

  void _mostrarPerfilCompleto(BuildContext context, Usuario u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(u.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dato('Celular', u.celular),
            _dato('Email', u.email),
            const Divider(),
            _dato('Dirección', u.direccion.isEmpty ? 'No registrada' : u.direccion),
            _dato('Edad', u.edad == 0 ? 'No registrada' : '${u.edad} años'),
            _dato('Sexo', u.sexo.isEmpty ? 'No registrado' : u.sexo),
            const SizedBox(height: 10),
            Text('Estado: ${u.estado.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  void _confirmarBloqueo(BuildContext context, Usuario usuario) {
    final esActivo = usuario.estado == 'activo';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(esActivo ? 'Bloquear Usuario' : 'Desbloquear Usuario'),
        content: Text("¿Estás seguro de que quieres ${esActivo ? 'bloquear' : 'desbloquear'} a ${usuario.nombre}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: esActivo ? Colors.red : Colors.green),
            onPressed: () {
              Navigator.pop(context);
              final nuevoEstado = esActivo ? 'inactivo' : 'activo';
              Provider.of<ControladorUsuarios>(context, listen: false)
                  .cambiarEstadoUsuario(usuario.id, nuevoEstado);
            },
            child: Text(esActivo ? 'Bloquear' : 'Desbloquear'),
          )
        ],
      ),
    );
  }

  void _mostrarDialogoRol(BuildContext context, Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) {
        String nuevoRol = usuario.rol;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Rol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Alumno'),
                    value: 'Alumno',
                     // ignore: deprecated_member_use
                    groupValue: nuevoRol,
                     // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => nuevoRol = v!),
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Admin'),
                    value: 'Admin',
                     // ignore: deprecated_member_use
                    groupValue: nuevoRol,
                     // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => nuevoRol = v!),
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Super Admin (Pro)'),
                    value: 'SuperAdmin',
                    activeColor: Colors.purple,
                     // ignore: deprecated_member_use
                    groupValue: nuevoRol,
                     // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => nuevoRol = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Provider.of<ControladorUsuarios>(context, listen: false)
                        .actualizarRol(usuario.id, nuevoRol);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
