import 'a_tema.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/h_servicio_conectividad.dart';

import 'package:flutter/services.dart';


// =============================================================================
// 1. GRADIENTE BUTTON
// =============================================================================
class BotonGradiente extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;
  final Gradient? gradient;

  const BotonGradiente({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 54,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeGradient = gradient ?? LinearGradient(
      colors: [
        Color.lerp(Colors.white, colorScheme.primary, 0.8)!, // Brillo sutil
        colorScheme.primary,
        colorScheme.secondary, // Sombra
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.4, 1.0],
    );

    final isEnabled = onPressed != null && !isLoading;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled ? activeGradient : null,
        color: isEnabled ? null : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
        boxShadow: isEnabled
            ? [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Center(
            child: isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
  final Widget? prefixIconWidget;

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
    this.prefixIconWidget,
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
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
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
        fontSize: widget.letterSpacing != null ? 24 : null,
        color: widget.letterSpacing != null ? theme.primaryColor : null,
      ),
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label.isEmpty ? null : widget.label,
        hintText: widget.hint,
        counterText: '',
        prefixText: widget.prefixText,
        prefixStyle: widget.prefixText != null 
          ? TextStyle(color: isDark ? Colors.white70 : theme.primaryColor.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 16)
          : null,
        prefixIcon: widget.prefixIconWidget ?? (widget.prefixIcon != null ? Icon(
            widget.prefixIcon,
            color: isDark ? Colors.white70 : theme.primaryColor.withValues(alpha: 0.6)
        ) : null),
        alignLabelWithHint: widget.maxLines > 1,
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: theme.hintColor,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        )
            : (widget.suffixIcon != null ? Icon(widget.suffixIcon, color: theme.hintColor) : null),
      ),
    );
  }
}

// =============================================================================
// 3. TARJETA PREMIUM
// =============================================================================
class TarjetaPremium extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool esBordeBrillante;
  final bool usaGradientePrimario; // ðŸ”¥ NUEVO: Control para activar el degradado

  const TarjetaPremium({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.esBordeBrillante = false,
    this.usaGradientePrimario = false, // ðŸ”¥ NUEVO: Por defecto es falso para no romper tu UI actual
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // Si usa gradiente, el color de fondo sÃ³lido se vuelve transparente
    final cardBg = usaGradientePrimario ? Colors.transparent : (backgroundColor ?? theme.cardTheme.color);

    final borderColor = esBordeBrillante
        ? theme.primaryColor.withValues(alpha: 0.5)
        : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05));

    return Container(
      decoration: BoxDecoration(
        color: usaGradientePrimario ? null : cardBg,
        // ðŸ”¥ AQUÃ SUCEDE LA MAGIA DINÃMICA
        gradient: usaGradientePrimario
            ? LinearGradient(
                colors: [
                  Color.lerp(Colors.white, colorScheme.primary, 0.8)!, // Brillo sutil
                  colorScheme.primary,
                  colorScheme.secondary, // Sombra
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.4, 1.0], // âœ¨ TransiciÃ³n mÃ¡s rica en 3 paradas
              )
            : null,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        border: Border.all(
          color: usaGradientePrimario ? Colors.transparent : borderColor,
          width: esBordeBrillante ? 1.5 : 1,
        ),
        boxShadow: isDark ? [] : ColoresApp.sombraSuave,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(DimensionesApp.radioGrande),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.2), // Mejor splash para fondos oscuros/degradados
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTokens.paddingEstandar),
            child: usaGradientePrimario
                ? Theme(
                    data: theme.copyWith(
                      iconTheme: const IconThemeData(color: Colors.white),
                      textTheme: theme.textTheme.apply(
                        bodyColor: Colors.white,
                        displayColor: Colors.white,
                      ),
                      listTileTheme: theme.listTileTheme.copyWith(
                        iconColor: Colors.white,
                        textColor: Colors.white,
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: child,
                    ),
                  )
                : child,
          ),
        ),
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2), // TranslÃºcido
        borderRadius: BorderRadius.circular(DimensionesApp.radioMedio),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}

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
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
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
