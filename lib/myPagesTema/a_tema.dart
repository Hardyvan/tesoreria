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
  static const Color darkBg = Color(0xFF121E2A);
  static const Color lightBg = Color(0xFFF5F7FA);

  static final List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: -5,
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
  static const Color error = Color(0xFFC62828);
  static const Color exito = Color(0xFF2E7D32);
  static const Color textoSecundarioClaro = Color(0xFF90A4AE);
  static const Color secundario = AppPalettes.defaultSecondary;
  static const Color estadoPendiente = Color(0xFFFF9900);
  
  static const Color superficieClara = Color(0xFFFFFFFF);
  static const Color superficieOscura = Color(0xFF1C2A38);
  static const Color textoOscuro = Color(0xFFECEFF1);
  
  static final List<BoxShadow> sombraSuave = AppTokens.sombraSuave;
  static const LinearGradient gradientePrimario = LinearGradient(
    colors: [AppPalettes.defaultPrimary, Color(0xFF1A237E)],
  );
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
  static final MaterialColor insoftBlue = _createMaterialColor(const Color(0xFF0056D2));
  static final MaterialColor foodOrange = _createMaterialColor(const Color(0xFFFF6B00));
  static final MaterialColor carbon = _createMaterialColor(const Color(0xFF2C3E50));

  static const Color defaultPrimary = Color(0xFF003366);
  static const Color defaultSecondary = Color(0xFFFF9900);

  // 3. LISTA DE SELECCIÓN DE COLORES
  static final List<Color> coloresDisponibles = [
    insoftBlue,
    foodOrange,
    Colors.indigo,
    Colors.teal,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.pink,
    carbon, // Negro azulado personalizado
    Colors.blueGrey,
  ];

  static ThemeConfig light({Color primary = defaultPrimary, AppStyle style = AppStyle.standard}) {
    // Tint backgrounds slightly with the primary color to make theme changes more impactful
    final Color tintedBackground = Color.lerp(AppTokens.lightBg, primary, 0.05) ?? AppTokens.lightBg;
    final Color tintedSurface = Color.lerp(ColoresApp.superficieClara, primary, 0.08) ?? ColoresApp.superficieClara;

    return ThemeConfig(
      brightness: Brightness.light,
      primary: primary,
      secondary: defaultSecondary,
      background: tintedBackground,
      surface: tintedSurface,
      onBackground: const Color(0xFF1F2937),
      style: style,
    );
  }

  static ThemeConfig dark({Color primary = const Color(0xFF64B5F6), AppStyle style = AppStyle.standard}) {
    // Tint backgrounds slightly with the primary color to make theme changes more impactful
    final Color tintedBackground = Color.lerp(AppTokens.darkBg, primary, 0.08) ?? AppTokens.darkBg;
    final Color tintedSurface = Color.lerp(ColoresApp.superficieOscura, primary, 0.12) ?? ColoresApp.superficieOscura;

    return ThemeConfig(
      brightness: Brightness.dark,
      primary: primary,
      secondary: defaultSecondary,
      background: tintedBackground,
      surface: tintedSurface,
      onBackground: ColoresApp.textoOscuro,
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
        borderRadiusGeneral = BorderRadius.circular(12.0);
        shapeBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));
        break;
    }

    return baseTheme.copyWith(
      primaryColor: config.primary, // FIJA EL PRIMARY COLOR AQUÍ
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

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF273444) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: borderRadiusGeneral, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusGeneral,
          borderSide: BorderSide(color: isDark ? Colors.white12 : config.primary.withValues(alpha: 0.08)),
        ),
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