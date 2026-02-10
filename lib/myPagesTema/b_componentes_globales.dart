import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'a_tema_app.dart';

// =============================================================================
// 1. GRADIENT BUTTON (Antes f_boton_gradiente.dart)
// =============================================================================

class BotonGradiente extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;
  
  // NUEVO: Para poder cambiar el color (Ej: Botón Naranja)
  final Gradient? gradient;
  final Color? shadowColor;

  const BotonGradiente({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 54, // Un poco más alto es más moderno (Apple/Google standard)
    this.gradient,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos el gradiente por defecto (Azul InSOFT) si no pasamos uno
    final activeGradient = gradient ?? ColoresApp.gradientePrimario;
    // Usamos la sombra azul por defecto si no pasamos una
    final activeShadowColor = shadowColor ?? ColoresApp.primario;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: activeGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // Usamos la sombra dinámica basada en el color del botón
            color: activeShadowColor.withValues(alpha: 0.4), 
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          // Efecto visual al presionar (Splash blanco suave)
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.transparent,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5, // Un poco más grueso se ve mejor
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                      ],
                      // MEJORA: Usamos la tipografía del Tema (Inter Bold)
                      Text(
                        text,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          // Si quisieras ajustar algo específico sobre el tema base:
                          fontSize: 16, 
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. CUSTOM TEXT FIELD (Antes e_campo_texto.dart)
// =============================================================================

class CampoTextoPersonalizado extends StatefulWidget {
  final String label;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final int maxLines;
  final String? hint;
  final List<TextInputFormatter>? inputFormatters;

  const CampoTextoPersonalizado({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.maxLines = 1,
    this.hint,
    this.inputFormatters,
  });

  @override
  State<CampoTextoPersonalizado> createState() => _CampoTextoPersonalizadoState();
}

class _CampoTextoPersonalizadoState extends State<CampoTextoPersonalizado> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // OPTIMIZACIÓN: Solo mostrar sombra en modo claro
        boxShadow: isDark ? [] : ColoresApp.sombraSuave,
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        maxLines: widget.maxLines,
        style: theme.textTheme.bodyLarge, // Usa la tipografía del tema actual
        inputFormatters: widget.inputFormatters,
        
        // El inputDecorationTheme ya lo definiste en a_tema_app.dart,
        // así que aquí solo sobrescribimos lo específico.
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.prefixIcon, 
            // Color dinámico según si está activo o no (opcional)
            color: isDark ? Colors.white70 : ColoresApp.primario.withValues(alpha: 0.7)
          ),
          alignLabelWithHint: widget.maxLines > 1,
          
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: theme.hintColor, // Usa el color de hint del tema
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : (widget.suffixIcon != null 
                  ? Icon(widget.suffixIcon, color: theme.hintColor) 
                  : null),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. PREMIUM CARD (Antes g_tarjeta_premium.dart)
// =============================================================================

class TarjetaPremium extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool esBordeBrillante; // NUEVO: Para destacar algo importante

  const TarjetaPremium({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.esBordeBrillante = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Lógica de colores automática
    final cardBg = backgroundColor ?? theme.cardTheme.color;
    
    // Si es "Brillante", usamos el color primario, si no, el borde sutil
    final borderColor = esBordeBrillante
        ? ColoresApp.primario.withValues(alpha: 0.5)
        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        boxShadow: [
          // En modo oscuro, eliminamos la sombra difusa y dejamos solo el borde
          if (!isDark) ...ColoresApp.sombraSuave,
        ],
        border: Border.all(
          color: borderColor,
          width: esBordeBrillante ? 1.5 : 1, // Borde un poco más grueso si destaca
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        clipBehavior: Clip.antiAlias, // Recorta el efecto ripple
        child: InkWell(
          onTap: onTap,
          // Color de splash adaptativo
          splashColor: isDark 
              ? Colors.white.withValues(alpha: 0.05) 
              : ColoresApp.primario.withValues(alpha: 0.1),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(DimensionesApp.paddingEstandar),
            child: child,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. PAGINATION CONTROLS (Antes i_controles_paginacion.dart)
// =============================================================================

class ControlesPaginacion extends StatelessWidget {
  final int paginaActual;
  final int totalPaginas;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;

  const ControlesPaginacion({
    super.key,
    required this.paginaActual,
    required this.totalPaginas,
    this.onAnterior,
    this.onSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón anterior (Compacto)
            IconButton.filled(
              onPressed: paginaActual > 1 ? onAnterior : null,
              icon: const Icon(Icons.chevron_left),
              style: IconButton.styleFrom(
                backgroundColor: ColoresApp.primario,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              tooltip: 'Anterior',
            ),

            // Indicador de página (Flexible para evitar overflow)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: ColoresApp.primarioContenedor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$paginaActual / $totalPaginas', // Texto más corto
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ColoresApp.primario,
                  ),
                ),
              ),
            ),

            // Botón siguiente (Compacto)
            IconButton.filled(
              onPressed: paginaActual < totalPaginas ? onSiguiente : null,
              icon: const Icon(Icons.chevron_right),
              style: IconButton.styleFrom(
                backgroundColor: ColoresApp.primario,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              tooltip: 'Siguiente',
            ),
          ],
        ),
      ),
    );
  }
}
