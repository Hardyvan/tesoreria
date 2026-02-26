class Actividad {
  final int id;
  final String titulo; // "Cuota Mensual", "Pollada"
  final double costo;
  final DateTime fechaCreada;

  Actividad({
    required this.id,
    required this.titulo,
    required this.costo,
    required this.fechaCreada,
  });

  factory Actividad.desdeMapa(Map<String, dynamic> mapa) {
    return Actividad(
      id: mapa['id'] ?? 0,
      titulo: mapa['titulo'] ?? '',
      costo: (mapa['costo'] ?? 0.0).toDouble(),
      fechaCreada: mapa['fecha_creada'] ?? DateTime.now(),
    );
  }
}


