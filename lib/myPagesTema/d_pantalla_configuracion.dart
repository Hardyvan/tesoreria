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
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon:  Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Personalizar Experiencia',
        ),
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
            /*Text(
              'Estilo de Componentes',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Define la forma de botones y tarjetas',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            const _ThemeStyleSelector(),*/

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
            AppPalettes.obtenerColorSecundario(color);

            return GestureDetector(
              onTap: () => proveedor.cambiarColorPrimario(color),
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: isMobileSmall ? 45 : 55,
                  height: isMobileSmall ? 45 : 55,
                  padding: isSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
