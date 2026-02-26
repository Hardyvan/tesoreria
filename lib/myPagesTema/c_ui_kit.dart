import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'a_tema.dart';

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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    final shapeTema = theme.elevatedButtonTheme.style?.shape?.resolve({})
        ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.paddingEstandar));

    final activeGradient = gradient ?? LinearGradient(
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: isEnabled ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ] : [],
        ),
        child: Material(
          color: isEnabled ? Colors.transparent : theme.disabledColor,
          shape: shapeTema,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: isEnabled ? activeGradient : null,
            ),
            child: InkWell(
              onTap: isEnabled ? onPressed : null,
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  width: 24, height: 24,
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
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

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
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
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

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: widget.maxLines,
      style: theme.textTheme.bodyLarge,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(
            widget.prefixIcon,
            color: theme.iconTheme.color?.withValues(alpha: 0.7) ?? theme.primaryColor
        ),
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

    final baseShape = theme.cardTheme.shape as OutlinedBorder?;

    final dynamicShape = esBordeBrillante && baseShape != null
        ? baseShape.copyWith(
      side: BorderSide(
        color: theme.primaryColor.withValues(alpha: 0.5),
        width: 1.5,
      ),
    )
        : baseShape;

    return Card(
      color: backgroundColor ?? theme.cardTheme.color,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: dynamicShape,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.primaryColor.withValues(alpha: 0.1),
        highlightColor: theme.primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppTokens.paddingEstandar),
          child: child,
        ),
      ),
    );
  }
}
class ManejadorErrores {


  /// Muestra un SnackBar rojo estilizado con el mensaje de error.

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

                  Text(

                      mensaje,

                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)

                  ),

                  if (detalle != null)

                    Text(

                        detalle,

                        style: const TextStyle(fontSize: 12, color: Colors.white70)

                    ),

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



  /// Muestra un Dialog para errores críticos que requieren acción del usuario.

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

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: const Text('Entendido'),

          )

        ],

      ),

    );

  }



  /// Muestra un SnackBar verde de éxito.

  static void mostrarMensajeExito(BuildContext context, String mensaje) {

    if (!context.mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Row(

              children: [

                const Icon(Icons.check_circle_outline, color: Colors.white),

                const SizedBox(width: 12),

                Expanded(

                  child: Text(mensaje, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                ),

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
    String iniciales = nombre != null && nombre!.isNotEmpty 
        ? nombre!.substring(0, 1).toUpperCase() 
        : '?';
        
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