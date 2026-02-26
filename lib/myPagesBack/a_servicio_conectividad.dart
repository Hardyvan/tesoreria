import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ServicioConectividad with ChangeNotifier {
  bool _tieneConexion = true;
  bool get tieneConexion => _tieneConexion;

  late StreamSubscription<ConnectivityResult> _subscription;

  ServicioConectividad() {
    _inicializar();
  }

  void _inicializar() async {
    // Estado inicial
    final resultado = await Connectivity().checkConnectivity();
    _actualizarEstado(resultado);

    // Escuchar cambios
    _subscription = Connectivity().onConnectivityChanged.listen(_actualizarEstado);
  }

  void _actualizarEstado(ConnectivityResult resultado) {
    bool nuevaConexion = resultado != ConnectivityResult.none;
    
    // Solo notificar si cambió
    if (_tieneConexion != nuevaConexion) {
      _tieneConexion = nuevaConexion;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
