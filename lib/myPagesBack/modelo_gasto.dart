class Gasto {
  final int id;
  final String descripcion;
  final double monto;
  final DateTime fechaGasto;
  final int usuarioId;
  final int? actividadId; // NUEVO: Para asociar gasto a una actividad

  Gasto({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.fechaGasto,
    required this.usuarioId,
    this.actividadId,
  });

  factory Gasto.desdeMapa(Map<String, dynamic> mapa) {
    return Gasto(
      id: mapa['id'] ?? 0,
      descripcion: mapa['descripcion'] ?? '',
      monto: (mapa['monto'] ?? 0.0).toDouble(),
      fechaGasto: mapa['fecha_gasto'] ?? DateTime.now(),
      usuarioId: mapa['usuario_id'] ?? 0,
      actividadId: mapa['actividad_id'], // Puede ser null
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'descripcion': descripcion,
      'monto': monto,
      'fecha_gasto': fechaGasto.toIso8601String(),
      'usuario_id': usuarioId,
      'actividad_id': actividadId,
    };
  }
}
