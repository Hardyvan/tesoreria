import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../myPagesBack/b_controlador_finanzas.dart';
import '../../myPagesBack/a_controlador_auth.dart';


class EditarPago extends StatefulWidget {
  final Map<String, dynamic> pago; // {id, descripcion, monto, fecha, ...}

  const EditarPago({super.key, required this.pago});

  @override
  State<EditarPago> createState() => _EditarPagoState();
}

class _EditarPagoState extends State<EditarPago> {
  late TextEditingController _montoCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: widget.pago['monto'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Concepto: ${widget.pago['descripcion']}", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nuevo Monto',
              border: OutlineInputBorder(),
              prefixText: 'S/ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardarCambios,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          child: _guardando 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _guardarCambios() async {
    final nuevoMonto = double.tryParse(_montoCtrl.text);
    if (nuevoMonto == null || nuevoMonto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser válido y mayor a 0'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _guardando = true);

    final auth = context.read<ControladorAuth>();
    final finanzas = context.read<ControladorFinanzas>();

    // Usar usuarioActual! con seguridad porque Edit solo es para Admin logueado
    if (auth.usuarioActual == null) {
       Navigator.pop(context);
       return;
    }

    final exito = await finanzas.editarPago(widget.pago['id'], nuevoMonto, auth.usuarioActual!);

    if (mounted) {
      setState(() => _guardando = false);
      Navigator.pop(context, exito); // Retornar true si hubo éxito
    }
  }
}
