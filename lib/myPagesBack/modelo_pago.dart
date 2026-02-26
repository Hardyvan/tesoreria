class Pago {
  final int id;
  final int usuarioId;
  final int actividadId;
  final double montoPagado;
  final DateTime fechaPago;
  final bool confirmado;

  Pago({
    required this.id,
    required this.usuarioId,
    required this.actividadId,
    required this.montoPagado,
    required this.fechaPago,
    required this.confirmado,
  });

  // Factory para crear desde BD
  factory Pago.desdeMapa(Map<String, dynamic> mapa) {
    return Pago(
      id: mapa['id'] ?? 0,
      usuarioId: mapa['usuario_id'] ?? 0,
      actividadId: mapa['actividad_id'] ?? 0,
      montoPagado: (mapa['monto'] ?? 0.0).toDouble(),
      fechaPago: mapa['fecha_pago'] ?? DateTime.now(),
      confirmado: mapa['confirmado'] == 1 || mapa['confirmado'] == true,
    );
  }

  // Convertir a Mapa (para insertar si fuera necesario, aunque usualmente se mandan campos sueltos)
  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'actividad_id': actividadId,
      'monto': montoPagado,
      'fecha_pago': fechaPago.toIso8601String(),
      'confirmado': confirmado ? 1 : 0,
    };
  }
}
