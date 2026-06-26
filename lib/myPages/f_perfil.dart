import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // Picker
import 'package:dsi/myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import 'dart:async';
import '../myPagesTema/c_formatos.dart';
import '../myPagesBack/f_logica_perfil.dart';
import '../myPagesBack/modelo_usuario.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';

class PerfilUsuario extends StatelessWidget {
  const PerfilUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 45,
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
                      icon: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        // MOSTRAR SELECTOR (Cámara o Galería)
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Galería'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    unawaited(
                                      _seleccionarYSubirFoto(
                                        context,
                                        ImageSource.gallery,
                                      ),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Cámara'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    unawaited(
                                      _seleccionarYSubirFoto(
                                        context,
                                        ImageSource.camera,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            if (auth.cargando)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            Text(
              user?.nombre ?? 'Invitado',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              user?.rol ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 10),

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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. SWITCH MODO OSCURO
                          _themeSwitchTile(ref: ref),
                          const SizedBox(height: 10),

                        // 2. PALETA DE COLORES
                        Text(
                          'Color Corporativo',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecciona el color principal de la aplicación',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                        ),
                        const SizedBox(height: 16),
                        _themeColorPicker(ref: ref),
                      ],
                    ),
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
                              maxLength: 9,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Nuevo Número',
                                counterText: '', // Ocultar contador si se prefiere una UI más limpia
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  if (ctrl.text.length < 9) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('El número debe tener 9 dígitos'), backgroundColor: Colors.orange),
                                    );
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  final errorMsg = await auth.actualizarCelular(
                                    ctrl.text,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          errorMsg ?? 'Celular actualizado correctamente',
                                        ),
                                        backgroundColor: errorMsg == null
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Guardar'),
                              ),
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
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/inicio_sesion',
                        (route) => false,
                      );
                    },
                  ),
                  if (auth.esAdmin) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text(
                        'Gestión de Usuarios',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
    );
  }

  // MÉTODO AUXILIAR PARA SUBIR FOTO
  Future<void> _seleccionarYSubirFoto(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    try {
      // 1. Seleccionar con compresión (Calidad reducida al 70% y dimensiones optimizadas para perfil)
      final XFile? archivo = await picker.pickImage(
        source: source,
        maxWidth: 600, // Dimensión física optimizada para perfil
        maxHeight: 600, // Evitar distorsión vertical alta
        imageQuality: 70, // Reducción estricta de calidad al 70% (ahorro de tamaño)
      );

      if (archivo == null) return; // Cancelado

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subiendo foto... ☁️'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 2. Subir a Firebase
      final url = await auth.subirImagenStorage(File(archivo.path));

      if (url != null) {
        // 3. Actualizar en BD (MySQL + SQLite)
        await auth.actualizarFoto(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Foto actualizada! 📸'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al subir imagen.'),
              backgroundColor: Colors.red,
            ),
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
          title: const Text(
            'Modo Oscuro',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
          ),
          subtitle: Text(
            isDark
                ? 'Descansa tu vista con tonos oscuros'
                : 'Interfaz clara y luminosa',
            style: TextStyle(
              fontFamily: 'Inter',
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          value: isDark,
          activeThumbColor: const Color(
            0xFF00ADB5,
          ), // Color tipo "Teal" del switch en tu diseño
          activeTrackColor: const Color(0xFF00ADB5).withValues(alpha: 0.4),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[800],
          onChanged: (val) {
            ref.cambiarTema(val);
          },
        );
      },
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
      },
    );
  }

  // =============================================================
  // 3. SELECTOR DE ESTILO (CHIPS MEJORADOS)
  // =============================================================
}

class GestionUsuarios extends StatefulWidget {
  const GestionUsuarios({super.key});

  @override
  State<GestionUsuarios> createState() => _GestionUsuariosState();
}

class _GestionUsuariosState extends State<GestionUsuarios> {
  late Future<void> _futureUsuarios;

  @override
  void initState() {
    super.initState();
    _futureUsuarios = Future.delayed(Duration.zero, _cargarUsuarios);
  }

  Future<void> _cargarUsuarios() async {
    final ctrl = Provider.of<ControladorUsuarios>(context, listen: false);
    // Forzamos la actualización siempre que se abra la pantalla para evitar datos viejos cacheados
    await ctrl.listarUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCrearAlumno(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Crear Manual'),
      ),
      body: FutureBuilder<void>(
        future: _futureUsuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Consumer<ControladorUsuarios>(
            builder: (context, usuariosCtrl, _) {
              final theme = Theme.of(context);
              if (usuariosCtrl.usuarios.isEmpty) {
                return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay usuarios registrados',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
              }
              return ListView.builder(
              padding: const EdgeInsets.only(
                bottom: 80,
                left: 16,
                right: 16,
                top: 16,
              ),
              itemCount: usuariosCtrl.usuarios.length,
              itemBuilder: (context, index) {
                final usuario = usuariosCtrl.usuarios[index];
                return _TarjetaUsuario(usuario: usuario);
              },
            );
            },
          );
        },
      ),
    );
  }

  void _mostrarDialogoCrearAlumno(BuildContext context) {
    final ctrlNombre = TextEditingController();
    final ctrlEmail = TextEditingController();
    final ctrlCelular = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Crear Alumno Manual'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CampoTextoPersonalizado(
                  controller: ctrlNombre,
                  label: 'Nombre Completo *',
                  hint: 'Ej. Juan Pérez',
                  prefixIcon: Icons.person,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CampoTextoPersonalizado(
                  controller: ctrlEmail,
                  label: 'Correo Electrónico (Google)',
                  hint: 'Ej. compañero@gmail.com',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegExp.hasMatch(value.trim())) {
                        return 'Formato de correo inválido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CampoTextoPersonalizado(
                  controller: ctrlCelular,
                  label: 'Número de Celular',
                  hint: 'Ej. 987654321',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              
              final nombre = ctrlNombre.text.trim();
              final email = ctrlEmail.text.trim();
              final celular = ctrlCelular.text.trim();
              
              Navigator.pop(dialogCtx);
              
              final finanzas = Provider.of<ControladorFinanzas>(context, listen: false);
              final exito = await finanzas.registrarAlumnoOffline(
                nombre: nombre,
                email: email.isNotEmpty ? email : null,
                celular: celular.isNotEmpty ? celular : null,
              );
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(exito ? 'Alumno registrado correctamente' : 'Error al crear alumno (Verifica conexión/duplicados)'),
                    backgroundColor: exito ? Colors.green : Colors.red,
                  )
                );
                if (exito) {
                   // Refrescar lista visual
                   unawaited(Provider.of<ControladorUsuarios>(context, listen: false).listarUsuarios());
                }
              }
            },
            child: const Text('Crear Alumno'),
          ),
        ],
      )
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

    Color? leftAccent;
    if (!esActivo) {
      leftAccent = Colors.grey;
    } else if (usuario.rol == 'SuperAdmin') {
      leftAccent = Colors.purple;
    } else if (esAdmin) {
      leftAccent = theme.primaryColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaPremium(
        usaGradientePrimario: false,
        leftAccentColor: leftAccent,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        child: Row(
          children: [
            // AVATAR CON INDICADOR DE ESTADO INTEGRADO
            AvatarUsuario(
              nombre: usuario.nombre,
              fotoUrl: usuario.fotoUrl,
              radius: 24,
              backgroundColor: esAdmin
                  ? theme.primaryColor.withValues(alpha: 0.12)
                  : theme.colorScheme.surface,
              textColor: esAdmin
                  ? theme.primaryColor
                  : ColoresApp.textoSecundarioClaro,
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
                      decoration: !esActivo
                          ? TextDecoration.lineThrough
                          : null, // Tachado si bloqueado
                      color: !esActivo ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    usuario.email.isNotEmpty ? usuario.email : 'Sin correo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  if (usuario.celular.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_android, size: 11, color: theme.primaryColor.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          usuario.celular,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  // CHIP DE ROL
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: usuario.rol == 'SuperAdmin'
                          ? Colors.purple.withValues(alpha: 0.12)
                          : (esAdmin
                                ? theme.primaryColor.withValues(alpha: 0.12)
                                : Colors.blueGrey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: usuario.rol == 'SuperAdmin'
                            ? Colors.purple.withValues(alpha: 0.4)
                            : (esAdmin
                                  ? theme.primaryColor.withValues(alpha: 0.4)
                                  : Colors.blueGrey.withValues(alpha: 0.3)),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      usuario.rol.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: usuario.rol == 'SuperAdmin'
                            ? Colors.purple
                            : (esAdmin
                                  ? theme.primaryColor
                                  : Colors.blueGrey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ACCIONES
            PopupMenuButton<String>(
              onSelected: (accion) => _manejarAccion(context, accion, usuario),
              itemBuilder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return [
                  PopupMenuItem(
                    value: 'ver',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 12),
                        Text('Ver Perfil', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  if (usuario.rol == 'Alumno')
                    PopupMenuItem(
                      value: 'exonerar',
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Text('Exoneraciones', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'edit_name',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 12),
                        Text('Editar Nombre', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rol',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 12),
                        Text('Cambiar Rol', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bloqueo',
                    child: Row(
                      children: [
                        Icon(
                          esActivo ? Icons.block : Icons.check_circle,
                          color: esActivo ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          esActivo ? 'Bloquear Cuenta' : 'Desbloquear',
                          style: TextStyle(color: esActivo ? Colors.red : Colors.green),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pass',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 12),
                        Text('Restablecer Pass', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'fusionar',
                    child: Row(
                      children: [
                        Icon(Icons.merge_type, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 12),
                        Text('Fusionar Cuenta', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Eliminar Usuario',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ];
              },
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
      case 'exonerar':
        _mostrarDialogoExoneraciones(context, usuario);
        break;
      case 'edit_name':
        _mostrarDialogoEditarNombre(context, usuario);
        break;
      case 'rol':
        _mostrarDialogoRol(context, usuario);
        break;
      case 'bloqueo':
        _confirmarBloqueo(context, usuario);
        break;
      case 'pass':
        if (usuario.email.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El usuario no tiene un correo registrado.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        Provider.of<ControladorUsuarios>(context, listen: false)
            .enviarCorreoRestablecimiento(usuario.email)
            .then((exito) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(exito ? 'Correo de restablecimiento enviado' : 'Error al enviar correo'),
                backgroundColor: exito ? Colors.green : Colors.red,
              ),
            );
          }
        });
        break;
      case 'fusionar':
        _mostrarDialogoFusion(context, usuario);
        break;
      case 'delete':
        _confirmarEliminacion(context, usuario);
        break;
    }
  }

  void _mostrarDialogoEditarNombre(BuildContext context, Usuario usuario) {
    final ctrl = TextEditingController(text: usuario.nombre);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar Nombre'),
        content: CampoTextoPersonalizado(
          controller: ctrl,
          label: 'Nombre Completo',
          hint: 'Ej. Juan Pérez',
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final nuevoNombre = ctrl.text.trim();
              if (nuevoNombre == usuario.nombre) {
                Navigator.pop(dialogCtx);
                return;
              }
              Navigator.pop(dialogCtx);
              
              final exito = await Provider.of<ControladorUsuarios>(
                context,
                listen: false,
              ).actualizarNombre(usuario.id, nuevoNombre);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(exito ? 'Nombre actualizado' : 'Error al actualizar nombre'),
                    backgroundColor: exito ? Colors.green : Colors.red,
                  )
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      )
    );
  }

  void _confirmarEliminacion(BuildContext context, Usuario usuario) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${usuario.nombre} PERMANENTEMENTE?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final exito = await Provider.of<ControladorUsuarios>(
                context,
                listen: false,
              ).eliminarUsuario(usuario.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      exito ? 'Usuario eliminado' : 'Error al eliminar',
                    ),
                    backgroundColor: exito ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
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
            _dato(
              'Dirección',
              u.direccion.isEmpty ? 'No registrada' : u.direccion,
            ),
            _dato('Edad', u.edad == 0 ? 'No registrada' : '${u.edad} años'),
            _dato('Sexo', u.sexo.isEmpty ? 'No registrado' : u.sexo),
            const SizedBox(height: 10),
            Text(
              'Estado: ${u.estado.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
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
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
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
        content: Text(
          "¿Estás seguro de que quieres ${esActivo ? 'bloquear' : 'desbloquear'} a ${usuario.nombre}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esActivo ? Colors.red : Colors.green,
            ),
            onPressed: () {
              Navigator.pop(context);
              final nuevoEstado = esActivo ? 'inactivo' : 'activo';
              Provider.of<ControladorUsuarios>(
                context,
                listen: false,
              ).cambiarEstadoUsuario(usuario.id, nuevoEstado);
            },
            child: Text(esActivo ? 'Bloquear' : 'Desbloquear'),
          ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final exito = await Provider.of<ControladorUsuarios>(
                      context,
                      listen: false,
                    ).actualizarRol(usuario.id, nuevoRol);
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(exito ? 'Rol de ${usuario.nombre} actualizado a $nuevoRol' : 'Error al actualizar el rol'),
                        backgroundColor: exito ? Colors.green : Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
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

  void _mostrarDialogoExoneraciones(BuildContext context, Usuario usuario) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final ctrlUsuarios = Provider.of<ControladorUsuarios>(context, listen: false);
        final finanzas = Provider.of<ControladorFinanzas>(context, listen: false);

        return FutureBuilder<List<int>>(
          future: ctrlUsuarios.obtenerExoneraciones(usuario.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Cargando Exoneraciones...'),
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final exoneradas = snapshot.data ?? [];
            
            return AlertDialog(
              title: Text('Exoneraciones: ${usuario.nombre}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marca las actividades en las que el alumno participa y debe pagar. Desmarca las actividades de las cuales está EXONERADO (no tendrá deuda).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (finanzas.metasActividades.isEmpty)
                    const Text('No hay actividades registradas en el salón.')
                  else
                    SizedBox(
                      width: double.maxFinite,
                      height: 250,
                      child: StatefulBuilder(
                        builder: (statefulCtx, setStateLocal) {
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: finanzas.metasActividades.length,
                            itemBuilder: (listCtx, index) {
                              final act = finanzas.metasActividades[index];
                              final actId = act['id'] is int ? act['id'] : int.tryParse(act['id'].toString()) ?? 0;
                              final titulo = act['titulo']?.toString() ?? '';
                              final participa = !exoneradas.contains(actId);
                              final costoVal = act['costo'] is num ? (act['costo'] as num).toDouble() : (double.tryParse(act['costo']?.toString() ?? '') ?? 0.0);

                              return CheckboxListTile(
                                title: Text(titulo),
                                subtitle: Text('Costo: S/ ${costoVal.toStringAsFixed(2)}'),
                                value: participa,
                                activeColor: Colors.green,
                                onChanged: (value) async {
                                  if (value == null) return;
                                  
                                  final exito = await ctrlUsuarios.guardarExoneracion(
                                    usuario.id,
                                    actId,
                                    !value, // exonerado = true si desmarca
                                  );

                                  if (exito) {
                                    setStateLocal(() {
                                      if (value) {
                                        exoneradas.remove(actId);
                                      } else {
                                        exoneradas.add(actId);
                                      }
                                    });
                                    // Recargar reportes financieros y metas
                                    unawaited(finanzas.obtenerReporteDeudores());
                                    unawaited(finanzas.obtenerMetasActividades());
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoFusion(BuildContext context, Usuario usuarioOrigen) {
    final ctrlUsuarios = Provider.of<ControladorUsuarios>(context, listen: false);
    final finanzas = Provider.of<ControladorFinanzas>(context, listen: false);

    // Listar todos los otros usuarios
    final otrosUsuarios = ctrlUsuarios.usuarios.where((u) => u.id != usuarioOrigen.id).toList();

    if (otrosUsuarios.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fusión de Cuentas'),
          content: const Text('No hay otros usuarios registrados en el salón para realizar la fusión.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    Usuario? usuarioDestino;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          title: const Row(
            children: [
              Icon(Icons.merge_type, color: Colors.blueAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fusionar Cuenta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (statefulCtx, setStateLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                      children: [
                        const TextSpan(text: 'Vas a fusionar la cuenta de '),
                        TextSpan(
                          text: usuarioOrigen.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' en otra cuenta. Todos sus '),
                        const TextSpan(text: 'pagos, asistencias y exoneraciones', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        const TextSpan(text: ' serán transferidos, y esta cuenta temporal será '),
                        const TextSpan(text: 'eliminada permanentemente.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Selecciona la cuenta de destino (Google):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Usuario>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    hint: const Text('Seleccionar Alumno Destino'),
                    initialValue: usuarioDestino,
                    items: otrosUsuarios.map((u) {
                      final displayEmail = u.email.isEmpty ? 'Sin correo' : u.email;
                      return DropdownMenuItem<Usuario>(
                        value: u,
                        child: Text(
                          '${u.nombre} ($displayEmail)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setStateLocal(() {
                        usuarioDestino = val;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (usuarioDestino == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, selecciona un alumno de destino.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Confirmación de seguridad final
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('¿Confirmar Fusión?'),
                    content: Text(
                      '¿Estás seguro de que deseas fusionar a ${usuarioOrigen.nombre} en ${usuarioDestino!.nombre}?\n\nEsta operación moverá todos los registros y ELIMINARÁ la cuenta de ${usuarioOrigen.nombre}. Esta acción no se puede deshacer.'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, false),
                        child: const Text('No, Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(confirmCtx, true),
                        child: const Text('Sí, Fusionar'),
                      ),
                    ],
                  ),
                );

                if (confirmar != true) return;

                if (context.mounted) {
                  unawaited(showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) => const AlertDialog(
                      title: Text('Procesando Fusión...'),
                      content: SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ));
                }

                final exito = await ctrlUsuarios.fusionarUsuarios(usuarioOrigen.id, usuarioDestino!.id);

                if (context.mounted) {
                  Navigator.pop(context); // Cerrar loading dialog
                  Navigator.pop(dialogCtx); // Cerrar merge dialog
                  
                  if (exito) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Fusión completada con éxito. Cuenta de ${usuarioOrigen.nombre} unificada en ${usuarioDestino!.nombre}.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Actualizar reportes y metas de recaudación
                    unawaited(finanzas.obtenerReporteDeudores());
                    unawaited(finanzas.obtenerMetasActividades());
                    unawaited(finanzas.obtenerResumenFinanciero());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al procesar la fusión de cuentas en el servidor.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Fusionar'),
            ),
          ],
        );
      },
    );
  }
}

