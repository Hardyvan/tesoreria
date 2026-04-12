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

  // ---------------------------------------------------------------------------
  // LÓGICA DE LOGIN (Delegada al Controlador)
  // ---------------------------------------------------------------------------
  Future<void> _ingresarConGoogle() async {
    // Ya no setteamos _cargando localmente porque lo escuchamos del Provider
    // Sin embargo, para UX inmediata, podemos dejarlo o confiar en el listener.
    // Lo ideal es usar el estado del provider.
    
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final errorMsg = await auth.ingresarConGoogle();

    if (!mounted) return;

    if (errorMsg == null) {
      // Login exitoso y completo
      unawaited(Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal));
    } else if (errorMsg == 'UsuarioNuevo' || errorMsg == 'UsuarioIncompleto') {
      // Necesita completar perfil -> Navegar a pantalla de completar
      unawaited(Navigator.pushReplacementNamed(context, '/completar_perfil'));
    } else {
      // Error real
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
       );
    }
  }

  // AQUÍ CONECTAS CON TU SERVIDOR EN dsi.net.pe


  // Lógica de Login Manual (Admin)
  void _mostrarLoginManual() {
    final auth = Provider.of<ControladorAuth>(context, listen: false); // Solo para leer iniciales
    final usuarioCtrl = TextEditingController(text: auth.emailGuardado); // Pre-llenar
    final passCtrl = TextEditingController(text: auth.passwordGuardado); // Pre-llenar password
    final formKey = GlobalKey<FormState>();
    
    // Estado local para el checkbox del diálogo
    bool recordarLocal = auth.recordarUsuario;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder( // StatefulBuilder para actualizar checkbox
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
                  
                  // CHECKBOX "RECORDARME"
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
                    Navigator.pop(dialogContext); // Cerrar diálogo
                    _cargando.value = true;
                    
                    final auth = Provider.of<ControladorAuth>(context, listen: false);
                    final errorMsg = await auth.iniciarSesion(usuarioCtrl.text, passCtrl.text);

                    if (!mounted) return;

                    if (errorMsg == null) {
                       // GUARDAR PREFERENCIA SI ÉXITO
                       unawaited(auth.guardarPreferencias(usuarioCtrl.text, passCtrl.text, recordarLocal));
                       
                       if (mounted) {
                          unawaited(Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal));
                       }
                    } else {
                       if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
                          );
                       }
                    }
                    
                    if (mounted) _cargando.value = false;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ingresar'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. LOGO DE LA APP
              Image.asset(
                'assets/logo/DSI.png',
                height: 100,
                // Si la imagen DSI.png es rectangular ancha, usa un ancho también en lugar de height: 100
                // Para redonder bordes si fuera necesario, envolver en ClipRRect.
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
                    // 2. BOTÓN DE GOOGLE PERSONALIZADO (Professional Standard)
                    TarjetaPremium(
                      onTap: _ingresarConGoogle,
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30), // Bordes más redondeados (Pill shape)
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
                                  // Fallback: Si la red bloquea la descarga, muestra una 'G' local amigable.
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
                    
                    // BOTÓN REGISTRARSE (Correo)
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/registro_correo');
                      },
                      child: const Text('¿No tienes cuenta? Regístrate aquí'),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Opción secundaria discreta (Ahora general)
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
  
  // Controladores
  final nombreCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();
  
  String? sexoSeleccionado;
  bool _cargando = false;

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
                  
                  // 1. Datos de Cuenta
                  CampoTextoPersonalizado(
                    controller: emailCtrl,
                    label: 'Correo Electrónico',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El correo es obligatorio';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
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

                  // 2. Datos Personales
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
                          label: 'Edad (Op.)', // Texto más corto para evitar overflow
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
    // VALIDACIÓN: El formulario ya se encargó de verificar vacíos y formatos.

    setState(() => _cargando = true);
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    // Si edad o dirección están vacíos, mandamos valores por defecto
    final error = await auth.registrarUsuarioCorreo(
      email: emailCtrl.text.trim(),
      password: passCtrl.text.trim(),
      nombre: nombreCtrl.text.trim(),
      celular: celularCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(), // Puede ir vacío
      edad: int.tryParse(edadCtrl.text) ?? 0, // Si falla o es vacío, va 0
      sexo: sexoSeleccionado ?? 'No especificado',
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error == null) {
      // Éxito Total (Quizás recuperación inmediata) -> Ir al Home
      unawaited(Navigator.pushNamedAndRemoveUntil(context, RutasApp.menuPrincipal, (route) => false));
    
    } else if (error == 'VERIFICACION_ENVIADA') {
      // Registro exitoso, pero requiere validación
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
                // Ir al Login para que ingrese sus datos
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
  
  // Controladores
  final nombreCtrl = TextEditingController();
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();
  
  String? sexoSeleccionado;
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    // Obtenemos los datos que ya tenemos (Nombre, Email) del Controlador
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;
    
    // Inicializar nombre si está vacío
    if (nombreCtrl.text.isEmpty && user != null) {
      nombreCtrl.text = user.nombre == 'Usuario' ? '' : user.nombre;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Completar Perfil'),
        automaticallyImplyLeading: false, // No permitir volver atrás sin completar
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

                  // Llenar Datos Faltantes
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
                        flex: 2, // Menos espacio para la edad
                        child: CampoTextoPersonalizado(
                          controller: edadCtrl,
                          label: 'Edad', // Etiqueta más corta
                          prefixIcon: Icons.cake,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3, // Más espacio para el texto "Masculino/Femenino"
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
      direccion: direccionCtrl.text.trim(), // Opcional
      edad: int.tryParse(edadCtrl.text) ?? 0, // Opcional
      sexo: sexoSeleccionado ?? 'No especificado',
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (errorMsg == null) {
      // Éxito -> Ir al Menu
      unawaited(Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: ColoresApp.error),
      );
    }
  }
}
