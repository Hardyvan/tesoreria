import 'package:flutter/material.dart';

// Importamos Pantallas
import 'c_menu_principal.dart';
import '../myPages/a_inicio_sesion.dart';
import '../myPages/f_perfil.dart';
import '../myPages/b_estado_financiero.dart';
import '../myMenu/d_historial_pagos.dart'; 

import '../myPages/c_reportes.dart';
import '../myPages/d_reportes_avanzados.dart';
import '../myPages/g_portal_financiero.dart';
import '../myPages/e_actividades.dart';
import '../myPages/h_insoft_analytics.dart';
import '../myPages/i_control_asistencia.dart';
import '../myPagesBack/modelo_actividad.dart';

class RutasApp {
  // Constantes de Rutas
  static const String inicioSesion = '/inicio_sesion';
  static const String menuPrincipal = '/menu_principal';
  static const String estadoFinanciero = '/estado_financiero';
  static const String perfilUsuario = '/perfil_usuario';
  static const String gestionUsuarios = '/gestion_usuarios';
  static const String historialPagos = '/historial_pagos';
  static const String reportes = '/reportes';
  static const String auditoria = '/auditoria';
  static const String portalFinanciero = '/portal_financiero';

  // Mapa de Rutas
  static Map<String, WidgetBuilder> obtenerRutas() {
    return {
      inicioSesion: (_) => const InicioSesion(),
      menuPrincipal: (_) => const MenuPrincipal(),
      perfilUsuario: (_) => const PerfilUsuario(),
      gestionUsuarios: (_) => const GestionUsuarios(),
      estadoFinanciero: (_) => const ListaDeudores(),
      '/registro_correo': (_) => const PantallaRegistro(),
      '/completar_perfil': (_) => const PantallaCompletarPerfil(),
      '/historial_pagos': (_) => const HistorialPagos(),
      reportes: (_) => const ReporteFinanciero(),
      '/reportes_avanzados': (_) => const ReportesAvanzados(),
      auditoria: (_) => const AuditoriaAdmin(),
      portalFinanciero: (_) => const PortalFinanciero(),
      '/crear_actividad': (_) => const CrearActividad(),
      '/insoft_analytics': (_) => const InsoftAnalyticsDemo(),
      '/control_asistencia': (context) {
        final arg = ModalRoute.of(context)!.settings.arguments;
        return PantallaAsistencia(actividad: arg as Actividad);
      },
    };
  }
}
