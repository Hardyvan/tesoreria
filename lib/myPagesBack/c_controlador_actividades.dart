import 'package:flutter/material.dart';
import 'modelo_actividad.dart';

class ControladorActividades extends ChangeNotifier {
  final List<Actividad> _actividades = [];
  bool _cargando = false;

  List<Actividad> get actividades => _actividades;
  bool get cargando => _cargando;

  // Crear una nueva actividad (Solo Admin)
  Future<bool> crearActividad(String titulo, double costo) async {
    _cargando = true;
    notifyListeners();
    
    try {
      // Lógica de inserción en BD
      // INSERT INTO salon_actividades ...
      await Future.delayed(const Duration(seconds: 1));
      
      // Actualizar lista local
      _actividades.add(Actividad(
        id: DateTime.now().millisecondsSinceEpoch, 
        titulo: titulo, 
        costo: costo, 
        fechaCreada: DateTime.now()
      ));
      
      return true;
    } catch (e) {
       debugPrint('Error creando actividad: $e');
       return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Listar actividades disponibles
  Future<void> listarActividades() async {
    // SELECT * FROM salon_actividades
  }
}
