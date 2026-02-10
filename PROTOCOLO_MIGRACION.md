# Protocolo de Migración del Diseño (Tema)

Este documento detalla los pasos para portar el sistema de diseño y componentes (`myPagesTema`) de esta aplicación a otros proyectos Flutter.

## 1. Requisitos Previos

El módulo depende de las siguientes librerías que deben estar presentes en el `pubspec.yaml` del proyecto destino:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Gestión de estado para el tema
  provider: ^6.0.0

  # Formato de fechas y monedas (Usado en AyudantesFormato)
  intl: ^0.19.0
```

## 2. Archivos a Copiar

Copia la carpeta completa `myPagesTema` dentro de la carpeta `lib/` de tu nuevo proyecto.

Estructura esperada:
```
lib/
└── myPagesTema/
    ├── a_tema_app.dart          # Definiciones de colores, tipografía y tema
    ├── b_componentes_globales.dart # Widgets reutilizables (Botones, Inputs)
    ├── c_utilidades.dart        # Helpers de formato
```

## 3. Configuración de Recursos (Fuentes)

El tema utiliza las familias de fuentes **Poppins** (Títulos) e **Inter** (Cuerpo).

### Paso 3.1: Copiar Archivos de Fuente
Copia la carpeta `assets/fonts/` con los archivos `.ttf` correspondientes al nuevo proyecto en la misma ruta.

### Paso 3.2: Registrar en pubspec.yaml
Añade las definiciones de fuente en el `pubspec.yaml` del nuevo proyecto:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Regular.ttf
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fonts/Poppins-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Poppins-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter_28pt-Regular.ttf
        - asset: assets/fonts/Inter_28pt-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter_28pt-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter_28pt-Bold.ttf
          weight: 700
```

## 4. Inicialización en main.dart

Para que el cambio de tema funcione, debes envolver tu aplicación con el `ProveedorTema`.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'myPagesTema/a_tema_app.dart'; // Ajusta la ruta según corresponda

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProveedorTema()),
      ],
      child: const MiApp(),
    ),
  );
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumir el proveedor de tema
    final providerM = Provider.of<ProveedorTema>(context);

    return MaterialApp(
      title: 'Nueva App',
      // Temas
      theme: TemaApp.temaClaro,
      darkTheme: TemaApp.temaOscuro,
      themeMode: providerM.modoTema, // Importante para el cambio dinámico
      
      home: const Scaffold(
        body: Center(child: Text('Hola Mundo')),
      ),
    );
  }
}
```

## 5. Uso de Componentes (Básico)

Una vez configurado, puedes usar los estilos y componentes en cualquier parte:

```dart
import 'package:flutter/material.dart';
import 'myPagesTema/a_tema_app.dart';
import 'myPagesTema/b_componentes_globales.dart';

// ...
// Uso de colores
Container(color: ColoresApp.primario);

// Uso de tipografía
Text('Título', style: Theme.of(context).textTheme.headlineLarge);

// Uso de componentes
BotonGradiente(
  text: 'Acción Principal',
  onPressed: () {},
  icon: Icons.rocket,
);
```

---

# Contexto del Sistema de Diseño

Estoy desarrollando una app Flutter que utiliza un sistema de diseño centralizado en la carpeta `lib/myPagesTema/`. **Es obligatorio usar estas definiciones en lugar de valores hardcodeados.**

## 1. Importaciones Obligatorias

Siempre incluye estos imports si vas a generar UI:

```dart
import '../myPagesTema/a_tema_app.dart';           // Para ColoresApp, DimensionesApp, TemaApp
import '../myPagesTema/b_componentes_globales.dart'; // Para BotonGradiente, CampoTextoPersonalizado
import '../myPagesTema/c_utilidades.dart';           // Para AyudantesFormato (Money/Date)
```

## 2. Reglas de Estilo (Estrictas)

### ❌ NO USAR (Incorrecto):
*   `Colors.blue`, `Colors.red` (Usa **ColoresApp**).
*   `TextStyle` hardcodeados (Usa **Theme.of(context).textTheme**).
*   `ElevatedButton` genéricos (Usa **BotonGradiente**).

### ✅ USAR (Correcto):
*   **Colores**: `ColoresApp.primario`, `ColoresApp.fondoClaro`.
*   **Tipografía**: `Theme.of(context).textTheme.headlineLarge`.
*   **Componentes**: `BotonGradiente`, `CampoTextoPersonalizado`, `TarjetaPremium`.
*   **Formatos**: `AyudantesFormato.formatearPrecio()`.

## 3. Reglas de Organización: "Extract Method" (CRÍTICO)

### ❌ NO USAR (Código Espagueti):
*   Métodos `build()` gigantes con cientos de líneas.
*   Anidación excesiva (Callback hell) dentro del build.

### ✅ USAR (Refactorización por Extracción):
*   Divide la UI en métodos privados pequeños y descriptivos.
*   Cada método debe tener una sola responsabilidad (ej: `_buildHeader()`, `_buildUserList()`).
*   El método `build()` principal debe ser un "índice" limpio de la pantalla.

## 4. Ejemplo de Estructura Esperada

Si te pido "crear una pantalla de perfil", el código debe verse así:

```dart
import 'package:flutter/material.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';
import '../myPagesTema/c_utilidades.dart';

class PerfilScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondoClaro,
      appBar: AppBar(title: Text('Perfil')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildEncabezadoPerfil(context), // ✅ Método extraído
            const SizedBox(height: 20),
            _buildEstadisticas(context),     // ✅ Método extraído
            const SizedBox(height: 20),
            _buildBotonAccion(),             // ✅ Método extraído
          ],
        ),
      ),
    );
  }

  // 👇 MÉTODOS EXTRAÍDOS PARA LIMPIEZA 👇

  Widget _buildEncabezadoPerfil(BuildContext context) {
    return TarjetaPremium(
      child: Column(
        children: [
          CircleAvatar(backgroundColor: ColoresApp.primario),
          Text('Usuario', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildEstadisticas(BuildContext context) {
    return Row(
      children: [
        Text(AyudantesFormato.formatearPrecio(100), style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildBotonAccion() {
    return BotonGradiente(
      text: 'Editar Perfil',
      icon: Icons.edit,
      onPressed: () {},
    );
  }
}
```
