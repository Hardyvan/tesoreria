import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ServicioConectividad with ChangeNotifier {
  bool _tieneConexion = true;
  bool get tieneConexion => _tieneConexion;

  late StreamSubscription<ConnectivityResult> _subscription;
  Timer? _debounce;

  ServicioConectividad() {
    _inicializar();
  }

  void _inicializar() async {
    // Estado inicial
    final resultado = await Connectivity().checkConnectivity();
    unawaited(_verificarConexionReal(resultado));

    // Escuchar cambios con un retraso (debouncer) para evitar falsos positivos al reanudar la app
    _subscription = Connectivity().onConnectivityChanged.listen((resultado) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(seconds: 2), () {
        _verificarConexionReal(resultado);
      });
    });
  }

  Future<void> _verificarConexionReal(ConnectivityResult resultado) async {
    bool nuevaConexion = false;
    
    if (resultado != ConnectivityResult.none) {
      // Verificar que realmente haya internet y no sea solo conexión local
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          nuevaConexion = true;
        }
      } catch (_) {
        nuevaConexion = false;
      }
    }

    if (_tieneConexion != nuevaConexion) {
      _tieneConexion = nuevaConexion;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
