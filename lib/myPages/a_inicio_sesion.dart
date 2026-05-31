import 'dart:async';
import 'dart:ui';
import '../myPagesTema/b_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dsi/myPagesTema/a_tema.dart';
import '../myPagesTema/g_fondo_animado.dart';

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

  Future<void> _redireccionarSegunTerminos(NavigatorState navigator, int usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    final terminosAceptados = prefs.getBool('terms_accepted_$usuarioId') ?? false;

    if (terminosAceptados) {
      unawaited(navigator.pushReplacementNamed(RutasApp.menuPrincipal));
    } else {
      unawaited(navigator.pushReplacementNamed(RutasApp.terminosCondiciones));
    }
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE LOGIN (Delegada al Controlador)
  // ---------------------------------------------------------------------------
  Future<void> _ingresarConGoogle() async {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final navigator = Navigator.of(context);
    final errorMsg = await auth.ingresarConGoogle();

    if (!mounted) return;

    if (errorMsg == null) {
      unawaited(_redireccionarSegunTerminos(navigator, auth.usuarioActual!.id));
    } else if (errorMsg == 'UsuarioNuevo' || errorMsg == 'UsuarioIncompleto') {
      unawaited(navigator.pushReplacementNamed('/completar_perfil'));
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
                         unawaited(_redireccionarSegunTerminos(navigatorPantalla, auth.usuarioActual!.id));
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: FondoAnimadoPremium(
        clima: TipoClimaFondo.aurora,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)   // Perspectiva 3D
                  ..rotateY(0.04)          // Inclinación sutil Y
                  ..rotateX(-0.02),        // Inclinación sutil X
                alignment: FractionalOffset.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: -10,
                            offset: const Offset(-8, 16), // Sombra con desviación tridimensional
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo Circular Estilizado con Resplandor
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                width: 130,
                                height: 130,
                                color: Colors.white,
                                child: Image.asset(
                                  'assets/logo/noti.png',
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.savings_rounded,
                                    size: 65,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
  
                          // Identidad de Acceso
                          Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 45,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.secondary,
                                  Colors.white,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 30),
  
                          // Cargando / Formulario
                          ValueListenableBuilder<bool>(
                            valueListenable: _cargando,
                            builder: (context, isLoading, childWidget) {
                              if (isLoading) {
                                return const SizedBox(
                                  height: 140,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                );
                              }
                              return childWidget!;
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Botón de Google Estilo Glass
                                GestureDetector(
                                  onTap: _ingresarConGoogle,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
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
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Text(
                                                'G',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Continuar con Google',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
  
                                // Registrarse Enlace
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/registro_correo');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: Text(
                                    '¿No tienes cuenta? Regístrate aquí',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
  
                                // Ingresar con Correo / Admin
                                TextButton(
                                  onPressed: _mostrarLoginManual,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: Text(
                                    'Ingresar con Correo / Admin',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
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
              ),
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