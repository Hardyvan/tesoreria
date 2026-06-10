import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ServicioConectividad with ChangeNotifier, WidgetsBindingObserver {
  bool _tieneConexion = true;
  bool get tieneConexion => _tieneConexion;

  late StreamSubscription<ConnectivityResult> _subscription;
  Timer? _debounce;
  int _currentCheckId = 0;

  ServicioConectividad() {
    WidgetsBinding.instance.addObserver(this);
    _inicializar();
  }

  void _inicializar() async {
    // Estado inicial
    try {
      final resultado = await Connectivity().checkConnectivity();
      unawaited(_verificarConexionReal(resultado));
    } catch (_) {}

    // Escuchar cambios con un retraso (debouncer) para evitar falsos positivos al reanudar la app
    _subscription = Connectivity().onConnectivityChanged.listen((resultado) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(seconds: 1), () {
        _verificarConexionReal(resultado);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _forzarVerificacion();
    }
  }

  void _forzarVerificacion() async {
    try {
      final resultado = await Connectivity().checkConnectivity();
      unawaited(_verificarConexionReal(resultado));
    } catch (_) {}
  }

  Future<bool> _lookupReal() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verificarConexionReal(ConnectivityResult resultado) async {
    final checkId = ++_currentCheckId;

    if (resultado == ConnectivityResult.none) {
      _actualizarEstado(false, checkId);
      return;
    }

    // Primer intento de ping real
    bool conectado = await _lookupReal();
    if (conectado) {
      _actualizarEstado(true, checkId);
      return;
    }

    // Reintentos progresivos en segundos: 2, 4, 8
    final reintentos = [2, 4, 8];
    for (int delay in reintentos) {
      await Future.delayed(Duration(seconds: delay));
      
      // Si se inició un nuevo proceso de verificación, abortamos este
      if (checkId != _currentCheckId) return;

      try {
        final resultadoActual = await Connectivity().checkConnectivity();
        if (resultadoActual == ConnectivityResult.none) {
          _actualizarEstado(false, checkId);
          return;
        }
      } catch (_) {}
      
      conectado = await _lookupReal();
      if (conectado) {
        _actualizarEstado(true, checkId);
        return;
      }
    }

    _actualizarEstado(false, checkId);
  }

  void _actualizarEstado(bool nuevoEstado, int checkId) {
    if (checkId == _currentCheckId) {
      if (_tieneConexion != nuevoEstado) {
        _tieneConexion = nuevoEstado;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
