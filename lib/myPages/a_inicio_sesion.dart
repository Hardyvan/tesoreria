import 'dart:async';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:dsi/myPagesTema/a_tema.dart';
import 'package:dsi/myPagesTema/c_ui_kit.dart';

// TUS IMPORTS DE INSOFT

import '../myPagesBack/a_controlador_auth.dart';
import '../myMenu/b_rutas_app.dart';

class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  bool _cargando = false;

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
                    setState(() => _cargando = true);
                    
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
                    
                    if (mounted) setState(() => _cargando = false);
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
              Text(
                'DSI Tesorería',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gestiona los fondos del salón\nde forma transparente.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),

              if (_cargando)
                const CircularProgressIndicator()
              else
                Column(
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
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                height: 24,
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
            ],
          ),
        ),
      ),
    );
  }
}
