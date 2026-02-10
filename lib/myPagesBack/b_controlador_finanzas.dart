import 'package:flutter/material.dart';

class ControladorFinanzas extends ChangeNotifier {
  double _deudaTotal = 0.0;
  double _totalPagado = 0.0;
  
  double get deudaTotal => _deudaTotal;
  double get totalPagado => _totalPagado;

  // Cargar resumen financiero del usuario
  Future<void> cargarFinanzasUsuario(int usuarioId) async {
    // Simulación: Consultar a BD cuanto debe y cuanto ha pagado
    // SELECT SUM(costo) FROM salon_actividades ...
    // SELECT SUM(monto) FROM salon_pagos WHERE usuario_id = ...
    
    await Future.delayed(const Duration(milliseconds: 500));
    _deudaTotal = 150.00;
    _totalPagado = 50.00;
    notifyListeners();
  }
}
