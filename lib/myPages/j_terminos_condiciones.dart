import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';
import '../myMenu/b_rutas_app.dart';

class PantallaTerminos extends StatefulWidget {
  const PantallaTerminos({super.key});

  @override
  State<PantallaTerminos> createState() => _PantallaTerminosState();
}

class _PantallaTerminosState extends State<PantallaTerminos> {
  bool _aceptado = false;
  bool _guardando = false;

  Future<void> _guardarAceptacion() async {
    if (!_aceptado) return;

    setState(() => _guardando = true);
    try {
      final auth = Provider.of<ControladorAuth>(context, listen: false);
      final usuario = auth.usuarioActual;
      if (usuario != null) {
        final prefs = await SharedPreferences.getInstance();
        // Clave única por usuario para evitar conflictos si se cambia de cuenta
        await prefs.setBool('terms_accepted_${usuario.id}', true);
        
        if (mounted) {
          await Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la aceptación. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _rechazarYSalir() {
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    auth.cerrarSesion();
    Navigator.pushNamedAndRemoveUntil(context, RutasApp.inicioSesion, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Términos y Condiciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 2,
        automaticallyImplyLeading: false, // Evitar que el usuario retroceda sin aceptar
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mensaje de bienvenida
              Text(
                '¡Bienvenido a DSI Tesorería!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para continuar y utilizar las funciones del salón de manera segura y transparente, lee y acepta nuestro acuerdo de términos de uso.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),

              // 2. Caja de texto scrollable con los términos
              Expanded(
                child: TarjetaPremium(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  esBordeBrillante: isDark,
                  padding: const EdgeInsets.all(16),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Text(
                          _obtenerTextoTerminos(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.6,
                            color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Checkbox de aceptación
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                child: CheckboxListTile(
                  value: _aceptado,
                  onChanged: (val) => setState(() => _aceptado = val ?? false),
                  title: Text(
                    'Acepto los términos y condiciones de uso del servicio',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    ),
                  ),
                  activeColor: accentColor,
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 20),

              // 4. Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _rechazarYSalir,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Rechazar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_aceptado && !_guardando) ? _guardarAceptacion : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: _aceptado ? 2 : 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Aceptar y Entrar',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _obtenerTextoTerminos() {
    return 'TÉRMINOS Y CONDICIONES DE USO - DSI TESORERÍA\n\n'
        '1. OBJETO Y ALCANCE\n'
        'La aplicación "DSI Tesorería" es una herramienta privada diseñada con el propósito de optimizar la gestión financiera, el control de ingresos, los pagos de actividades y el registro de egresos de la sección del salón de clases. Su uso está estrictamente restringido a los alumnos autorizados y personal administrativo de la coordinación de la sección.\n\n'
        '2. POLÍTICA DE TRANSPARENCIA Y DATOS PÚBLICOS\n'
        'Con el objetivo de garantizar la total honestidad y claridad en el manejo de los fondos del salón, los usuarios entienden y aceptan que:\n'
        'a) El saldo general de caja, las actividades planificadas y el Kardex con el historial de todos los movimientos de efectivo (ingresos y gastos) serán visibles y transparentes para todos los integrantes registrados.\n'
        'b) La lista de aportes mostrará el estado de cuenta de cada integrante, identificando públicamente a los alumnos que se encuentren "Al día" o con cuotas pendientes de pago ("Deudor").\n\n'
        '3. REGISTRO Y SEGURIDAD DE LA CUENTA\n'
        'a) Para acceder a la plataforma, cada alumno debe verificar su correo institucional o personal y completar su perfil con datos verídicos (nombre completo, número de celular e inasistencias).\n'
        'b) El acceso es personal e intransferible. Cada usuario es responsable de mantener la seguridad de sus credenciales y de notificar inmediatamente cualquier uso no autorizado.\n\n'
        '4. PRIVACIDAD Y SEGURIDAD DE DATOS (DATA SAFETY)\n'
        'De acuerdo con las normativas de protección de datos y las directrices de Google Play:\n'
        'a) Recopilación Exclusiva: La información de carácter personal (nombre completo, correo electrónico, número de celular, dirección, edad y sexo) e información financiera (historial de aportaciones y pagos) recopilada por la aplicación se utiliza única y exclusivamente para el funcionamiento operativo, administración interna, envío de notificaciones y transparencia de cuentas del salón.\n'
        'b) Cifrado y Seguridad: Toda la información de usuario se transmite de forma cifrada bajo protocolos seguros HTTPS en tránsito y se almacena de forma privada.\n'
        'c) No compartición: Bajo ninguna circunstancia sus datos personales serán vendidos, compartidos o transferidos a terceras empresas o anunciantes comerciales.\n'
        'd) Eliminación de Datos: El usuario conserva el derecho de solicitar la eliminación definitiva de su cuenta y sus datos personales enviando una solicitud a la administración.\n\n'
        '5. SANCIONES, MULTAS Y EXONERACIONES\n'
        'a) De acuerdo a las políticas internas establecidas democráticamente por el salón de clases, se registrarán inasistencias y se computarán multas o cargos correspondientes a aquellos alumnos que no asistan o no colaboren con las actividades programadas.\n'
        'b) Cualquier solicitud de exoneración de pagos deberá ser presentada formalmente ante el Administrador de Tesorería, quien evaluará e ingresará la exoneración en el sistema de acuerdo a las directrices de la sección.\n\n'
        '6. RESPONSABILIDAD DE LOS ADMINISTRADORES\n'
        'Los administradores asignados al salón de clases son responsables del registro fiel, oportuno y documentado de cada ingreso de dinero, gasto y corte de caja. Todo movimiento sospechoso o erróneo será registrado en el sistema de auditoría integral y podrá ser objeto de revisión inmediata.\n\n'
        '7. ACEPTACIÓN GENERAL\n'
        'Al marcar la casilla de aceptación y presionar el botón "Aceptar y Entrar", confirmas que has leído, entendido y aceptado todos los puntos descritos en este acuerdo. Si no estás de acuerdo con estos términos, deberás presionar "Rechazar", lo cual impedirá tu acceso al sistema.';
  }
}
