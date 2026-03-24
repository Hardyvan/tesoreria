import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// 1. THEME EXTENSION (PALETA DE ESTADOS CORPORATIVOS INSOFT)
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

  static const light = InsoftColors(
    estadoPendiente: Color(0xFFFF9900),
    estadoPagado:    Color(0xFF2E7D32),
    estadoDeudor:    Color(0xFFC62828),
    kanbanHaciendo:  Color(0xFF1565C0),
    kanbanHecho:     Color(0xFF6A1B9A),
  );

  static const dark = InsoftColors(
    estadoPendiente: Color(0xFFFFB74D),
    estadoPagado:    Color(0xFF66BB6A),
    estadoDeudor:    Color(0xFFEF5350),
    kanbanHaciendo:  Color(0xFF42A5F5),
    kanbanHecho:     Color(0xFFAB47BC),
  );
}

// =============================================================================
// 2. PALETA BASE Y CONSTANTES
// =============================================================================
class AppTokens {
  static const double paddingEstandar = 20.0;
  static const Color darkBg = Color(0xFF0F172A); // Un poco más profundo/elegante
  static const Color lightBg = Color(0xFFF8FAFC); // Gris muy limpio

  static final List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04), // Sombra más sutil
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];
}

class DimensionesApp {
  static const double paddingEstandar = AppTokens.paddingEstandar;
  static const double radioMedio = 12.0;
  static const double radioGrande = 16.0;
}

enum AppThemeColor { azul, bosque, morado }

class ColoresApp {
  static const Color error = Color(0xFFD32F2F);
  static const Color exito = Color(0xFF2E7D32);
  static const Color textoSecundarioClaro = Color(0xFF78909C);
  static const Color textoPrimarioOscuro = Color(0xFF000000);
  static const Color secundario = AppPalettes.defaultSecondary;
  static const Color estadoPendiente = Color(0xFFF57C00);

  static const Color superficieClara = Color(0xFFFFFFFF);
  static const Color superficieOscura = Color(0xFF1E293B); // Slate 800 (Tailwind)
  static const Color textoOscuro = Color(0xFFF8FAFC);

  static final List<BoxShadow> sombraSuave = AppTokens.sombraSuave;
}

// =============================================================================
// 3. CONFIGURACIÓN DINÁMICA DE TEMA Y ESTILOS
// =============================================================================
enum AppStyle { standard, modern, elegant, tech }

class ThemeConfig {
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color onBackground;
  final AppStyle style;

  const ThemeConfig({
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.onBackground,
    required this.style,
  });

  bool get isDark => brightness == Brightness.dark;
}

class AppPalettes {
  // 1. GENERADOR DE MATERIAL COLOR
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.r.toInt(), g = color.g.toInt(), b = color.b.toInt();

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  // 2. COLORES PERSONALIZADOS
  static final MaterialColor insoftBlue = _createMaterialColor(const Color(0xFF003162));
  static final MaterialColor foodOrange = _createMaterialColor(const Color(0xFFFF6B00));
  static final MaterialColor carbon = _createMaterialColor(const Color(0xFF2C3E50));

  static const Color defaultPrimary = Color(0xFF0056D2);
  static const Color defaultSecondary = Color(0xFF00A2FF);
  static const Color azulProfundo = Color(0xFF295E73); // #295E73
  static const Color amarilloinSoft = Color(0xFFEAA012); // #F2B441
  static const Color rosaViejo = Color(0xFFD48392);
  static const Color rosaPolvo = Color(0xFFE4B9AB);// #F27141
  static const Color rojoTerracota = Color(0xFFBF5349); /// Cian para el azul

  // 3. LISTA DE SELECCIÓN DE COLORES
  static final List<Color> coloresDisponibles = [
    insoftBlue,         // Tu azul corporativo base
    azulProfundo,       // #295E73
    amarilloinSoft,    // #F2B441
    rosaViejo,        // #F2A341
    rosaPolvo,       // #F27141
    rojoTerracota,      // #BF5349
    carbon,             // Tu color carbón
    //Colors.blueGrey,    // Gris azulado
  ];

  // ===========================================================================
  // ✨ MÉTODO "DUOTONO VIBRANTE": COLORES COMPAÑEROS DE ALTO CONTRASTE
  // ===========================================================================
  static Color obtenerColorSecundario(Color colorPrimario) {
    final int value = colorPrimario.toARGB32();

    // 0. 🔵 Azul Standard (Default) -> Compañero: Cian Claro (el que pediste inicialmente)
    if (value == defaultPrimary.toARGB32()) return defaultSecondary;

    // 1. 🔵 Azul InSOFT (#003162) -> Compañero: Ámbar InSOFT (#FD9703) (Contraste clásico)
    if (value == insoftBlue.toARGB32()) return const Color(0xFFFD9703);

    // 2. 🌲 Azul Profundo / Teal oscuro (#295E73) -> Compañero: Coral Cálido / Terracota (#E07A5F)
    if (value == azulProfundo.toARGB32()) return const Color(0xFFE07A5F);

    // 3. 🟡 Amarillo InSOFT (#EAA012) -> Compañero: Azul Marino Profundo (#1E3A8A)
    if (value == amarilloinSoft.toARGB32()) return const Color(0xFF1E3A8A);

    // 4. 🌸 Rosa Viejo (#D48392) -> Compañero: Verde Salvia oscuro (#4A5D23) o Vino (#5C1D2A)
    if (value == rosaViejo.toARGB32()) return const Color(0xFF5C1D2A);

    // 5. 🌸 Rosa Polvo (#E4B9AB) -> Compañero: Carmesí Rico (#9B2226)
    if (value == rosaPolvo.toARGB32()) return const Color(0xFF9B2226);

    // 6. 🔴 Rojo Terracota (#BF5349) -> Compañero: Teal Suave / Océano (#006D77)
    if (value == rojoTerracota.toARGB32()) return const Color(0xFF006D77);

    // 7. ⚫ Carbón (#2C3E50) -> Compañero: Naranja Quemado (#D35400) (Estilo dev elegante)
    if (value == carbon.toARGB32()) return const Color(0xFFD35400);

    // 8. 🔘 Azul Grisáceo (fallback) -> Compañero: Ámbar Dorado (#FFC107)
    if (value == Colors.blueGrey.toARGB32()) return const Color(0xFFFFC107);

    // Fallback de seguridad: generamos un color complementario aproximado invirtiendo los canales
    return Color.fromARGB(
      255,
      255 - colorPrimario.r.toInt(),
      255 - colorPrimario.g.toInt(),
      255 - colorPrimario.b.toInt(),
    );
  }


  // ===========================================================================
  // ✨ SURFACE TINTING: FONDOS OSCUROS DINÁMICOS
  // ===========================================================================
  static Color _tintarSuperficie(Color baseColor, Color tintColor, double opacity) {
    return Color.alphaBlend(tintColor.withValues(alpha: opacity), baseColor);
  }

  static ThemeConfig light({Color primary = defaultPrimary, AppStyle style = AppStyle.standard}) {
    // Restaurando fondo blanco puro para máximo contraste (Estilo InSOFT limpio)
    const Color plainBackground = Color(0xFFF5F7FA); // Gris muy tenue para fondo (AppColors.backgroundLight)
    const Color plainSurface = Colors.white; // Blanco puro para tarjetas

    // Aplicamos la lógica del secundario dinámico
    final Color dynamicSecondary = obtenerColorSecundario(primary);

    return ThemeConfig(
      brightness: Brightness.light,
      primary: primary,
      secondary: dynamicSecondary,
      background: plainBackground,
      surface: plainSurface,
      onBackground: const Color(0xFF1E293B), // Slate 800 para mejor lectura
      style: style,
    );
  }

  static ThemeConfig dark({Color primary = const Color(0xFF64B5F6), AppStyle style = AppStyle.standard}) {
    // 1. Base neutra súper oscura (Material 3 standard)
    const Color grisAsfaltoBase = Color(0xFF111418); // Muy cercano al negro puro, ligeramente más amigable
    
    // 2. Aplicamos Surface Tinting (mezclamos un poco del color primario en el fondo gris)
    // Fondo general recibe apenas 4% del color primario
    final Color tintedBackground = _tintarSuperficie(grisAsfaltoBase, primary, 0.04);
    
    // Tarjetas/Superficies reciben 8% del primario para destacarse apenas un poco
    final Color tintedSurface = _tintarSuperficie(grisAsfaltoBase, primary, 0.08);

    // Aplicamos la lógica del secundario dinámico
    final Color dynamicSecondary = obtenerColorSecundario(primary);

    return ThemeConfig(
      brightness: Brightness.dark,
      primary: primary,
      secondary: dynamicSecondary,
      background: tintedBackground,
      surface: tintedSurface,
      onBackground: ColoresApp.textoOscuro, // Blanco tiza para perfecta legibilidad
      style: style,
    );
  }
}

// =============================================================================
// 4. TEMA APP (CONSTRUCTOR DINÁMICO)
// =============================================================================
class TemaApp {

  static ThemeData obtenerTema(ThemeConfig config) {
    final isDark = config.isDark;
    final extensionColores = isDark ? InsoftColors.dark : InsoftColors.light;

    final primaryContainer = isDark ? config.primary.withValues(alpha: 0.2) : config.primary.withValues(alpha: 0.1);
    final onPrimaryContainer = isDark ? config.onBackground : config.primary;

    final baseTheme = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    BorderRadius borderRadiusGeneral;
    OutlinedBorder shapeBoton;

    switch (config.style) {
      case AppStyle.modern:
        borderRadiusGeneral = BorderRadius.circular(30.0);
        shapeBoton = const StadiumBorder();
        break;
      case AppStyle.elegant:
        borderRadiusGeneral = BorderRadius.zero;
        shapeBoton = const RoundedRectangleBorder(borderRadius: BorderRadius.zero);
        break;
      case AppStyle.tech:
        borderRadiusGeneral = BorderRadius.circular(8.0);
        shapeBoton = BeveledRectangleBorder(borderRadius: BorderRadius.circular(8.0));
        break;
      case AppStyle.standard:
        borderRadiusGeneral = BorderRadius.circular(16.0); // Subimos un poco el estándar
        shapeBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0));
        break;
    }

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Inter'), // ✨ Fuente global
      primaryColor: config.primary,
      scaffoldBackgroundColor: config.background,
      canvasColor: config.background,
      extensions: [extensionColores],

      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primary,
        brightness: config.brightness,
        primary: config.primary,
        secondary: config.secondary,
        surface: config.surface,
        onSurface: config.onBackground,
        error: ColoresApp.error,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
      ),

      cardTheme: CardThemeData(
        color: config.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusGeneral,
          side: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: config.surface,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusGeneral),
        titleTextStyle: TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20,
            color: isDark ? Colors.white : config.primary
        ),
      ),

      // ✨ Globals Text Selection (Cursor & Highlight)
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: config.secondary,
        selectionColor: config.secondary.withValues(alpha: 0.3),
        selectionHandleColor: config.secondary,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: borderRadiusGeneral, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusGeneral,
          borderSide: BorderSide(color: isDark ? Colors.white12 : config.primary.withValues(alpha: 0.08)),
        ),
        // ✨ Aquí usamos el color Secundario Vibrante
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusGeneral,
          borderSide: BorderSide(color: config.secondary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shapeBoton,
        ),
      ),

      // ✨ Agregamos el FAB con el color Secundario
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: config.secondary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ✨ Agregamos el NavigationBar con el indicador Secundario
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: config.secondary.withValues(alpha: 0.25),
        backgroundColor: config.surface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: config.secondary); 
          }
          return IconThemeData(color: isDark ? Colors.white54 : Colors.black54);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
             return TextStyle(fontWeight: FontWeight.bold, color: config.secondary, fontSize: 12);
          }
          return TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54, fontSize: 12);
        }),
      ),

      // ✨ [Refinamiento Premium] Snackbars flotantes tipo píldora
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Píldora
        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B), // Slate oscuro sofisticado
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        elevation: 8,
      ),

      // ✨ [Refinamiento Premium] BottomSheets iOS-style (Curvas grandes)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: config.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
      ),

      // ✨ [Refinamiento Premium] Divisores súper sutiles para evitar ruido visual
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        thickness: 1,
        space: 1,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: config.style == AppStyle.modern ? Colors.transparent : config.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: config.style != AppStyle.elegant,
        iconTheme: IconThemeData(color: isDark ? Colors.white : config.primary),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18,
          color: isDark ? Colors.white : config.primary,
        ),
      ),
    );
  }
}

// =============================================================================
// 5. PROVIDER CON PERSISTENCIA
// =============================================================================
class ProveedorTema extends ChangeNotifier {
  ThemeMode _modoTema = ThemeMode.system;
  Color _colorSeleccionado = AppPalettes.defaultPrimary;
  AppStyle _estiloSeleccionado = AppStyle.standard;

  ThemeMode get modoTema => _modoTema;
  Color get colorSeleccionado => _colorSeleccionado;
  AppStyle get estiloSeleccionado => _estiloSeleccionado;

  Color get colorTema => _colorSeleccionado;

  void cambiarColor(AppThemeColor modo) {
    if (modo == AppThemeColor.azul) {
      cambiarColorPrimario(const Color(0xFF003366));
    } else if (modo == AppThemeColor.bosque) {
      cambiarColorPrimario(const Color(0xFF1B5E20));
    } else if (modo == AppThemeColor.morado) {
      cambiarColorPrimario(const Color(0xFF4A148C));
    }
  }

  ProveedorTema() {
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    bool? esOscuro = prefs.getBool('esOscuro');
    if (esOscuro != null) _modoTema = esOscuro ? ThemeMode.dark : ThemeMode.light;

    int? colorValue = prefs.getInt('colorTema');
    if (colorValue != null) _colorSeleccionado = Color(colorValue);

    String? estiloNombre = prefs.getString('estiloTema');
    if (estiloNombre != null) {
      _estiloSeleccionado = AppStyle.values.firstWhere(
              (e) => e.name == estiloNombre,
          orElse: () => AppStyle.standard
      );
    }
    notifyListeners();
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('esOscuro', _modoTema == ThemeMode.dark);
    await prefs.setInt('colorTema', _colorSeleccionado.toARGB32());
    await prefs.setString('estiloTema', _estiloSeleccionado.name);
  }

  void cambiarTema(bool esOscuro) {
    _modoTema = esOscuro ? ThemeMode.dark : ThemeMode.light;
    _guardarPreferencias();
    notifyListeners();
  }

  void cambiarColorPrimario(Color nuevoColor) {
    _colorSeleccionado = nuevoColor;
    _guardarPreferencias();
    notifyListeners();
  }

  void cambiarEstilo(AppStyle nuevoEstilo) {
    _estiloSeleccionado = nuevoEstilo;
    _guardarPreferencias();
    notifyListeners();
  }

  ThemeConfig get configActual {
    bool esOscuro = _modoTema == ThemeMode.dark;
    return esOscuro
        ? AppPalettes.dark(primary: _colorSeleccionado, style: _estiloSeleccionado)
        : AppPalettes.light(primary: _colorSeleccionado, style: _estiloSeleccionado);
  }
}
