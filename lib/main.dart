import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante para Firebase
import 'myPagesTema/a_tema_app.dart';
import 'myMenu/a_pantalla_bienvenida.dart';

// Importamos Controllers
import 'myPagesBack/a_controlador_auth.dart';
import 'myPagesBack/b_controlador_finanzas.dart';
import 'myPagesBack/c_controlador_actividades.dart';
import 'myPagesBack/d_controlador_usuarios.dart'; // Controlador Usuarios

// Importamos Rutas
import 'myMenu/b_rutas_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  // Aseguramos binding para operaciones asíncronas antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos Firebase (Sin opciones, usa google-services.json)
  await Firebase.initializeApp();

  // Cargamos variables de entorno
  await dotenv.load(fileName: ".env");

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
      title: 'Tesorería InSOFT',
      debugShowCheckedModeBanner: false,
      
      // Configuración de Tema
      theme: TemaApp.obtenerTema(false),
      darkTheme: TemaApp.obtenerTema(true),
      themeMode: providerM.modoTema,
      
      // Pantalla Inicial (Wrapper de Login)
      home: const PantallaBienvenida(),
      
      // Definición de Rutas Nombradas
      routes: RutasApp.obtenerRutas(),
    );
  }
}
