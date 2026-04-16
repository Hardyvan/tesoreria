class ExcepcionSegura implements Exception {
  final String mensajeUsuario;
  final String? detalleTecnico; // Solo para log interno, NO mostrar al usuario

  ExcepcionSegura(this.mensajeUsuario, [this.detalleTecnico]);

  @override
  String toString() => mensajeUsuario;
}
