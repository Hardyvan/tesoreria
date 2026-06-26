import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../myPagesBack/a_logica_inicio_sesion.dart';
import '../myPagesBack/k_servicio_auditoria.dart';
import '../myPagesTema/a_tema.dart';
import '../myPagesTema/b_ui_kit.dart';

class AjustesAdmin extends StatefulWidget {
  const AjustesAdmin({super.key});

  @override
  State<AjustesAdmin> createState() => _AjustesAdminState();
}

class _AjustesAdminState extends State<AjustesAdmin> {
  bool _sincronizando = false;

  Future<void> _ejecutarSincronizacionTotal() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = Provider.of<ControladorAuth>(context, listen: false);
    final theme = Theme.of(context);
    final insoftColors = theme.extension<InsoftColors>()!;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.secondary, size: 28),
            const SizedBox(width: 10),
            Text(
              '¿Sincronizar Todo?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Esta acción consultará todos los deudores, pagos, gastos, ingresos extra y fondo base de la base de datos MySQL y los subirá masivamente a Google Sheets.\n\nÚsala para corregir discrepancias de montos o fechas. El proceso puede tomar unos segundos.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.hintColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('INICIAR SINCRONIZACIÓN', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _sincronizando = true;
    });

    final servicio = ServicioAuditoria();
    final res = await servicio.sincronizarTodoGoogleSheets();

    if (!mounted) return;

    setState(() {
      _sincronizando = false;
    });

    if (res['ok'] == true) {
      // Registrar la acción de sincronización en la auditoría
      final adminNombre = auth.usuarioActual?.nombre ?? 'Administrador';
      await servicio.registrarAccion(
        accion: 'Sincronización Total',
        detalle: 'Sincronización masiva de base de datos con Google Sheets ejecutada por $adminNombre.',
        usuarioId: auth.usuarioActual?.id,
      );

      if (!mounted) return;

      unawaited(showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: insoftColors.estadoPagado ?? ColoresApp.exito, size: 28),
              const SizedBox(width: 10),
              Text(
                '¡Éxito!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            res['msj'] ?? 'Sincronización masiva con Google Sheets completada exitosamente.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ACEPTAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
            ),
          ],
        ),
      ));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['msj'] ?? 'Error al conectar con el Webhook de Google Sheets.'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    final esSuperAdmin = auth.usuarioActual?.rol == 'SuperAdmin';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final insoftColors = theme.extension<InsoftColors>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mantenimiento de Sistema',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CABECERA CON DISEÑO PREMIUM Y ACCENT BADGES
            TarjetaPremium(
              usaGradientePrimario: true,
              esBordeBrillante: true,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consola de Control',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Soporte técnico y mantenimiento en la nube',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildChipEstatus(
                        context: context,
                        icon: Icons.dns_rounded,
                        label: 'MySQL: ONLINE',
                        color: insoftColors.estadoPagado ?? Colors.greenAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildChipEstatus(
                        context: context,
                        icon: Icons.cloud_done_rounded,
                        label: 'Autosync: ACTIVO',
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. CONTENEDOR UNIFICADO DEL DASHBOARD
            TarjetaPremium(
              usaGradientePrimario: false,
              esBordeBrillante: true,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // --- SECCIÓN GOOGLE SHEETS ---
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (insoftColors.estadoPagado ?? Colors.green).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.table_chart_rounded, color: insoftColors.estadoPagado ?? Colors.green, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Google Sheets',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'AUTOMÁTICO',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Hoja de cálculo enlazada en tiempo real.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.sync_rounded, size: 16, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sincronización en tiempo real',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cada pago, gasto, ingreso extra o cambios de cuenta que registres en el celular se sincronizan automáticamente con Google Sheets. No necesitas presionar ningún botón en el uso diario.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_sincronizando) ...[
                          Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: theme.colorScheme.secondary),
                                const SizedBox(height: 12),
                                Text(
                                  'Sincronizando base de datos contable...',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: theme.colorScheme.secondary),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.secondary),
                              label: Text(
                                'FORZAR REESCRITURA COMPLETA',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              onPressed: _ejecutarSincronizacionTotal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // --- SECCIÓN SUPERADMIN DE SEGURIDAD (DENTRO DEL MISMO CONTENEDOR) ---
                  if (esSuperAdmin) ...[
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/auditoria'),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.security_rounded, color: theme.colorScheme.error, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auditoría del Sistema',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Log de transacciones y seguridad.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white60 : Colors.black38,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Accede al log histórico de todas las operaciones realizadas por cajeros, modificaciones de montos, y auditoría general de accesos.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. BADGES DE SEGURIDAD DEL PIE DE PÁGINA
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Zona horaria activa del servidor: Perú (America/Lima)',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Respaldo Encriptado con SSL de 256 bits',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET AUXILIAR PARA CHIPS DE ESTATUS
  Widget _buildChipEstatus({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
