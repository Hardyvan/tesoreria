import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/b_logica_estado_financiero.dart';
import '../myPagesBack/e_logica_actividades.dart';
import '../myPages/b_estado_financiero.dart';
import '../myPages/f_perfil.dart';
import '../myMenu/d_historial_pagos.dart';
import '../myPages/e_actividades.dart';

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  int _indiceActual = 0;

  Future<void> _abrirWhatsApp() async {
    const String numero = '51990292918'; // Coordinación DSI
    const mensaje = 'Hola, tengo una consulta sobre mi estado de pagos.';
    final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error lanzando URL: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Red de Seguridad: Verificar si faltan datos obligatorios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<ControladorAuth>(context, listen: false);
      if (auth.usuarioActual != null) {
        if (auth.usuarioActual!.celular.isEmpty) {
          // Si logró entrar sin teléfono, lo sacamos de aquí
          Navigator.pushReplacementNamed(context, '/completar_perfil');
        } else {
          // --- OPTIMIZACIÓN: PRECARGA EN SEGUNDO PLANO ---
          // Precargamos los datos que se mostrarán en el menú lateral para evitar lag
          final finanzas = Provider.of<ControladorFinanzas>(context, listen: false);
          
          // 1. Precargar historial de pagos (para todos) — forzamos refresco al iniciar
          finanzas.obtenerDetallePagosPorActividad(auth.usuarioActual!.id, forceRefresh: true);
          finanzas.cargarFinanzasUsuario(auth.usuarioActual!.id);
          
          // 2. Precargar Reporte Financiero (Kardex global, para todos por política de transparencia)
          finanzas.obtenerResumenFinanciero();
          finanzas.obtenerMovimientosKardex(reset: true);
          
          // 3. Si es Admin, precargar datos de actividades
          if (auth.usuarioActual!.rol == 'Admin' || auth.usuarioActual!.rol == 'SuperAdmin') {
             final actividadesCtrl = Provider.of<ControladorActividades>(context, listen: false);
             actividadesCtrl.listarActividades();
          }
        }
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



    vistas.add(const HistorialPagos());
    botonesVavegacion.add(const NavigationDestination(
      icon: Icon(Icons.history_edu),
      label: 'Pagos',
    ));

    // NOTA: Reportes se ha movido al DrawerLateral

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
      label: 'Perfil',
    ));

    // NOTA: Auditoría se ha movido al Drawer Lateral



    // PROTECCIÓN CONTRA CRASH:
    if (_indiceActual >= vistas.length) {
      _indiceActual = 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          botonesVavegacion[_indiceActual].label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'DSI Tesorería',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.usuarioActual?.nombre ?? '',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.85), 
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Control de Caja', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Saldo y descarga de reportes', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                iconColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                textColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.pushNamed(context, '/portal_financiero');
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment_outlined),
                title: const Text('Kardex de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Historial completo de caja', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                iconColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                textColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.pushNamed(context, '/reportes');
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Balance por Fechas', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Ingresos, gastos y utilidades', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                iconColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                textColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/reportes_avanzados');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: const Text('Recaudación y Deudores', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                subtitle: const Text('Metas de cobro y lista de deudas', style: TextStyle(color: Colors.teal)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/insoft_analytics');
                },
              ),
              if (auth.usuarioActual?.rol == 'SuperAdmin' || auth.usuarioActual?.rol == 'Admin') ...[
                const Divider(),
                if (auth.usuarioActual?.rol == 'SuperAdmin')
                  ListTile(
                    leading: Icon(Icons.security, color: Theme.of(context).colorScheme.error),
                    title: Text(
                      'Auditoría de Sistema', 
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text('Corte de caja y logs de seguridad', style: TextStyle(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7))),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/auditoria');
                    },
                  ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                iconColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                textColor: isDark ? Colors.white : Theme.of(context).primaryColor,
                onTap: () {
                   auth.cerrarSesion();
                   Navigator.pushNamedAndRemoveUntil(context, '/inicio_sesion', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _indiceActual,
        children: vistas,
      ),
      floatingActionButton: _construirFAB(context, auth),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _indiceActual,
          onDestinationSelected: (i) => setState(() => _indiceActual = i),
          destinations: botonesVavegacion,
        ),
      ),
    );
  }

  Widget? _construirFAB(BuildContext context, ControladorAuth auth) {
    // Usaremos el índice para determinar qué FAB mostrar
    
    // 0: Estado Financiero -> Boton Whatsapp (Ayuda)
    // 1: Mis Pagos -> Boton Whatsapp (Ayuda)
    // 2: Gestion Actividades -> Boton Nueva Actividad
    // 3: Perfil -> Boton Whatsapp (Ayuda)
    
    // Si estamos en Gestión de Actividades (que para Admin suele ser el índice 2)
    final esAdmin = auth.usuarioActual?.rol == 'Admin' || auth.usuarioActual?.rol == 'SuperAdmin';
    if (esAdmin && _indiceActual == 2) {
      return FloatingActionButton.extended(
        heroTag: 'fab_actividad',
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => Navigator.pushNamed(context, '/crear_actividad'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVA ACTIVIDAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    // Para las otras pestañas, mostramos el botón de WhatsApp si no es la pestaña de Perfil (donde ya hay botones de contacto)
    if (_indiceActual == 1 || _indiceActual == 0) {
      return FloatingActionButton.extended(
        heroTag: 'fab_ayuda',
        onPressed: _abrirWhatsApp,
        backgroundColor: const Color(0xFF25D366),
        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
        label: const Text('Consultar Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    return null;
  }
}

