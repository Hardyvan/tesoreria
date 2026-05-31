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

  // 2. COLORES PERSONALIZADOS PREMIUM (10 Duotonos Vibrantes de Alto Impacto)
  static final MaterialColor insoftBlue = _createMaterialColor(const Color(0xFF003162));      // 1. 🌌 Azul Eclipse Corporativo
  static final MaterialColor verdeBosque = _createMaterialColor(const Color(0xFF1B4D3E));     // 2. 🌲 Verde Bosque Místico
  static final MaterialColor moradoCosmico = _createMaterialColor(const Color(0xFF3F2B96));   // 3. 🔮 Morado Amatista Cósmico
  static final MaterialColor naranjaCobre = _createMaterialColor(const Color(0xFFD35400));    // 4. 🍊 Naranja Cobre Terracota
  static final MaterialColor rojoRubi = _createMaterialColor(const Color(0xFF8D0801));        // 5. 🍷 Rojo Rubí Imperial
  static final MaterialColor carbonTech = _createMaterialColor(const Color(0xFF212529));      // 6. 🖤 Negro Carbón Industrial
  static final MaterialColor bronceLatte = _createMaterialColor(const Color(0xFF7E6B5A));     // 7. 🍂 Bronce Latte Escandinavo
  static final MaterialColor cerezoSakura = _createMaterialColor(const Color(0xFFD81B60));    // 8. 🌸 Cerezo Sakura Japonés
  static final MaterialColor azulOceano = _createMaterialColor(const Color(0xFF006064));      // 9. 🌊 Azul Océano Profundo
  static final MaterialColor trigoDorado = _createMaterialColor(const Color(0xFFE65100));     // 10. 🌾 Trigo Dorado Atardecer

  static const Color defaultPrimary = Color(0xFF003162); // Por defecto: Azul Insoft Corporativo para evitar transiciones feas al cargar
  static const Color defaultSecondary = Color(0xFFFD9703); // Por defecto: Ámbar Insoft

  // 3. LISTA OFICIAL DE LOS 10 COLORES CORPORATIVOS DISPONIBLES
  static final List<Color> coloresDisponibles = [
    insoftBlue,         // 1. Azul Eclipse Corporativo
    verdeBosque,        // 2. Verde Bosque Místico
    moradoCosmico,      // 3. Morado Amatista Cósmico
    naranjaCobre,       // 4. Naranja Cobre Terracota
    rojoRubi,           // 5. Rojo Rubí Imperial
    carbonTech,         // 6. Negro Carbón Industrial
    bronceLatte,        // 7. Bronce Latte Escandinavo
    cerezoSakura,       // 8. Cerezo Sakura Japonés
    azulOceano,         // 9. Azul Océano Profundo
    trigoDorado,        // 10. Trigo Dorado Atardecer
  ];

  // ===========================================================================
  // ✨ MÉTODO "DUOTONO VIBRANTE": COLORES COMPAÑEROS DE ALTO CONTRASTE PREMIUM
  // ===========================================================================
  static Color obtenerColorSecundario(Color colorPrimario) {
    final int value = colorPrimario.toARGB32();

    // 1. 🌌 Azul Eclipse Corporativo (#003162) -> Compañero: Ámbar Insoft Vibrante (#FD9703) (El dúo perfecto de la marca)
    if (value == insoftBlue.toARGB32()) return const Color(0xFFFD9703);

    // 2. 🌲 Verde Bosque Místico (#1B4D3E) -> Compañero: Menta Neón Eléctrica (#00E676) (Contraste verde ultra-moderno)
    if (value == verdeBosque.toARGB32()) return const Color(0xFF00E676);

    // 3. 🔮 Morado Amatista Cósmico (#3F2B96) -> Compañero: Rosa Orquídea Neón (#EC53B5) (Aspecto Cyberpunk futurista)
    if (value == moradoCosmico.toARGB32()) return const Color(0xFFEC53B5);

    // 4. 🍊 Naranja Cobre Terracota (#D35400) -> Compañero: Azul Hielo Glaciar (#85C1E9) (Equilibrio térmico bellísimo)
    if (value == naranjaCobre.toARGB32()) return const Color(0xFF85C1E9);

    // 5. 🍷 Rojo Rubí Imperial (#8D0801) -> Compañero: Océano Turquesa Eléctrico (#00B4D8) (Aspecto pasional de alto contraste)
    if (value == rojoRubi.toARGB32()) return const Color(0xFF00B4D8);

    // 6. 🖤 Negro Carbón Industrial (#212529) -> Compañero: Naranja Mandarina Eléctrico (#FFFF8C00) (Estilo minimalista oscuro premium)
    if (value == carbonTech.toARGB32()) return const Color(0xFFFF8C00);

    // 7. 🍂 Bronce Latte Escandinavo (#7E6B5A) -> Compañero: Oro Champagne Calma (#E8C547) (Elegancia minimalista y relajante)
    if (value == bronceLatte.toARGB32()) return const Color(0xFFE8C547);

    // 8. 🌸 Cerezo Sakura Japonés (#D81B60) -> Compañero: Menta Turquesa (#26A69A)
    if (value == cerezoSakura.toARGB32()) return const Color(0xFF26A69A);

    // 9. 🌊 Azul Océano Profundo (#006064) -> Compañero: Coral Naranja (#FF7043)
    if (value == azulOceano.toARGB32()) return const Color(0xFFFF7043);

    // 10. 🌾 Trigo Dorado Atardecer (#E65100) -> Compañero: Midnight Indigo (#1A237E)
    if (value == trigoDorado.toARGB32()) return const Color(0xFF1A237E);

    // Fallback por defecto si no coincide ninguno (Azul Insoft -> Ámbar)
    return const Color(0xFFFD9703);
  }

  // ===========================================================================
  // ✨ TERCER COLOR DE ENFOQUE (ACENTO VIVO ADICIONAL)
  // ===========================================================================
  static Color obtenerColorTerciario(Color colorPrimario) {
    final int value = colorPrimario.toARGB32();

    if (value == insoftBlue.toARGB32()) return const Color(0xFFFF4081);       // Fucsia brillante
    if (value == verdeBosque.toARGB32()) return const Color(0xFFE9C46A);      // Oro Cálido
    if (value == moradoCosmico.toARGB32()) return const Color(0xFF00E5FF);    // Celeste Neón
    if (value == naranjaCobre.toARGB32()) return const Color(0xFF27AE60);     // Esmeralda
    if (value == rojoRubi.toARGB32()) return const Color(0xFFE9C46A);         // Oro Imperial
    if (value == carbonTech.toARGB32()) return const Color(0xFF00B4D8);       // Cian Eléctrico
    if (value == bronceLatte.toARGB32()) return const Color(0xFFD81B60);      // Rosado Cereza
    if (value == cerezoSakura.toARGB32()) return const Color(0xFFFFB300);     // Miel Dulce
    if (value == azulOceano.toARGB32()) return const Color(0xFF9CCC65);       // Verde Lima
    if (value == trigoDorado.toARGB32()) return const Color(0xFF43A047);      // Verde Hoja

    return const Color(0xFFFF4081); // Fallback
  }

  // ===========================================================================
  // ✨ FONDOS CÁLIDOS PERSONALIZADOS (Evitan pantallas frías / blancas genéricas)
  // ===========================================================================
  static Color obtenerFondoCalido(Color colorPrimario) {
    final int value = colorPrimario.toARGB32();

    if (value == insoftBlue.toARGB32()) return const Color(0xFFFAF9F5);       // Blanco Alabastro eclipse
    if (value == verdeBosque.toARGB32()) return const Color(0xFFF4F6F4);      // Salvia místico suave
    if (value == moradoCosmico.toARGB32()) return const Color(0xFFF9F5FB);    // Bruma orquídea cálida
    if (value == naranjaCobre.toARGB32()) return const Color(0xFFFAF5F0);     // Arena cobriza cálida
    if (value == rojoRubi.toARGB32()) return const Color(0xFFFAF4F4);         // Rosa rubí cálida
    if (value == carbonTech.toARGB32()) return const Color(0xFFF6F6F6);       // Platino cálido industrial
    if (value == bronceLatte.toARGB32()) return const Color(0xFFF7F5F2);      // Cashmere Latte cálido
    if (value == cerezoSakura.toARGB32()) return const Color(0xFFFCF5F7);     // Crema de cerezo
    if (value == azulOceano.toARGB32()) return const Color(0xFFF2F7F7);       // Sal marina / menta clara
    if (value == trigoDorado.toARGB32()) return const Color(0xFFFDF8F2);      // Trigo dorado cálido

    return const Color(0xFFFAF9F5); // Fallback
  }

  // ===========================================================================
  // ✨ SURFACE TINTING: FONDOS OSCUROS DINÁMICOS
  // ===========================================================================
  static Color _tintarSuperficie(Color baseColor, Color tintColor, double opacity) {
    return Color.alphaBlend(tintColor.withValues(alpha: opacity), baseColor);
  }

  static ThemeConfig light({Color primary = defaultPrimary, AppStyle style = AppStyle.standard}) {
    // Generación dinámica del fondo cálido personalizado según el color seleccionado
    final Color warmBackground = obtenerFondoCalido(primary);
    const Color plainSurface = Colors.white; // Tarjetas blancas nítidas para alto contraste sobre fondo cálido

    final Color dynamicSecondary = obtenerColorSecundario(primary);

    return ThemeConfig(
      brightness: Brightness.light,
      primary: primary,
      secondary: dynamicSecondary,
      background: warmBackground,
      surface: plainSurface,
      onBackground: const Color(0xFF1E293B), // Slate 800 para legibilidad premium
      style: style,
    );
  }

  static ThemeConfig dark({Color primary = const Color(0xFF64B5F6), AppStyle style = AppStyle.standard}) {
    // Fondos oscuros cálidos slate con Surface Tinting del color primario
    const Color darkBackgroundBase = Color(0xFF161E2D); // Base azulada/oscura muy profunda
    const Color darkSurfaceBase = Color(0xFF222F43);    // Tarjetas ligeramente más claras
    
    final Color tintedBackground = _tintarSuperficie(darkBackgroundBase, primary, 0.04);
    final Color tintedSurface = _tintarSuperficie(darkSurfaceBase, primary, 0.06);

    final Color dynamicSecondary = obtenerColorSecundario(primary);

    return ThemeConfig(
      brightness: Brightness.dark,
      primary: primary,
      secondary: dynamicSecondary,
      background: tintedBackground,
      surface: tintedSurface,
      onBackground: ColoresApp.textoOscuro, // Blanco tiza legible
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
    final Color colorAdaptado = isDark ? ColorScheme.fromSeed(seedColor: config.primary, brightness: Brightness.dark).primary : config.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: config.brightness,
      primaryColor: colorAdaptado,
      scaffoldBackgroundColor: config.background,
      canvasColor: config.background,
      fontFamily: 'Inter',
      extensions: [extensionColores],

      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primary,
        brightness: config.brightness,
      ).copyWith(
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
      
      textTheme: TextTheme(
        displayLarge: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        displayMedium: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        displaySmall: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        headlineLarge: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        headlineMedium: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        headlineSmall: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        titleLarge: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        titleMedium: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        titleSmall: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        bodyLarge: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)), // Textos legibles en oscuros
        bodyMedium: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
        bodySmall: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF1E293B)),
        labelLarge: TextStyle(color: isDark ? Colors.white : colorAdaptado),
        labelMedium: TextStyle(color: isDark ? Colors.white70 : colorAdaptado),
        labelSmall: TextStyle(color: isDark ? Colors.white60 : colorAdaptado),
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

      // ✨ [Nuevo] Drawer dinámico basado en MyPagesTema
      drawerTheme: DrawerThemeData(
        backgroundColor: config.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),

      // ✨ [Nuevo] ListTiles dinámicos
      listTileTheme: ListTileThemeData(
        iconColor: colorAdaptado,
        textColor: config.onBackground,
        titleTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        subtitleTextStyle: TextStyle(color: config.onBackground.withValues(alpha: 0.6), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
