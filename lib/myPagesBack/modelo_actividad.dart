class Actividad {
  final int id;
  final String titulo; // "Cuota Mensual", "Pollada"
  final double costo;
  final DateTime fechaCreada;
  final DateTime? fechaLimite;
  final double multaPorDia;
  final bool requiereAsistencia;
  final double multaInasistencia;

  Actividad({
    required this.id,
    required this.titulo,
    required this.costo,
    required this.fechaCreada,
    this.fechaLimite,
    this.multaPorDia = 0.0,
    this.requiereAsistencia = false,
    this.multaInasistencia = 0.0,
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
      requiereAsistencia: mapa['requiere_asistencia'] == 1 || mapa['requiere_asistencia'] == true || mapa['requiere_asistencia'] == '1',
      multaInasistencia: (mapa['multa_inasistencia'] is num) ? (mapa['multa_inasistencia'] as num).toDouble() : double.tryParse(mapa['multa_inasistencia']?.toString() ?? '0') ?? 0.0,
    );
  }
}


