import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_client.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import 'c_menu_principal.dart';
import '../myPages/a_inicio_sesion.dart';
import '../myPages/j_terminos_condiciones.dart';
import '../myPagesBack/k_gerente_notificaciones.dart';
import '../myPagesTema/g_fondo_animado.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _escalaAnimacion;
  late final Animation<double> _opacidadAnimacion;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _escalaAnimacion = CurvedAnimation(
      parent: _controlador,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    );

    _opacidadAnimacion = CurvedAnimation(
      parent: _controlador,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // Iniciar secuencia después del primer frame y remover splash nativo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove(); 
      } catch (e) {
        // Ignorar si no estaba presente
      }
      _iniciarSecuencia();
    });
  }

  bool _terminosAceptados = false;
  bool _actualizacionObligatoria = false;
  bool _actualizacionOpcional = false;
  String _mensajeUpdate = '';
  String _urlPlayStore = '';

  int _compararVersiones(String v1, String v2) {
    try {
      final partes1 = v1.split('.').map(int.parse).toList();
      final partes2 = v2.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final val1 = i < partes1.length ? partes1[i] : 0;
        final val2 = i < partes2.length ? partes2[i] : 0;
        if (val1 > val2) return 1;
        if (val1 < val2) return -1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _chequearControlVersion() async {
    try {
      final response = await ApiClient().post('obtenerControlVersion');
      if (response['ok'] == true) {
        final versionActual = response['version_actual']?.toString() ?? '1.0.0';
        final versionMinima = response['version_minima']?.toString() ?? '1.0.0';
        _urlPlayStore = response['url_play_store']?.toString() ?? '';

        const String versionLocal = '1.1.0'; // Versión local del app

        if (_compararVersiones(versionLocal, versionMinima) < 0) {
          _actualizacionObligatoria = true;
          _mensajeUpdate = response['mensaje_obligatorio'] ?? 'Es necesaria una nueva versión para continuar.';
        } else if (_compararVersiones(versionLocal, versionActual) < 0) {
          _actualizacionOpcional = true;
          _mensajeUpdate = response['mensaje_opcional'] ?? 'Hay mejoras disponibles en Google Play Store.';
        }
      }
    } catch (e) {
      debugPrint('Error chequeando control de versión: $e');
    }
  }

  Future<void> _abrirPlayStore() async {
    final uri = Uri.parse(_urlPlayStore.isNotEmpty ? _urlPlayStore : 'https://play.google.com/store/apps/details?id=pe.insoft.tesoreria.dsi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _mostrarDialogoActualizacion({required bool obligatorio}) async {
    await showDialog(
      context: context,
      barrierDismissible: !obligatorio, // Si es opcional, se puede tocar fuera para cerrar
      builder: (context) {
        return PopScope(
          canPop: !obligatorio, // Si es opcional, se puede retroceder con el botón atrás nativo
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  obligatorio ? Icons.system_update_rounded : Icons.info_outline_rounded,
                  color: obligatorio ? Colors.red.shade400 : Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  obligatorio ? 'Actualizar App' : 'Nueva Versión',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              _mensajeUpdate,
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
            actions: [
              if (!obligatorio)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Más tarde',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _abrirPlayStore();
                  if (!obligatorio && mounted) {
                    navigator.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: obligatorio ? Colors.red.shade400 : Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Actualizar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Al cerrarse el diálogo por cualquier medio (clic en 'Más tarde', tocar fuera, botón atrás):
    if (!obligatorio && mounted) {
      _navegarSegunEstado();
    }
  }

  Future<void> _iniciarSecuencia() async {
    try {
      // Iniciamos animación
      unawaited(_controlador.forward());
      
      final auth = Provider.of<ControladorAuth>(context, listen: false);
      
      // Inicializar notificaciones en segundo plano
      unawaited(GerenteNotificaciones().inicializar());
      
      // Espera de carga, validación de sesión y control de versión en paralelo
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 3200)),
        auth.verificarSesion(),
        _chequearControlVersion(),
      ]);

      if (!mounted) return;

      // Si hay sesión activa, verificar si aceptó los términos
      final usuario = auth.usuarioActual;
      if (usuario != null) {
        _terminosAceptados = usuario.terminosAceptados;
      }
      
      // Procesar ingreso considerando la versión y términos
      _procesarIngreso();
      
    } catch (e) {
      // Manejo seguro de interrupción
    }
  }

  void _procesarIngreso() {
    if (_actualizacionObligatoria) {
      _mostrarDialogoActualizacion(obligatorio: true);
    } else if (_actualizacionOpcional) {
      _mostrarDialogoActualizacion(obligatorio: false);
    } else {
      _navegarSegunEstado();
    }
  }
  
  void _navegarSegunEstado() {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final usuario = auth.usuarioActual;
    
    Widget destino;
    
    if (usuario == null) {
      destino = const InicioSesion();
    } else if (usuario.celular.isEmpty) {
      destino = const PantallaCompletarPerfil();
    } else if (!_terminosAceptados) {
      destino = const PantallaTerminos();
    } else {
      destino = const MenuPrincipal();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destino,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: FondoAnimadoPremium(
        clima: TipoClimaFondo.aurora,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Contenido Principal Central
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Contenedor Glassmorphism Premium
                      ClipRRect(
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
                                    ? theme.primaryColor.withValues(alpha: 0.15)
                                    : theme.primaryColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 40,
                                  spreadRadius: -10,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _construirLogoAnimado(),
                                const SizedBox(height: 35),
                                
                                // Título e Identidad
                                FadeTransition(
                                  opacity: _opacidadAnimacion,
                                  child: Column(
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: [Colors.white, theme.colorScheme.secondary],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                        child: const Text(
                                          'TESORERÍA DSI',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: 60,
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
                                      const SizedBox(height: 12),
                                      Text(
                                        'Gestión Financiera',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.0,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                                _construirIndicadorCarga(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Pie de Página Corporativo Flotante
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _construirPiePaginaMarca(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirLogoAnimado() {
    final theme = Theme.of(context);
    
    return ScaleTransition(
      scale: _escalaAnimacion,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10), // Sombra con desplazamiento vertical suave
            ),
            BoxShadow(
              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Container(
            width: 180,
            height: 180,
            color: Colors.white, // Fondo puro para que el logo png se vea asombroso
            child: Image.asset(
              'assets/logo/DSI.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.savings_rounded,
                size: 90,
                color: theme.primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirIndicadorCarga() {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _opacidadAnimacion,
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'INICIANDO EXPERIENCIA...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPiePaginaMarca() {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _opacidadAnimacion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Powered by',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9, 
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'InSOFT',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: theme.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Software Inteligente que Transforma',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
