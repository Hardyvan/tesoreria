import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/h_servicio_conectividad.dart';
import 'a_tema.dart';

// =============================================================================
// 1. BOTÓN PRINCIPAL SOLID (Reemplaza BotonGradiente)
// =============================================================================
class BotonGradiente extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;
  final bool useSecondaryColor; // ✨ Nueva opción para usar el color de acento

  const BotonGradiente({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 54,
    this.useSecondaryColor = false,
  });

  @override
  State<BotonGradiente> createState() => _BotonGradienteState();
}

class _BotonGradienteState extends State<BotonGradiente> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    
    // Usamos colores SÓLIDOS puros como pidió el usuario, cero degradados
    final solidColor = widget.useSecondaryColor ? theme.colorScheme.secondary : theme.primaryColor;

    final buttonContent = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isEnabled ? solidColor : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
        // Sombra suave del mismo color sólido
        boxShadow: isEnabled
            ? [
          BoxShadow(
            color: solidColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? () {
            HapticFeedback.lightImpact(); // Vibración física premium
            widget.onPressed!();
          } : null,
          borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700, // Más Bold para compensar la falta de gradiente
                      fontSize: 16,
                      fontFamily: 'Inter'
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isEnabled) return buttonContent;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: buttonContent,
      ),
    );
  }
}

// =============================================================================
// 2. CAMPO DE TEXTO
// =============================================================================
class CampoTextoPersonalizado extends StatefulWidget {
  final String label;
  final IconData? prefixIcon;
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
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final int? maxLength;
  final TextAlign textAlign;
  final double? letterSpacing;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final TextCapitalization textCapitalization;

  const CampoTextoPersonalizado({
    super.key,
    required this.label,
    this.prefixIcon,
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
    this.focusNode,
    this.onFieldSubmitted,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.letterSpacing,
    this.onChanged,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
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

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      showCursor: true,
      cursorColor: theme.primaryColor,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      textAlign: widget.textAlign,
      onChanged: widget.onChanged,
      buildCounter: (widget.maxLength != null)
          ? (_, {required currentLength, maxLength, required isFocused}) => null
          : null,
      style: theme.textTheme.bodyLarge?.copyWith(
        letterSpacing: widget.letterSpacing,
        fontWeight: widget.letterSpacing != null ? FontWeight.bold : null,
        fontSize: widget.letterSpacing != null ? 18 : null,
        color: widget.letterSpacing != null ? theme.primaryColor : null,
      ),
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label.isEmpty ? null : widget.label,
        hintText: widget.hint,
        counterText: '',
        prefixText: widget.prefixText,

        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),

        prefixIcon: widget.prefixIcon != null
            ? Icon(
          widget.prefixIcon,
          color: isDark
              ? Colors.white70
              : theme.primaryColor.withValues(alpha: 0.6),
        )
            : null,
        alignLabelWithHint: widget.maxLines > 1,
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: theme.hintColor,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        )
            : (widget.suffixIcon != null
            ? Icon(widget.suffixIcon, color: theme.hintColor)
            : null),
      ),
    );
  }
}

// =============================================================================
// 3. TARJETA PREMIUM
// =============================================================================
class TarjetaPremium extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool esBordeBrillante;
  final bool usaGradientePrimario; // 🔥 NUEVO: Control para activar el degradado

  const TarjetaPremium({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.esBordeBrillante = false,
    this.usaGradientePrimario = false, // 🔥 NUEVO: Por defecto es falso para no romper tu UI actual
  });

  @override
  State<TarjetaPremium> createState() => _TarjetaPremiumState();
}

class _TarjetaPremiumState extends State<TarjetaPremium> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final borderColor = widget.esBordeBrillante
        ? theme.primaryColor.withValues(alpha: 0.5)
        : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05));

    final cardContent = Container(
      decoration: BoxDecoration(
        // 🔥 Simplificación: Eliminamos degradados para usar colores sólidos puros (Máxima legibilidad)
        gradient: null,
        color: widget.usaGradientePrimario ? colorScheme.primary : (widget.backgroundColor ?? theme.cardTheme.color),
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        border: Border.all(
          color: widget.usaGradientePrimario ? Colors.transparent : borderColor,
          width: widget.esBordeBrillante ? 1.5 : 1,
        ),
        boxShadow: isDark ? [] : ColoresApp.sombraSuave,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap != null ? () {
            HapticFeedback.lightImpact(); // Vibración física premium
            widget.onTap!();
          } : null,
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Theme(
            data: theme.copyWith(
              iconTheme: IconThemeData(
                color: widget.usaGradientePrimario ? Colors.white : null,
              ),
              dividerTheme: theme.dividerTheme.copyWith(
                color: widget.usaGradientePrimario ? Colors.white.withValues(alpha: 0.2) : null,
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: widget.usaGradientePrimario ? Colors.white : null,
                ),
              ),
              listTileTheme: ListTileThemeData(
                iconColor: widget.usaGradientePrimario ? Colors.white : null,
                textColor: widget.usaGradientePrimario ? Colors.white : null,
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  color: widget.usaGradientePrimario ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                ),
                subtitleTextStyle: theme.textTheme.bodySmall!.copyWith(
                  color: widget.usaGradientePrimario ? Colors.white70 : null,
                ),
              ),
            ),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: widget.usaGradientePrimario ? Colors.white : null,
              ),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(AppTokens.paddingEstandar),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) {
      return cardContent;
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: cardContent,
      ),
    );
  }
}

// =============================================================================
// 4. CONTENEDOR GLASS
// =============================================================================
class ContenedorGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ContenedorGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1), // Más translúcido para dejar pasar el blur
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
          ),
          child: child,
        ),
      ),
    );
  }
}

// =============================================================================
// 4.5. BADGE ESTADO (NUEVO)
// =============================================================================
class BadgeEstado extends StatelessWidget {
  final String texto;
  final Color colorBase;

  const BadgeEstado({
    super.key,
    required this.texto,
    required this.colorBase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorBase.withValues(alpha: 0.15), // Fondo translúcido muy sutil
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorBase.withValues(alpha: 0.5), // Borde suave
          width: 1,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: colorBase, // Texto con alto contraste relativo a su fondo translúcido
          fontWeight: FontWeight.bold,
          fontSize: 12,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// Fin BadgeEstado

// =============================================================================
// 5. MANEJADOR DE ERRORES GLOBAL
// =============================================================================
class ManejadorErrores {
  static void mostrarErrorMensaje(BuildContext context, String mensaje, {String? detalle}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  if (detalle != null) Text(detalle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: ColoresApp.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void mostrarErrorCritico(BuildContext context, String titulo, String mensaje) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning, color: ColoresApp.error, size: 48),
        title: Text(titulo, textAlign: TextAlign.center),
        content: Text(mensaje, textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))
        ],
      ),
    );
  }

  static void mostrarMensajeExito(BuildContext context, String mensaje) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(mensaje, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ]
          ),
          backgroundColor: ColoresApp.exito,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        )
    );
  }
}

// =============================================================================
// 6. AVATAR USUARIO
// =============================================================================
class AvatarUsuario extends StatelessWidget {
  final String? nombre;
  final String? fotoUrl;
  final double radius;
  final Color backgroundColor;
  final Color? textColor;
  final bool? activo;

  const AvatarUsuario({
    super.key,
    this.nombre,
    this.fotoUrl,
    this.textColor,
    this.activo,
    this.radius = 20,
    this.backgroundColor = ColoresApp.superficieOscura,
  });

  @override
  Widget build(BuildContext context) {
    String iniciales = nombre != null && nombre!.isNotEmpty ? nombre!.substring(0, 1).toUpperCase() : '?';
    final hasImage = fotoUrl != null && fotoUrl!.isNotEmpty;
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: hasImage ? NetworkImage(fotoUrl!) : null,
      child: hasImage ? null : Text(
        iniciales,
        style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
      ),
    );
  }
}

// =============================================================================
// 7. BANNER SIN CONEXIÓN GLOBAL (Design System)
// =============================================================================
class BannerSinConexion extends StatelessWidget {
  const BannerSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final conectividad = Provider.of<ServicioConectividad>(context);
      if (conectividad.tieneConexion) return const SizedBox.shrink();
    } catch (_) {}
    
    return Container(
      color: ColoresApp.error,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Text(
        'Sin conexión a internet',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// =============================================================================
// 8. CONTENEDOR RESPONSIVO (Tablet/Web)
// =============================================================================
class ContenedorMaximoLectura extends StatelessWidget {
  final Widget child;
  final double anchoMaximo;

  const ContenedorMaximoLectura({
    super.key,
    required this.child,
    this.anchoMaximo = 700, // Ancho cómodo para lectura y tarjetas
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: child,
      ),
    );
  }
}
