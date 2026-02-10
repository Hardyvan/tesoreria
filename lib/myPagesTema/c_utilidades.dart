import 'package:intl/intl.dart';

class AyudantesFormato {
  // --- SINGLETONS DE RENDIMIENTO (Se crean una sola vez) ---
  
  // Usamos es_PE para asegurar formatos peruanos correctos
  static final NumberFormat _formatoSoles = NumberFormat.currency(
    locale: 'es_PE', 
    symbol: 'S/ ', 
    decimalDigits: 2
  );

  static final NumberFormat _formatoMiles = NumberFormat('#,###', 'es_PE');
  
  // Formatos de fecha cacheados
  static final DateFormat _fechaHora = DateFormat('dd MMM yyyy, hh:mm a', 'es_PE');
  static final DateFormat _fechaSola = DateFormat('dd MMM yyyy', 'es_PE');
  static final DateFormat _soloHora = DateFormat('hh:mm a', 'es_PE');
  static final DateFormat _fechaCorta = DateFormat('dd/MM', 'es_PE');

  // =========================================================
  // MÉTODOS PÚBLICOS
  // =========================================================

  /// Convierte 25.5 -> "S/ 25.50"
  static String precio(double? monto) {
    if (monto == null) return "S/ 0.00";
    return _formatoSoles.format(monto);
  }

  /// Convierte 5 -> "0005" (Ideal para Tickets)
  static String numeroTicket(int numero, {int digitos = 4}) {
    return numero.toString().padLeft(digitos, '0');
  }

  /// Manejo inteligente de fechas
  static String fecha(DateTime? fecha, {bool incluirHora = false}) {
    if (fecha == null) return "-";
    return incluirHora 
        ? _fechaHora.format(fecha) 
        : _fechaSola.format(fecha);
  }

  static String fechaCorta(DateTime? fecha) {
    if (fecha == null) return "-";
    return _fechaCorta.format(fecha);
  }

  static String hora(DateTime? fecha) {
    if (fecha == null) return "-";
    return _soloHora.format(fecha);
  }

  /// Formatea miles: 1500 -> "1,500"
  static String numero(int? numero) {
    if (numero == null) return "0";
    return _formatoMiles.format(numero);
  }

  /// Capitalizar Nombres: "ivan velez" -> "Ivan Velez"
  /// Vital para que la lista de alumnos se vea profesional
  static String capitalizarTexto(String texto) {
    if (texto.isEmpty) return "";
    return texto.split(' ').map((palabra) {
      if (palabra.isEmpty) return "";
      return "${palabra[0].toUpperCase()}${palabra.substring(1).toLowerCase()}";
    }).join(' ');
  }
}

// =========================================================
// EXTENSIONES (Syntactic Sugar)
// =========================================================

extension DoubleExtension on double? {
  String toSoles() => AyudantesFormato.precio(this);
  String toPorcentaje() => "${(this ?? 0).toStringAsFixed(1)}%";
}

extension IntExtension on int? {
  String toTicket() => AyudantesFormato.numeroTicket(this ?? 0);
  String toMiles() => AyudantesFormato.numero(this);
}

extension DateTimeExtension on DateTime? {
  String toFechaUsuario() => AyudantesFormato.fecha(this);
  String toFechaHora() => AyudantesFormato.fecha(this, incluirHora: true);
  
  // Extra: Lógica de "Hace x tiempo" (Como WhatsApp)
  String timeAgo() {
    if (this == null) return "";
    final diferencia = DateTime.now().difference(this!);
    
    if (diferencia.inDays > 7) return AyudantesFormato.fechaCorta(this);
    if (diferencia.inDays >= 1) return "Hace ${diferencia.inDays} días";
    if (diferencia.inHours >= 1) return "Hace ${diferencia.inHours} h";
    if (diferencia.inMinutes >= 1) return "Hace ${diferencia.inMinutes} min";
    return "Ahora mismo";
  }
}

extension StringExtension on String {
  String toCapitalized() => AyudantesFormato.capitalizarTexto(this);
}
