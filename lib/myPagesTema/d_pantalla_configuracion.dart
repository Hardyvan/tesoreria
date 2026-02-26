import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'a_tema.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Experiencia'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. SWITCH MODO OSCURO
            const _ThemeSwitchTile(),

            const SizedBox(height: 25),

            // 2. PALETA DE COLORES
            Text(
              'Color Corporativo',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Selecciona el color principal de la aplicación',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            const _ThemeColorPicker(),

            const SizedBox(height: 25),

            // 3. ESTILO VISUAL
            Text(
              'Estilo de Componentes',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Define la forma de botones y tarjetas',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            const _ThemeStyleSelector(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  const _ThemeSwitchTile();

  @override
  Widget build(BuildContext context) {
    final proveedor = context.watch<ProveedorTema>();
    final isDark = proveedor.modoTema == ThemeMode.dark;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(isDark ? 'Descansa tu vista con tonos oscuros' : 'Interfaz clara y luminosa'),
      value: isDark,
      activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      activeThumbColor: Theme.of(context).colorScheme.primary,
      onChanged: (bool value) {
        context.read<ProveedorTema>().cambiarTema(value);
      },
    );
  }
}

class _ThemeColorPicker extends StatelessWidget {
  const _ThemeColorPicker();

  @override
  Widget build(BuildContext context) {
    final isMobileSmall = MediaQuery.of(context).size.width < 360;

    return Consumer<ProveedorTema>(
      builder: (context, proveedor, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: AppPalettes.coloresDisponibles.map((color) {

            final isSelected = proveedor.colorSeleccionado.toARGB32() == color.toARGB32();

            return GestureDetector(
              onTap: () => proveedor.cambiarColorPrimario(color),
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: isMobileSmall ? 45 : 55,
                  height: isMobileSmall ? 45 : 55,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ThemeStyleSelector extends StatelessWidget {
  const _ThemeStyleSelector();

  IconData _getStyleIcon(AppStyle style) {
    switch (style) {
      case AppStyle.standard: return Icons.check_box_outline_blank_rounded;
      case AppStyle.modern:   return Icons.circle_outlined;
      case AppStyle.elegant:  return Icons.square_outlined;
      case AppStyle.tech:     return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proveedor = context.watch<ProveedorTema>();
    final colorScheme = theme.colorScheme;

    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: AppStyle.values.map((style) {
          final isSelected = proveedor.estiloSeleccionado == style;
          final styleIcon = _getStyleIcon(style);

          return ChoiceChip(
            avatar: Icon(
              styleIcon,
              size: 18,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            label: Text(
              style.name.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            selected: isSelected,
            onSelected: (bool selected) {
              if (selected) proveedor.cambiarEstilo(style);
            },
            showCheckmark: false,
            elevation: isSelected ? 4 : 0,
            pressElevation: 2,
            selectedColor: colorScheme.primary,
            backgroundColor: theme.brightness == Brightness.dark
                ? colorScheme.surfaceContainerHigh
                : Colors.grey.shade100,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          );
        }).toList(),
      ),
    );
  }
}