import 'package:flutter/material.dart';

// Importamos Pantallas
import 'c_menu_principal.dart';
import '../myPages/a_inicio_sesion.dart';
import '../myPages/h_perfil_usuario.dart';
import '../myPages/e_gestion_usuarios.dart';
import '../myPages/d_lista_deudores.dart';
import '../myPages/b_registro_correo.dart';
import '../myPages/i_completar_perfil.dart';
// import '../myPages/b_crear_actividad.dart'; 
// import '../myPages/c_registro_pagos.dart';

class RutasApp {
  // Constantes de Rutas
  static const String inicioSesion = '/inicio_sesion';
  static const String menuPrincipal = '/menu_principal';
  static const String crearActividad = '/crear_actividad';
  static const String registroPagos = '/registro_pagos';
  static const String listaDeudores = '/lista_deudores';
  static const String perfilUsuario = '/perfil_usuario';
  static const String gestionUsuarios = '/gestion_usuarios';

  // Mapa de Rutas
  static Map<String, WidgetBuilder> obtenerRutas() {
    return {
      inicioSesion: (_) => const InicioSesion(),
      menuPrincipal: (_) => const MenuPrincipal(),
      perfilUsuario: (_) => const PerfilUsuario(),
      gestionUsuarios: (_) => const GestionUsuarios(),
      listaDeudores: (_) => const ListaDeudores(),
      '/registro_correo': (_) => const PantallaRegistro(),
      '/completar_perfil': (_) => const PantallaCompletarPerfil(),
    };
  }
}
