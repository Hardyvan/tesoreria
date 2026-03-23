import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // Picker
import 'package:dsi/myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myMenu/b_rutas_app.dart';
import 'dart:async';
import '../myPagesTema/c_formatos.dart';
import '../myPagesBack/f_logica_perfil.dart';
import '../myPagesBack/modelo_usuario.dart';

class PerfilUsuario extends StatelessWidget {
  const PerfilUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: const [ BannerSinConexion() ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
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
                      icon: Icon(Icons.camera_alt, size: 18, color: Theme.of(context).primaryColor),
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
                                     unawaited(_seleccionarYSubirFoto(context, ImageSource.gallery));
                                   },
                                 ),
                                 ListTile(
                                   leading: const Icon(Icons.camera_alt),
                                   title: const Text('Cámara'),
                                   onTap: () async {
                                     Navigator.pop(ctx);
                                     unawaited(_seleccionarYSubirFoto(context, ImageSource.camera));
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
            
            const SizedBox(height: 24),
            
            // ----------------------------------------------------
            // SECCIÓN DE PERSONALIZACIÓN (DISEÑO SLEEK)
            // ----------------------------------------------------
            Consumer<ProveedorTema>(
              builder: (context, ref, child) {
                final isDark = ref.modoTema == ThemeMode.dark;
                
                // Color contenedor basado en el modo, imitando el diseño de la imagen
                final cardColor = isDark 
                    ? const Color(0xFF1E293B) // Slate Dark
                    : Colors.white;
                
                final borderColor = isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.2);

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalización',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: borderColor),
                        const SizedBox(height: 16),
                        
                        // 1. SWITCH MODO OSCURO
                        _themeSwitchTile(ref: ref),
                        const SizedBox(height: 24),
                        
                        // 2. PALETA DE COLORES
                        Text(
                          'Color Corporativo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecciona el color principal de la aplicación',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _themeColorPicker(ref: ref),
                        
                        const SizedBox(height: 32),
                        
                        // 3. ESTILO VISUAL DE COMPONENTES
                        Text(
                          'Estilo de Componentes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Define la forma de botones y diálogos',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _themeStyleSelector(ref: ref),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            TarjetaPremium(
              usaGradientePrimario: true,
              esBordeBrillante: true,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history_edu),
                    title: const Text('Historial de Pagos y Ayuda'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pushNamed(context, RutasApp.historialPagos),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Celular'),
                    subtitle: Text(user?.celular ?? 'Sin registrar'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Diálogo para editar celular
                        final ctrl = TextEditingController(text: user?.celular);
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Actualizar Celular'),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Nuevo Número'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  final exito = await auth.actualizarCelular(ctrl.text);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(exito ? 'Celular actualizado' : 'Error al actualizar'),
                                        backgroundColor: exito ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Guardar'),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar Sesión'),
                    onTap: () {
                      auth.cerrarSesion();
                      Navigator.pushNamedAndRemoveUntil(context, '/inicio_sesion', (route) => false);
                    },
                  ),
                  if (auth.esAdmin) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
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
           const SnackBar(content: Text('Subiendo foto... ☁️'), duration: Duration(seconds: 2))
        );
      }

      // 2. Subir a Firebase
      final url = await auth.subirImagenStorage(File(archivo.path));

      if (url != null) {
        // 3. Actualizar en BD (MySQL + SQLite)
        await auth.actualizarFoto(url);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('¡Foto actualizada! 📸'), backgroundColor: Colors.green)
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Error al subir imagen.'), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      debugPrint('Error picker: $e');
    }
  }

  // =============================================================
  // 1. SWITCH MODO OSCURO (OPTIMIZADO)
  // =============================================================
  Widget _themeSwitchTile({required ProveedorTema ref}) {
    return Builder(
      builder: (context) {
        final isDark = ref.modoTema == ThemeMode.dark;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          subtitle: Text(
            isDark ? 'Descansa tu vista con tonos oscuros' : 'Interfaz clara y luminosa',
            style: TextStyle(fontFamily: 'Inter', color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          value: isDark,
          activeThumbColor: const Color(0xFF00ADB5), // Color tipo "Teal" del switch en tu diseño
          activeTrackColor: const Color(0xFF00ADB5).withValues(alpha: 0.4),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[800],
          onChanged: (val) {
             ref.cambiarTema(val);
          },
        );
      }
    );
  }

  // =============================================================
  // 2. CHECK MULTI COLOR (CON ESTILO Y ANIMACIÓN)
  // =============================================================
  Widget _themeColorPicker({required ProveedorTema ref}) {
    return Builder(
      builder: (context) {
        // Obtenemos el ancho de pantalla para simular el responsive
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: AppPalettes.coloresDisponibles.map((color) {
            final isSelected = ref.colorTema.toARGB32() == color.toARGB32(); 

            return GestureDetector(
              onTap: () => ref.cambiarColorPrimario(color),
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: isMobile ? 45 : 55,
                  height: isMobile ? 45 : 55,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }

  // =============================================================
  // 3. SELECTOR DE ESTILO (CHIPS MEJORADOS)
  // =============================================================
  Widget _themeStyleSelector({required ProveedorTema ref}) {
    IconData getStyleIcon(AppStyle style) {
      switch (style) {
        case AppStyle.standard: return Icons.check_box_outline_blank_rounded; 
        case AppStyle.modern:   return Icons.circle_outlined;                 
        case AppStyle.elegant:  return Icons.square_outlined;                 
        case AppStyle.tech:     return Icons.code;                            
      }
    }

    return Builder(
      builder: (context) {
        final isDarkTheme = ref.modoTema == ThemeMode.dark;

        return Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: AppStyle.values.map((style) {
              final isSelected = ref.estiloSeleccionado == style;
              final styleIcon = getStyleIcon(style);
              
              final unselectedColor = isDarkTheme ? Colors.white70 : Colors.black54;
              final selectedColor = Colors.white;

              return ChoiceChip(
                avatar: Icon(
                  styleIcon,
                  size: 16,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                label: Text(
                  style.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                selected: isSelected,
                onSelected: (bool selected) {
                  if (selected) ref.cambiarEstilo(style);
                },
                showCheckmark: false, 
                elevation: 0,
                selectedColor: isDarkTheme ? Colors.white12 : Colors.black87,
                backgroundColor: isDarkTheme
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                side: BorderSide.none, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), 
                ),
                labelStyle: TextStyle(
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              );
            }).toList(),
          ),
        );
      }
    );
  }
}


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
