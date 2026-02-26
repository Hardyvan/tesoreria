import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../myPagesBack/a_controlador_auth.dart';
import '../myPagesBack/f_servicio_auditoria.dart';
import '../myPagesTema/a_tema.dart';

class AuditoriaAdmin extends StatefulWidget {
  const AuditoriaAdmin({super.key});

  @override
  State<AuditoriaAdmin> createState() => _AuditoriaAdminState();
}

class _AuditoriaAdminState extends State<AuditoriaAdmin> {
  late Future<List<Map<String, dynamic>>> _futureLogs;
  late Future<List<Map<String, dynamic>>> _futureCaja;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() {
    setState(() {
      _futureLogs = ServicioAuditoria().obtenerLogsAuditoria();
      _futureCaja = ServicioAuditoria().obtenerResumenCaja(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControladorAuth>(context);
    
    // PROTECCIÓN DE RUTA: Solo SuperAdmin
    if (auth.usuarioActual?.rol != 'SuperAdmin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Denegado')),
        body: const Center(child: Text('No tienes permisos para ver esta sección.')),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría (Super Admin)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN CORTE DE CAJA (NUEVO) ---
            const Text('Corte de Caja (Hoy)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureCaja,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) return const Text('No hay cobros registrados hoy.', style: TextStyle(color: Colors.grey));
                
                final caja = snapshot.data!;
                double totalDia = caja.fold(0, (sum, item) => sum + (item['total'] as double));

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...caja.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['admin'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text("S/ ${(item['total'] as double).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL RECAUDADO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('S/ ${totalDia.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            const Text('Historial de Acciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // --- LISTA DE LOGS ---
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureLogs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay registros de auditoría aún.'),
                    ),
                  );
                }

                final logs = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true, // Importante para ScrollView
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _TarjetaLog(log: log, dateFormat: dateFormat);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaLog extends StatelessWidget {
  final Map<String, dynamic> log;
  final DateFormat dateFormat;

  const _TarjetaLog({required this.log, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final accion = log['accion'];
    final admin = log['admin'];
    final fecha = log['fecha'];
    final dispositivo = log['dispositivo'];
    final detalle = log['detalle'];

    IconData icono;
    Color color;

    if (accion.contains('Pago')) {
      icono = Icons.payments;
      color = Colors.green;
    } else if (accion.contains('Gasto')) {
      icono = Icons.money_off;
      color = Colors.red;
    } else if (accion.contains('Usuario') || accion.contains('Rol')) {
      icono = Icons.manage_accounts;
      color = Colors.orange;
    } else {
      icono = Icons.info;
      color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ColoresApp.sombraSuave,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icono, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accion, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                  ),
                ),
                Text(
                  dateFormat.format(fecha),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  const TextSpan(text: 'Admin: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$admin '),
                  TextSpan(text: '($dispositivo)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detalle,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
