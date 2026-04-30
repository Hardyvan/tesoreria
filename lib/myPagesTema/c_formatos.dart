import 'package:intl/intl.dart';

class AyudantesFormato {
  static const String _locale = 'es_PE';

  static final NumberFormat _formatoMiles = NumberFormat('#,###', _locale);
  static final NumberFormat _formatoCompacto = NumberFormat.compact(locale: _locale);

  static final DateFormat _fechaHora = DateFormat('dd MMM yyyy, hh:mm a', _locale);
  static final DateFormat _fechaSola = DateFormat('dd MMM yyyy', _locale);
  static final DateFormat _soloHora = DateFormat('hh:mm a', _locale);
  static final DateFormat _fechaCorta = DateFormat('dd/MM', _locale);

  static String precio(double? monto) {
    // Usamos 'en_US' localmente aquí para forzar el PUNTO en decimales y COMA en miles
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2);
    return 'S/ ${fmt.format(monto ?? 0).trim()}';
  }

  static String numeroTicket(int numero, {int digitos = 4}) =>
      numero.toString().padLeft(digitos, '0');

  static String fecha(DateTime? fecha, {bool incluirHora = false}) {
    if (fecha == null) return '-';
    return incluirHora ? _fechaHora.format(fecha) : _fechaSola.format(fecha);
  }

  static String fechaCorta(DateTime? fecha) =>
      fecha == null ? '-' : _fechaCorta.format(fecha);

  static String hora(DateTime? fecha) =>
      fecha == null ? '-' : _soloHora.format(fecha);

  static String numero(int? numero) => _formatoMiles.format(numero ?? 0);

  static String numeroCompacto(num? numero) => _formatoCompacto.format(numero ?? 0);

  static String capitalizarTexto(String texto) {
    if (texto.trim().isEmpty) return '';
    return texto.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase().split(' ').map((palabra) {
      if (palabra.isEmpty) return '';
      if (palabra.length == 1) return palabra.toUpperCase();
      return '${palabra[0].toUpperCase()}${palabra.substring(1)}';
    }).join(' ');
  }
}

extension FormatoMoneda on double? {
  String toSoles() => AyudantesFormato.precio(this);
  String toPorcentaje() => '${(this ?? 0).toStringAsFixed(1)}%';
  String toCompacto() => AyudantesFormato.numeroCompacto(this);
}

extension FormatoEnteros on int? {
  String toTicket({int digitos = 4}) => AyudantesFormato.numeroTicket(this ?? 0, digitos: digitos);
  String toMiles() => AyudantesFormato.numero(this);
  String toCompacto() => AyudantesFormato.numeroCompacto(this);
}

extension FormatoFechas on DateTime? {
  String toFechaUsuario() => AyudantesFormato.fecha(this);
  String toFechaHora() => AyudantesFormato.fecha(this, incluirHora: true);

  String timeAgo() {
    if (this == null) return '';
    final diferencia = DateTime.now().difference(this!);

    if (diferencia.isNegative) return 'En el futuro';
    if (diferencia.inDays > 7) return AyudantesFormato.fechaCorta(this);
    if (diferencia.inDays >= 1) return 'Hace ${diferencia.inDays}d';
    if (diferencia.inHours >= 1) return 'Hace ${diferencia.inHours}h';
    if (diferencia.inMinutes >= 1) return 'Hace ${diferencia.inMinutes} min';
    return 'Ahora mismo';
  }
}

extension FormatoStrings on String {
  String toCapitalized() => AyudantesFormato.capitalizarTexto(this);

  String toFirstName() {
    if (trim().isEmpty) return '';
    return trim().split(' ').first.toCapitalized();
  }

  double toSafeDouble() {
    if (trim().isEmpty) return 0.0;
    final cleanString = replaceAll(RegExp(r'[^0-9\.-]'), '');
    return double.tryParse(cleanString) ?? 0.0;
  }

  int toSafeInt() {
    if (trim().isEmpty) return 0;
    final cleanString = replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(cleanString) ?? 0;
  }
}

