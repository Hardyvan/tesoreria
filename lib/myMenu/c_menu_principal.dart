import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../myPagesBack/a_controlador_auth.dart';
import '../myPages/d_lista_deudores.dart';
import '../myPages/h_perfil_usuario.dart';
import '../myPages/g_reporte_financiero.dart';
import '../myPages/i_auditoria_admin.dart';
import '../myPages/e_gestion_actividades.dart';

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  int _indiceActual = 0;

  @override
  void initState() {
    super.initState();
    // Red de Seguridad: Verificar si faltan datos obligatorios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<ControladorAuth>(context, listen: false);
      if (auth.usuarioActual != null && auth.usuarioActual!.celular.isEmpty) {
        // Si logró entrar sin teléfono, lo sacamos de aquí
        Navigator.pushReplacementNamed(context, '/completar_perfil');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // DEFINICIÓN DINÁMICA DE VISTAS (IGUAL PARA TODOS)
    List<Widget> vistas = [];
    List<NavigationDestination> botonesVavegacion = [];

    // 1. Estado (Lista de Deudores Global - Transparencia Total)
    vistas.add(const ListaDeudores());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.people_alt_outlined),
      label: 'Estado',
    ));



    // 2. Reportes (Kardex Global - Transparencia Total)
    vistas.add(const ReporteFinanciero());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.assessment_outlined),
      label: 'Reportes',
    ));

    // 3. Gestión de Actividades (SOLO ADMIN/SUPER ADMIN)
    final auth = Provider.of<ControladorAuth>(context);
    final esAdminOpe = auth.usuarioActual?.rol == 'Admin' || auth.usuarioActual?.rol == 'SuperAdmin';
    if (esAdminOpe) {
      vistas.add(const GestionActividades());
      botonesVavegacion.add(const NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        label: 'Actividades',
      ));
    }

    // 4. Perfil (Para todos)
    vistas.add(const PerfilUsuario());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.person_outline),
      label: 'Mi Perfil',
    ));

    // 5. Auditoría (SOLO SUPER ADMIN)
    if (auth.usuarioActual?.rol == 'SuperAdmin') {
      // Importar arriba: import '../myPages/i_auditoria_admin.dart';
      vistas.add(const AuditoriaAdmin());
      botonesVavegacion.add(const NavigationDestination(
        icon: Icon(Icons.security, color: Colors.red),
        label: 'Auditoría',
      ));
    }



    // PROTECCIÓN CONTRA CRASH:
    // Si cambiamos de rol y el índice estaba en una pestaña que ya no existe (ej: 2 o 3),
    // lo reseteamos a 0 para evitar el error "RangeError".
    if (_indiceActual >= vistas.length) {
      _indiceActual = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: vistas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (i) => setState(() => _indiceActual = i),
        destinations: botonesVavegacion,
      ),
    );
  }
}
