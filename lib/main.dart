import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Importante para idioma
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante para Firebase
import 'package:dsi/myPagesTema/a_tema.dart';

import 'myMenu/a_pantalla_bienvenida.dart';

// Importamos Controllers
import 'myPagesBack/a_logica_inicio_sesion.dart';
import 'myPagesBack/b_logica_estado_financiero.dart';
import 'myPagesBack/e_logica_actividades.dart';
import 'myPagesBack/f_logica_perfil.dart'; // Controlador Usuarios
import 'myPagesBack/h_servicio_conectividad.dart';

// Importamos Rutas
import 'myMenu/b_rutas_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para fechas
// Para MethodChannel

import 'myPagesTema/b_ui_kit.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

// No es necesario import 'package:tesoreria_ivan/myPagesTema/b_ui_kit.dart'; para el Banner, ya está en misPagesTema/b_ui_kit.dart

Future<void> main() async {
  // Aseguramos binding para operaciones asíncronas antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // BLOQUEO DE CAPTURAS DE PANTALLA (Nativo Android con flutter_windowmanager)
  try {
     await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  } catch (e) {
     debugPrint('No se pudo establecer FLAG_SECURE: $e');
  }

  // Inicializamos Firebase (Sin opciones, usa google-services.json)
  await Firebase.initializeApp();

  // Cargamos variables de entorno
  await dotenv.load(fileName: '.env');

  // Inicializar formato de fechas para Intl (Español)
  await initializeDateFormatting('es_PE', null);

  runApp(
    MultiProvider(
      providers: [
        // Tema
        ChangeNotifierProvider(create: (_) => ProveedorTema()),
        
        // Lógica de Negocio (Back)
        ChangeNotifierProvider(create: (_) => ControladorAuth()),
        ChangeNotifierProvider(create: (_) => ControladorFinanzas()),
        ChangeNotifierProvider(create: (_) => ControladorActividades()),
        ChangeNotifierProvider(create: (_) => ControladorUsuarios()),
        ChangeNotifierProvider(create: (_) => ServicioConectividad()), // Nuevo Servicio
      ],
      child: const MiApp(),
    ),
  );
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final providerM = Provider.of<ProveedorTema>(context);
    
    return MaterialApp(
      title: 'DSI',
      debugShowCheckedModeBanner: false,
      
      // Configuración de Tema
      theme: TemaApp.obtenerTema(AppPalettes.light(primary: providerM.colorSeleccionado, style: providerM.estiloSeleccionado)),
      darkTheme: TemaApp.obtenerTema(AppPalettes.dark(primary: providerM.colorSeleccionado, style: providerM.estiloSeleccionado)),
      themeMode: providerM.modoTema,

      // Configuración de Idioma (Español)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'PE'), // Español Perú
      ],
      
      // Banner de Conexión y Responsividad Global
      builder: (context, child) {
        final columnChild = Column(
          children: [
             Expanded(child: child ?? const SizedBox()),
             const BannerSinConexion(),
          ],
        );
        
        return Container(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black87 
              : Colors.blueGrey.shade50,
          child: ContenedorMaximoLectura(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor, // Mantiene el color base del app
              child: columnChild,
            ),
          ),
        );
      },
      // Pantalla Inicial (Wrapper de Login)
      home: const PantallaBienvenida(),
      
      // Definición de Rutas Nombradas
      routes: RutasApp.obtenerRutas(),
    );
  }
}
