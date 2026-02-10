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
}
