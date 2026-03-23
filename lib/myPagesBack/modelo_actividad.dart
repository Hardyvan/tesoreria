class Actividad {
  final int id;
  final String titulo; // "Cuota Mensual", "Pollada"
  final double costo;
  final DateTime fechaCreada;
  final DateTime? fechaLimite;
  final double multaPorDia;

  Actividad({
    required this.id,
    required this.titulo,
    required this.costo,
    required this.fechaCreada,
    this.fechaLimite,
    this.multaPorDia = 0.0,
  });

  factory Actividad.desdeMapa(Map<String, dynamic> mapa) {
    return Actividad(
      id: mapa['id'] ?? 0,
      titulo: mapa['titulo'] ?? '',
      costo: (mapa['costo'] ?? 0.0).toDouble(),
      fechaCreada: mapa['fecha_creacion'] ?? mapa['fecha_creada'] ?? DateTime.now(),
      fechaLimite: mapa['fecha_limite'] != null ? DateTime.tryParse(mapa['fecha_limite'].toString()) : null,
      multaPorDia: (mapa['multa_por_dia'] ?? 0.0).toDouble(),
    );
  }
}


