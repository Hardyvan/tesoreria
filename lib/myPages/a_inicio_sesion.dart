import 'dart:async';
import '../myPagesTema/b_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dsi/myPagesTema/a_tema.dart';

// TUS IMPORTS DE INSOFT
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myMenu/b_rutas_app.dart';

class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  final ValueNotifier<bool> _cargando = ValueNotifier<bool>(false);

  @override
  void dispose() {
    // Liberamos el ValueNotifier para evitar fugas de memoria
    _cargando.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE LOGIN (Delegada al Controlador)
  // ---------------------------------------------------------------------------
  Future<void> _ingresarConGoogle() async {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final errorMsg = await auth.ingresarConGoogle();

    if (!mounted) return;

    if (errorMsg == null) {
      unawaited(Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal));
    } else if (errorMsg == 'UsuarioNuevo' || errorMsg == 'UsuarioIncompleto') {
      unawaited(Navigator.pushReplacementNamed(context, '/completar_perfil'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
      );
    }
  }

  // Lógica de Login Manual (Admin)
  void _mostrarLoginManual() {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final usuarioCtrl = TextEditingController(text: auth.emailGuardado);
    final passCtrl = TextEditingController(text: auth.passwordGuardado);
    final formKey = GlobalKey<FormState>();

    bool recordarLocal = auth.recordarUsuario;
    bool cargandoLocal = false; // Estado de carga exclusivo del diálogo

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (innerContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Iniciar Sesión'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CampoTextoPersonalizado(
                      controller: usuarioCtrl,
                      label: 'Usuario o Correo',
                      prefixIcon: Icons.person,
                    ),
                    const SizedBox(height: 16),
                    CampoTextoPersonalizado(
                      controller: passCtrl,
                      label: 'Contraseña',
                      prefixIcon: Icons.lock,
                      isPassword: true,
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      title: const Text('Recordar usuario', style: TextStyle(fontSize: 14)),
                      value: recordarLocal,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        setStateDialog(() => recordarLocal = val!);
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: cargandoLocal ? null : () {
                          Navigator.pop(dialogContext);
                          _mostrarRecuperarPassword(usuarioCtrl.text);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: cargandoLocal ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: cargandoLocal ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setStateDialog(() => cargandoLocal = true);

                      // 1. Capturamos las dependencias de la pantalla principal ANTES del await
                      final auth = Provider.of<ControladorAuth>(context, listen: false);
                      final navigatorPantalla = Navigator.of(context);
                      final scaffoldMsg = ScaffoldMessenger.of(context);

                      // 2. Ejecutamos la tarea asíncrona
                      final errorMsg = await auth.iniciarSesion(usuarioCtrl.text, passCtrl.text);

                      // 3. Verificamos SOLO el contexto del diálogo para su estado y cerrarlo
                      if (!innerContext.mounted) return;
                      setStateDialog(() => cargandoLocal = false);

                      if (errorMsg == null) {
                        unawaited(auth.guardarPreferencias(usuarioCtrl.text, passCtrl.text, recordarLocal));

                        // Cerramos el diálogo usando su propio contexto ya validado
                        Navigator.pop(innerContext);

                        // Navegamos a la siguiente pantalla usando la referencia capturada
                        unawaited(navigatorPantalla.pushReplacementNamed(RutasApp.menuPrincipal));
                      } else {
                        // Mostramos el snackbar usando la referencia capturada
                        scaffoldMsg.showSnackBar(
                          SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: cargandoLocal
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Ingresar'),
                ),
              ],
            );
          }
      ),
    ).then((_) {
      // Nos aseguramos de destruir los controladores al cerrar el diálogo
      usuarioCtrl.dispose();
      passCtrl.dispose();
    });
  }

  void _mostrarRecuperarPassword(String correoRecomendado) {
    final correoCtrl = TextEditingController(text: correoRecomendado);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu correo electrónico y te enviaremos un enlace seguro para restablecer tu contraseña.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                CampoTextoPersonalizado(
                  controller: correoCtrl,
                  label: 'Correo Electrónico',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'El correo es obligatorio';
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(v)) return 'Correo inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext);
                  final auth = Provider.of<ControladorAuth>(context, listen: false);
                  final error = await auth.enviarCorreoRecuperacion(correoCtrl.text);

                  if (!mounted) return;
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Revisa tu bandeja de entrada o SPAM.'), backgroundColor: ColoresApp.exito, duration: Duration(seconds: 4)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: ColoresApp.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              child: const Text('Enviar Enlace'),
            ),
          ],
        );
      },
    ).then((_) => correoCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo/noti.png',
                  height: 100,
                ),
                const SizedBox(height: 24),

                ValueListenableBuilder<bool>(
                  valueListenable: _cargando,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                    }
                    return child!;
                  },
                  child: Column(
                    children: [
                      TarjetaPremium(
                        onTap: _ingresarConGoogle,
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://developers.google.com/identity/images/g-logo.png',
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 24,
                                    width: 24,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Text('G', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continuar con Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/registro_correo');
                        },
                        child: const Text('¿No tienes cuenta? Regístrate aquí'),
                      ),

                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: _mostrarLoginManual,
                        child: Text(
                          'Ingresar con Correo / Admin',
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formKey = GlobalKey<FormState>();

  final nombreCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();

  String? sexoSeleccionado;
  bool _cargando = false;

  @override
  void dispose() {
    nombreCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    celularCtrl.dispose();
    direccionCtrl.dispose();
    edadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ColoresApp.textoOscuro,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: TarjetaPremium(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registro Completo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  CampoTextoPersonalizado(
                    controller: emailCtrl,
                    label: 'Correo Electrónico',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El correo es obligatorio';
                      if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(v)) {
                        return 'Formato de correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: passCtrl,
                    label: 'Contraseña',
                    prefixIcon: Icons.lock,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const Divider(height: 30),

                  CampoTextoPersonalizado(
                    controller: nombreCtrl,
                    label: 'Nombre Completo',
                    prefixIcon: Icons.person,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: celularCtrl,
                    label: 'Celular',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El celular es obligatorio';
                      if (v.length < 9) return 'Debe tener 9 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: direccionCtrl,
                    label: 'Dirección (Opcional)',
                    prefixIcon: Icons.home,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTextoPersonalizado(
                          controller: edadCtrl,
                          label: 'Edad (Op.)',
                          prefixIcon: Icons.cake,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sexoSeleccionado,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Sexo (Op.)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                            ),
                            prefixIcon: Icon(Icons.wc, color: Theme.of(context).primaryColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          hint: const Text('Selec.'),
                          items: const [
                            DropdownMenuItem(value: 'Masculino', child: Text('Masculino', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Femenino', child: Text('Femenino', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => sexoSeleccionado = val),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_cargando)
                    const Center(child: CircularProgressIndicator())
                  else
                    BotonGradiente(
                      text: 'Registrarme',
                      icon: Icons.check_circle,
                      onPressed: _registrarUsuario,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    final error = await auth.registrarUsuarioCorreo(
      email: emailCtrl.text.trim(),
      password: passCtrl.text.trim(),
      nombre: nombreCtrl.text.trim(),
      celular: celularCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(),
      edad: int.tryParse(edadCtrl.text) ?? 0,
      sexo: sexoSeleccionado ?? 'No especificado',
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error == null) {
      unawaited(Navigator.pushNamedAndRemoveUntil(context, RutasApp.menuPrincipal, (route) => false));
    } else if (error == 'VERIFICACION_ENVIADA') {
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Registro Exitoso!'),
          content: const Text('Te hemos enviado un correo de verificación.\n\nPor favor revisa tu bandeja y haz clic en el enlace antes de iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(Navigator.pushNamedAndRemoveUntil(context, '/inicio_sesion', (route) => false));
              },
              child: const Text('Entendido, ir al Login'),
            )
          ],
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: ColoresApp.error),
      );
    }
  }
}

class PantallaCompletarPerfil extends StatefulWidget {
  const PantallaCompletarPerfil({super.key});

  @override
  State<PantallaCompletarPerfil> createState() => _PantallaCompletarPerfilState();
}

class _PantallaCompletarPerfilState extends State<PantallaCompletarPerfil> {
  final _formKey = GlobalKey<FormState>();

  final nombreCtrl = TextEditingController();
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();

  String? sexoSeleccionado;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Corregido: La inicialización segura se realiza aquí, no en el build
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final user = auth.usuarioActual;
    if (user != null) {
      nombreCtrl.text = user.nombre == 'Usuario' ? '' : user.nombre;
    }
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    celularCtrl.dispose();
    direccionCtrl.dispose();
    edadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Completar Perfil'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ColoresApp.textoOscuro,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: TarjetaPremium(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.security_update_good, size: 60, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    "¡Casi listo, ${user?.nombre ?? 'Usuario'}!",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para continuar, necesitamos algunos datos adicionales para tu ficha de alumno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30),

                  CampoTextoPersonalizado(
                    controller: nombreCtrl,
                    label: 'Nombre Completo *',
                    prefixIcon: Icons.person,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: celularCtrl,
                    label: 'Celular *',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El celular es obligatorio';
                      if (v.trim().length < 9) return 'Debe tener 9 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: direccionCtrl,
                    label: 'Dirección (Opcional)',
                    prefixIcon: Icons.home,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CampoTextoPersonalizado(
                          controller: edadCtrl,
                          label: 'Edad',
                          prefixIcon: Icons.cake,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: sexoSeleccionado,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Sexo (Opcional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                            ),
                            prefixIcon: Icon(Icons.wc, color: Theme.of(context).primaryColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          hint: const Text('Selec.'),
                          items: const [
                            DropdownMenuItem(value: 'Masculino', child: Text('Masculino', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Femenino', child: Text('Femenino', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => sexoSeleccionado = val),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  BotonGradiente(
                    text: 'Guardar Datos',
                    icon: Icons.save,
                    isLoading: _cargando,
                    onPressed: _guardarDatos,
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                      onPressed: () {
                        auth.cerrarSesion();
                        Navigator.pushReplacementNamed(context, '/inicio_sesion');
                      },
                      child: const Text('Cancelar y Salir', style: TextStyle(color: ColoresApp.error))
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    final errorMsg = await auth.completarPerfil(
      nombre: nombreCtrl.text.trim(),
      celular: celularCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(),
      edad: int.tryParse(edadCtrl.text) ?? 0,
      sexo: sexoSeleccionado ?? 'No especificado',
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (errorMsg == null) {
      unawaited(Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
      );
    }
  }
}