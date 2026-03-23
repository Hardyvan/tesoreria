class Pago {
  final int id;
  final int usuarioId;
  final int actividadId;
  final double montoPagado;
  final double montoMulta;
  final DateTime fechaPago;
  final bool confirmado;
  final String metodoPago;

  Pago({
    required this.id,
    required this.usuarioId,
    required this.actividadId,
    required this.montoPagado,
    this.montoMulta = 0.0,
    required this.fechaPago,
    required this.confirmado,
    this.metodoPago = 'Efectivo',
  });

  // Factory para crear desde BD
  factory Pago.desdeMapa(Map<String, dynamic> mapa) {
    return Pago(
      id: mapa['id'] ?? 0,
      usuarioId: mapa['usuario_id'] ?? 0,
      actividadId: mapa['actividad_id'] ?? 0,
      montoPagado: (mapa['monto'] ?? 0.0).toDouble(),
      montoMulta: (mapa['monto_multa'] ?? 0.0).toDouble(),
      fechaPago: mapa['fecha_pago'] ?? DateTime.now(),
      confirmado: mapa['confirmado'] == 1 || mapa['confirmado'] == true,
      metodoPago: mapa['metodo_pago'] ?? 'Efectivo',
    );
  }

  // Convertir a Mapa (para insertar si fuera necesario, aunque usualmente se mandan campos sueltos)
  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'actividad_id': actividadId,
      'monto': montoPagado,
      'monto_multa': montoMulta,
      'fecha_pago': fechaPago.toIso8601String(),
      'confirmado': confirmado ? 1 : 0,
      'metodo_pago': metodoPago,
    };
  }
}
