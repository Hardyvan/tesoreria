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
    // Parseo seguro de fecha (API devuelve String, mysql1 devolvía DateTime)
    DateTime fechaCreacion = DateTime.now();
    final rawFecha = mapa['fecha_creacion'] ?? mapa['fecha_creada'];
    if (rawFecha is DateTime) {
      fechaCreacion = rawFecha;
    } else if (rawFecha != null) {
      fechaCreacion = DateTime.tryParse(rawFecha.toString()) ?? DateTime.now();
    }

    return Actividad(
      id: mapa['id'] is int ? mapa['id'] : int.tryParse(mapa['id']?.toString() ?? '0') ?? 0,
      titulo: mapa['titulo']?.toString() ?? '',
      costo: (mapa['costo'] is num) ? (mapa['costo'] as num).toDouble() : double.tryParse(mapa['costo']?.toString() ?? '0') ?? 0.0,
      fechaCreada: fechaCreacion,
      fechaLimite: mapa['fecha_limite'] != null ? DateTime.tryParse(mapa['fecha_limite'].toString()) : null,
      multaPorDia: (mapa['multa_por_dia'] is num) ? (mapa['multa_por_dia'] as num).toDouble() : double.tryParse(mapa['multa_por_dia']?.toString() ?? '0') ?? 0.0,
    );
  }
}


