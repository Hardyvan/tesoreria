import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesBack/a_controlador_auth.dart';
import 'c_menu_principal.dart';
import '../myPages/a_inicio_sesion.dart';
import '../myPages/i_completar_perfil.dart';

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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _escalaAnimacion = CurvedAnimation(
      parent: _controlador,
      curve: Curves.elasticOut,
    );

    _opacidadAnimacion = CurvedAnimation(
      parent: _controlador,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // Iniciar secuencia después del primer frame y remover splash nativo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Removemos el splash nativo si existe (para evitar solapamiento)
      // Nota: Si no se configuró flutter_native_splash.yaml, esto solo quita el splash blanco por defecto
      try {
        FlutterNativeSplash.remove(); 
      } catch (e) {
        // Ignorar si no estaba presente
      }
      _iniciarSecuencia();
    });
  }

  Future<void> _iniciarSecuencia() async {
    try {
      // Ejecutamos la animación y la espera mínima de forma paralela
      // Y TAMBIÉN verificamos la sesión (Optimización de tiempo)
      final auth = Provider.of<ControladorAuth>(context, listen: false);
      
      await Future.wait([
        _controlador.forward().orCancel,
        Future.delayed(const Duration(milliseconds: 2800)),
        auth.verificarSesion(), // Hacemos la verificación aquí
      ]);

      if (!mounted) return;
      
      // Lógica de Navegación Inteligente (Acoplada a InSOFT Auth)
      _navegarSegunEstado();
      
    } catch (e) {
      // Manejo de cancelación si el widget se destruye
    }
  }
  
  void _navegarSegunEstado() {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final usuario = auth.usuarioActual;
    
    Widget destino;
    
    if (usuario == null) {
      // No logueado -> Login
      destino = const InicioSesion();
    } else if (usuario.celular.isEmpty) {
      // Logueado pero SIN DATOS (Protocolo Híbrido) -> Completar Perfil
      destino = const PantallaCompletarPerfil();
    } else {
      // Todo OK -> Menú
      destino = const MenuPrincipal();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destino,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
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
    // Usamos el color de fondo definido en el tema
    return Scaffold(
      backgroundColor: ColoresApp.fondoClaro,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _construirLogoAnimado(),
                const SizedBox(height: 40),
                _construirIndicadorCarga(),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _construirPiePaginaMarca(),
          ),
        ],
      ),
    );
  }

  Widget _construirLogoAnimado() {
    return ScaleTransition(
      scale: _escalaAnimacion,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ColoresApp.fondoClaro, // Fondo blanco para que resalte el logo
          boxShadow: [
            BoxShadow(
              color: ColoresApp.primario.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/logo/gallos.png', // Tu archivo de imagen
            width: 250,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.savings, // Icono de tesorería/chanchito por defecto si no hay imagen
              size: 150, // Ajustado
              color: ColoresApp.primario
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirIndicadorCarga() {
    return FadeTransition(
      opacity: _opacidadAnimacion,
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(ColoresApp.primario),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "CARGANDO EXPERIENCIA...",
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
              color: ColoresApp.primario.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPiePaginaMarca() {
    return FadeTransition(
      opacity: _opacidadAnimacion,
      child: Column(
        children: [
          const Text(
            "Powered by",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          const Text(
            "InSOFT", // Tu marca oficial
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: ColoresApp.primario,
            ),
          ),
          const Text(
            "Convertimos Ideas en Software que Funciona", // Tu eslogan
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
