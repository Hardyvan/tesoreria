import 'dart:math';
import 'package:flutter/material.dart';
import 'a_tema.dart';

/// Tipos de efectos visuales que soporta el fondo animado
enum TipoClimaFondo {
  apagado,
  aurora, // Luciérnagas / orbes de luz flotantes sobre gradiente
  lluvia,  // Gotas de lluvia delgadas y rápidas en diagonal
  nieve    // Copos de nieve suaves cayendo con balanceo lateral
}

/// Modelo físico individual para cada partícula en pantalla
class ModeloParticula {
  double x;
  double y;
  double velocidadX;
  double velocidadY;
  double tamano;
  double opacidad;
  double opacidadBase;
  double angulo; // Usado para balanceo sinusoidal (nieve/flotación)
  double velocidadBalanceo;
  final Color color;

  ModeloParticula({
    required this.x,
    required this.y,
    required this.velocidadX,
    required this.velocidadY,
    required this.tamano,
    required this.opacidad,
    required this.angulo,
    required this.velocidadBalanceo,
    required this.color,
  }) : opacidadBase = opacidad;

  /// Actualiza la física de la partícula en base al tipo de clima
  void actualizar(double ancho, double alto, TipoClimaFondo clima) {
    switch (clima) {
      case TipoClimaFondo.nieve:
        // Cae suavemente hacia abajo y se balancea horizontalmente
        y += velocidadY;
        angulo += velocidadBalanceo;
        x += sin(angulo) * 0.6 + velocidadX;
        
        // Efecto de desvanecimiento sutil al flotar
        opacidad = opacidadBase * (0.6 + sin(angulo * 2) * 0.4);
        break;

      case TipoClimaFondo.lluvia:
        // Cae rápidamente en diagonal
        y += velocidadY;
        x += velocidadX;
        break;

      case TipoClimaFondo.aurora:
        // Flota lentamente hacia arriba y se mece con suavidad
        y += velocidadY;
        angulo += velocidadBalanceo;
        x += cos(angulo) * 0.3;
        
        // Pulso de luz brillante (lento)
        opacidad = opacidadBase * (0.5 + sin(angulo * 1.5) * 0.5);
        break;
        
      default:
        break;
    }

    // Reiniciar posición si sale de los límites de la pantalla con margen
    if (y > alto + 20) {
      y = -20;
      x = Random().nextDouble() * ancho;
    } else if (y < -20) {
      y = alto + 20;
      x = Random().nextDouble() * ancho;
    }

    if (x > ancho + 20) {
      x = -20;
    } else if (x < -20) {
      x = ancho + 20;
    }
  }
}

/// Painter que dibuja vectorialmente las partículas en el canvas
class WeatherParticlesPainter extends CustomPainter {
  final List<ModeloParticula> particulas;
  final TipoClimaFondo clima;

  WeatherParticlesPainter({required this.particulas, required this.clima});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..style = PaintingStyle.fill;

    for (var particula in particulas) {
      pincel.color = particula.color.withValues(alpha: particula.opacidad);

      if (clima == TipoClimaFondo.lluvia) {
        // La lluvia se dibuja como líneas delgadas e inclinadas para dar sensación de velocidad
        pincel.strokeWidth = particula.tamano * 0.8;
        pincel.style = PaintingStyle.stroke;
        pincel.strokeCap = StrokeCap.round;

        // Trayectoria de la línea (estela de la gota de lluvia)
        final inicio = Offset(particula.x, particula.y);
        final fin = Offset(
          particula.x + particula.velocidadX * 1.5,
          particula.y + particula.velocidadY * 1.5,
        );
        canvas.drawLine(inicio, fin, pincel);
      } else if (clima == TipoClimaFondo.aurora) {
        // Las partículas de aurora/luciérnagas se dibujan como círculos con un difuminado suave (brillo)
        final centro = Offset(particula.x, particula.y);
        
        // Crear un brillo radial simple dibujando un círculo semi-translúcido más grande de fondo
        final pincelBrillo = Paint()
          ..style = PaintingStyle.fill
          ..color = particula.color.withValues(alpha: particula.opacidad * 0.35);
        
        canvas.drawCircle(centro, particula.tamano * 2.8, pincelBrillo);
        canvas.drawCircle(centro, particula.tamano, pincel);
      } else {
        // Copos de nieve clásicos (círculos suaves)
        final centro = Offset(particula.x, particula.y);
        canvas.drawCircle(centro, particula.tamano, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeatherParticlesPainter oldDelegate) => true;
}

/// Widget contenedor que gestiona e itera el bucle físico de animación de las partículas
class EfectoParticulasWidget extends StatefulWidget {
  final TipoClimaFondo clima;
  final int cantidadParticulas;

  const EfectoParticulasWidget({
    super.key,
    required this.clima,
    this.cantidadParticulas = 35,
  });

  @override
  State<EfectoParticulasWidget> createState() => _EfectoParticulasWidgetState();
}

class _EfectoParticulasWidgetState extends State<EfectoParticulasWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controladorBucle;
  final List<ModeloParticula> _particulas = [];
  final Random _azar = Random();
  Size _ultimoTamano = Size.zero;

  @override
  void initState() {
    super.initState();
    // Bucle continuo a máxima tasa de refresco
    _controladorBucle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_actualizarFisica)..repeat();
  }

  @override
  void didUpdateWidget(covariant EfectoParticulasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clima != widget.clima) {
      _inicializarParticulas(_ultimoTamano);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ultimoTamano != Size.zero) {
      _inicializarParticulas(_ultimoTamano);
    }
  }

  @override
  void dispose() {
    _controladorBucle.dispose();
    super.dispose();
  }

  /// Inicializa las partículas en función del tipo de clima seleccionado
  void _inicializarParticulas(Size size) {
    if (size == Size.zero) return;
    
    _particulas.clear();
    final cantidad = widget.clima == TipoClimaFondo.lluvia ? (widget.cantidadParticulas * 1.5).toInt() : widget.cantidadParticulas;

    for (int i = 0; i < cantidad; i++) {
      double x = _azar.nextDouble() * size.width;
      double y = _azar.nextDouble() * size.height;
      double velocidadX = 0;
      double velocidadY = 0;
      double tamano = 0;
      double opacidad = 0;
      Color color = Colors.white;

      switch (widget.clima) {
        case TipoClimaFondo.nieve:
          // Copos de nieve: tamaños variados, caída vertical suave
          tamano = _azar.nextDouble() * 3.5 + 1.2;
          velocidadY = _azar.nextDouble() * 0.9 + 0.5;
          velocidadX = _azar.nextDouble() * 0.2 - 0.1;
          opacidad = _azar.nextDouble() * 0.5 + 0.3;
          color = Colors.white;
          break;

        case TipoClimaFondo.lluvia:
          // Lluvia: gotas muy delgadas, rápidas, caen inclinadas
          tamano = _azar.nextDouble() * 1.8 + 1.0;
          velocidadY = _azar.nextDouble() * 8.0 + 8.0;
          velocidadX = -3.0 - (_azar.nextDouble() * 2.0); // Viento hacia la izquierda
          opacidad = _azar.nextDouble() * 0.35 + 0.15;
          color = const Color(0xFFE0F2FE); // Celeste cristalino
          break;

        case TipoClimaFondo.aurora:
          // Destellos/Luciernagas de aurora: flotan lento hacia arriba
          tamano = _azar.nextDouble() * 4.5 + 2.0;
          velocidadY = -(_azar.nextDouble() * 0.3 + 0.15); // Hacia arriba
          velocidadX = 0;
          opacidad = _azar.nextDouble() * 0.6 + 0.2;
          
          // Mezcla de colores mágicos y vibrantes según el tema dinámico activo
          final theme = Theme.of(context);
          final colorPrimario = theme.primaryColor;
          final colorSecundario = theme.colorScheme.secondary;
          final colorTerciario = AppPalettes.obtenerColorTerciario(colorPrimario);
          
          final tonalidades = [
            Colors.white,
            colorPrimario.withValues(alpha: 0.7),
            colorSecundario.withValues(alpha: 0.7),
            colorTerciario.withValues(alpha: 0.7),
          ];
          color = tonalidades[_azar.nextInt(tonalidades.length)];
          break;

        default:
          break;
      }

      _particulas.add(
        ModeloParticula(
          x: x,
          y: y,
          velocidadX: velocidadX,
          velocidadY: velocidadY,
          tamano: tamano,
          opacidad: opacidad,
          angulo: _azar.nextDouble() * pi * 2,
          velocidadBalanceo: _azar.nextDouble() * 0.03 + 0.01,
          color: color,
        ),
      );
    }
  }

  void _actualizarFisica() {
    if (_ultimoTamano == Size.zero) return;
    setState(() {
      for (var particula in _particulas) {
        particula.actualizar(_ultimoTamano.width, _ultimoTamano.height, widget.clima);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clima == TipoClimaFondo.apagado) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_ultimoTamano != size) {
          _ultimoTamano = size;
          // Retrasar inicialización para no bloquear la fase de layout
          Future.microtask(() => _inicializarParticulas(size));
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: WeatherParticlesPainter(
              particulas: _particulas,
              clima: widget.clima,
            ),
          ),
        );
      },
    );
  }
}

/// Widget que renderiza el gradiente Aurora en movimiento constante y orgánico
class FondoAuroraAnimado extends StatefulWidget {
  const FondoAuroraAnimado({super.key});

  @override
  State<FondoAuroraAnimado> createState() => _FondoAuroraAnimadoState();
}

class _FondoAuroraAnimadoState extends State<FondoAuroraAnimado>
    with SingleTickerProviderStateMixin {
  late AnimationController _controladorMovimiento;

  @override
  void initState() {
    super.initState();
    // Animación cíclica e infinita muy lenta para evitar fatiga visual
    _controladorMovimiento = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controladorMovimiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorPrimario = theme.primaryColor;
    final colorSecundario = theme.colorScheme.secondary;
    final colorTerciario = AppPalettes.obtenerColorTerciario(colorPrimario);

    return AnimatedBuilder(
      animation: _controladorMovimiento,
      builder: (context, child) {
        final val = _controladorMovimiento.value;
        
        // Mapeamos los puntos de anclaje del gradiente con oscilaciones orgánicas
        final beginX = -1.0 + sin(val * pi) * 0.4;
        final beginY = -1.2 + cos(val * pi * 0.8) * 0.3;
        final endX = 1.0 + cos(val * pi) * 0.4;
        final endY = 1.2 + sin(val * pi * 0.6) * 0.3;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(beginX, beginY),
              end: Alignment(endX, endY),
              colors: [
                colorPrimario,
                colorPrimario.withValues(alpha: 0.85),
                colorTerciario.withValues(alpha: 0.9),
                colorSecundario.withValues(alpha: 0.85),
                colorSecundario,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Widget integral que unifica el gradiente Aurora y las capas de clima/partículas
class FondoAnimadoPremium extends StatelessWidget {
  final TipoClimaFondo clima;
  final Widget? child;

  const FondoAnimadoPremium({
    super.key,
    required this.clima,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = child;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Capa 1: El fondo de gradiente Aurora en constante movimiento
        const FondoAuroraAnimado(),

        // Capa 2: Efecto de iluminación/viñeta oscuro en las esquinas para resaltar el contenido central
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.4,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),

        // Capa 3: Bucle físico de partículas (Lluvia, Nieve o destellos)
        EfectoParticulasWidget(clima: clima),

        // Capa 4: Contenido del aplicativo
        // ignore: use_null_aware_elements
        if (contenido != null) contenido,
      ],
    );
  }
}
