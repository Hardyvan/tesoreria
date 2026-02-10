import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'dart:ui'; // Descomenta si usas FontFeature

// =============================================================================
// 1. THEME EXTENSION (LA GRAN MEJORA)
// Permite usar: Theme.of(context).extension<InsoftColors>()!.estadoPagado
// =============================================================================
@immutable
class InsoftColors extends ThemeExtension<InsoftColors> {
  final Color? estadoPendiente;
  final Color? estadoPagado;
  final Color? estadoDeudor;
  final Color? kanbanHaciendo;
  final Color? kanbanHecho;

  const InsoftColors({
    required this.estadoPendiente,
    required this.estadoPagado,
    required this.estadoDeudor,
    required this.kanbanHaciendo,
    required this.kanbanHecho,
  });

  @override
  InsoftColors copyWith({Color? estadoPendiente, Color? estadoPagado, Color? estadoDeudor, Color? kanbanHaciendo, Color? kanbanHecho}) {
    return InsoftColors(
      estadoPendiente: estadoPendiente ?? this.estadoPendiente,
      estadoPagado: estadoPagado ?? this.estadoPagado,
      estadoDeudor: estadoDeudor ?? this.estadoDeudor,
      kanbanHaciendo: kanbanHaciendo ?? this.kanbanHaciendo,
      kanbanHecho: kanbanHecho ?? this.kanbanHecho,
    );
  }

  @override
  InsoftColors lerp(ThemeExtension<InsoftColors>? other, double t) {
    if (other is! InsoftColors) return this;
    return InsoftColors(
      estadoPendiente: Color.lerp(estadoPendiente, other.estadoPendiente, t),
      estadoPagado: Color.lerp(estadoPagado, other.estadoPagado, t),
      estadoDeudor: Color.lerp(estadoDeudor, other.estadoDeudor, t),
      kanbanHaciendo: Color.lerp(kanbanHaciendo, other.kanbanHaciendo, t),
      kanbanHecho: Color.lerp(kanbanHecho, other.kanbanHecho, t),
    );
  }

  // Definición de colores para MODO CLARO
  static const light = InsoftColors(
    estadoPendiente: Color(0xFFFB923C), // Naranja
    estadoPagado: Color(0xFF10B981),    // Verde Esmeralda
    estadoDeudor: Color(0xFFE11D48),    // Rojo Rosa
    kanbanHaciendo: Color(0xFF7DD3FC),
    kanbanHecho: Color(0xFF6EE7B7),
  );

  // Definición de colores para MODO OSCURO (Más desaturados para no cansar la vista)
  static const dark = InsoftColors(
    estadoPendiente: Color(0xFFC2410C), // Naranja más oscuro
    estadoPagado: Color(0xFF047857),    // Verde más oscuro
    estadoDeudor: Color(0xFF9F1239),    // Rojo más oscuro
    kanbanHaciendo: Color(0xFF075985),
    kanbanHecho: Color(0xFF065F46),
  );
}

// =============================================================================
// 2. PALETA BASE Y CONSTANTES
// =============================================================================
class AppTokens {
  static const double radioMedio = 12.0;
  static const double radioGrande = 20.0; // Añadido para compatibilidad
  static const double paddingEstandar = 20.0; // Añadido para compatibilidad
  
  // Colores Base (InSOFT Brand)
  static const Color brandBlue = Color(0xFF003162);
  static const Color brandOrange = Color(0xFFFF9100);
  
  static const Color darkBg = Color(0xFF0A111F);
  static const Color lightBg = Color(0xFFF4F7F9);
  
  // Gradientes (Mantenidos para compatibilidad con botones)
  static const LinearGradient gradientePrimario = LinearGradient(
    colors: [Color(0xFF003162), Color(0xFF001E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Sombras (Mantenidas para compatibilidad)
  static final List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: const Color(0xFF003162).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: -5,
    ),
  ];
}

// Wrapper para compatibilidad con código existente que usa ColoresApp y DimensionesApp
// Esto facilitará la transición, pero lo ideal es refactorizar a AppTokens gradualmente
class ColoresApp {
  static const Color primario = AppTokens.brandBlue;
  static const Color secundario = AppTokens.brandOrange;
  static const Color fondoClaro = AppTokens.lightBg;
  static const Color fondoOscuro = AppTokens.darkBg;
  static const LinearGradient gradientePrimario = AppTokens.gradientePrimario;
  static List<BoxShadow> get sombraSuave => AppTokens.sombraSuave;
  static const Color exito = Color(0xFF10B981); // Fallback estatico
  static const Color error = Color(0xFFE11D48); // Fallback estatico
  static const Color superficieClara = Color(0xFFFFFFFF);
  static const Color superficieOscura = Color(0xFF162133);
  static const Color primarioContenedor = Color(0xFFE3F2FD);
  static const Color textoSecundarioClaro = Color(0xFF475569);
  
  // Compatibilidad
  static const Color fondo = AppTokens.lightBg;
  static const Color textoOscuro = Color(0xFF162133);
}

class DimensionesApp {
  static const double radioMedio = AppTokens.radioMedio;
  static const double radioGrande = AppTokens.radioGrande;
  static const double paddingEstandar = AppTokens.paddingEstandar;
}


// =============================================================================
// 3. TEMA APP (Optimizado con Extensions)
// =============================================================================
class TemaApp {
  
  static ThemeData obtenerTema(bool esOscuro) {
    // Variables dinámicas según el modo
    final colorFondo = esOscuro ? AppTokens.darkBg : AppTokens.lightBg;
    final colorPrimario = esOscuro ? const Color(0xFFE3F2FD) : AppTokens.brandBlue;
    final extensionColores = esOscuro ? InsoftColors.dark : InsoftColors.light;

    // Base del tema
    final baseTheme = esOscuro ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorFondo,
      
      // Aquí inyectamos nuestros colores semánticos
      extensions: [extensionColores],

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTokens.brandBlue,
        brightness: esOscuro ? Brightness.dark : Brightness.light,
        primary: colorPrimario,
        secondary: AppTokens.brandOrange,
        surface: esOscuro ? const Color(0xFF162133) : Colors.white,
      ),

      // Tipografía optimizada (Usando apply para no repetir fontFamily)
      textTheme: baseTheme.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: esOscuro ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        displayColor: esOscuro ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      ).copyWith(
        displayLarge: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        headlineLarge: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),

      // Input Decoration unificado
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esOscuro ? const Color(0xFF162133) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radioMedio),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radioMedio),
          borderSide: BorderSide(
            color: esOscuro ? Colors.white10 : Colors.black12
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radioMedio),
          borderSide: BorderSide(color: AppTokens.brandOrange, width: 2),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. PROVIDER (Sin cambios mayores, solo limpieza)
// =============================================================================
class ProveedorTema extends ChangeNotifier {
  ThemeMode _modoTema = ThemeMode.system;
  ThemeMode get modoTema => _modoTema;

  void cambiarTema(bool esOscuro) {
    _modoTema = esOscuro ? ThemeMode.dark : ThemeMode.light;
    _actualizarSystemUI();
    notifyListeners();
  }

  void _actualizarSystemUI() {
    // Lógica simple para actualizar la barra de estado
    final esOscuro = _modoTema == ThemeMode.dark; // Simplificado para el ejemplo
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: esOscuro ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: esOscuro ? AppTokens.darkBg : AppTokens.lightBg,
    ));
  }
}
