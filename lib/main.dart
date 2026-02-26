import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Importante para idioma
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante para Firebase
import 'package:dsi/myPagesTema/a_tema.dart';

import 'myMenu/a_pantalla_bienvenida.dart';

// Importamos Controllers
import 'myPagesBack/a_controlador_auth.dart';
import 'myPagesBack/b_controlador_finanzas.dart';
import 'myPagesBack/c_controlador_actividades.dart';
import 'myPagesBack/d_controlador_usuarios.dart'; // Controlador Usuarios
import 'myPagesBack/a_servicio_conectividad.dart';

// Importamos Rutas
import 'myMenu/b_rutas_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para fechas
import 'package:flutter/services.dart'; // Para MethodChannel

import 'globals.dart'; // Importante para BannerSinConexion

Future<void> main() async {
  // Aseguramos binding para operaciones asíncronas antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // BLOQUEO DE CAPTURAS DE PANTALLA (Nativo Android)
  try {
     const platform = MethodChannel('com.insoft.tesoreria/seguridad');
     await platform.invokeMethod('protegerPantalla');
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
      
      // Banner de Conexión Global
      builder: (context, child) {
        return Column(
          children: [
             Expanded(child: child ?? const SizedBox()),
             const BannerSinConexion(),
          ],
        );
      },

      // Pantalla Inicial (Wrapper de Login)
      home: const PantallaBienvenida(),
      
      // Definición de Rutas Nombradas
      routes: RutasApp.obtenerRutas(),
    );
  }
}
