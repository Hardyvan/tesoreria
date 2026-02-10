import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../myPagesBack/a_controlador_auth.dart';

// Importamos las vistas
import '../myPages/d_lista_deudores.dart';
import '../myPages/c_registro_pagos.dart';
import '../myPages/h_perfil_usuario.dart';
import '../myPages/b_crear_actividad.dart';

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
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final esAdmin = auth.esAdmin;

    // DEFINICIÓN DINÁMICA DE VISTAS SEGÚN ROL
    List<Widget> vistas = [];
    List<NavigationDestination> botonesVavegacion = [];

    // 1. Dashboard / Deudores (Para todos o solo Admin?)
    // Asumiremos que todos pueden ver el semáforo, pero solo admin edita
    vistas.add(const ListaDeudores());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      label: 'Estado',
    ));

    // 2. Registro de Pagos (Solo Admin registra, Alumnos ven historial propio)
    if (esAdmin) {
      vistas.add(const RegistroPagos());
      botonesVavegacion.add(const NavigationDestination(
        icon: Icon(Icons.payment),
        label: 'RegistrarPago',
      ));
      
      vistas.add(const CrearActividad());
      botonesVavegacion.add(const NavigationDestination(
        icon: Icon(Icons.add_circle_outline),
        label: 'Crear Actividad',
      ));
    }

    // 3. Perfil (Para todos)
    vistas.add(const PerfilUsuario());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.person_outline),
      label: 'Mi Perfil',
    ));



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
