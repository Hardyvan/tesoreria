import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';
import '../myPagesBack/a_controlador_auth.dart';
import '../myMenu/b_rutas_app.dart';

class PantallaCompletarPerfil extends StatefulWidget {
  const PantallaCompletarPerfil({super.key});

  @override
  State<PantallaCompletarPerfil> createState() => _PantallaCompletarPerfilState();
}

class _PantallaCompletarPerfilState extends State<PantallaCompletarPerfil> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();
  
  String sexoSeleccionado = 'Masculino';
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    // Obtenemos los datos que ya tenemos (Nombre, Email) del Controlador
    final auth = Provider.of<ControladorAuth>(context);
    final user = auth.usuarioActual;

    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        title: const Text("Completar Perfil"),
        automaticallyImplyLeading: false, // No permitir volver atrás sin completar
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ColoresApp.textoOscuro,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DimensionesApp.paddingEstandar),
          child: TarjetaPremium(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Icon(Icons.security_update_good, size: 60, color: ColoresApp.primario),
                   const SizedBox(height: 16),
                   Text(
                    "¡Casi listo, ${user?.nombre ?? 'Usuario'}!",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Para continuar, necesitamos algunos datos adicionales para tu ficha de alumno.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30),

                  // Llenar Datos Faltantes
                  CampoTextoPersonalizado(
                    controller: celularCtrl,
                    label: "Celular",
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: direccionCtrl,
                    label: "Dirección (Opcional)",
                    prefixIcon: Icons.home,
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 2, // Menos espacio para la edad
                        child: CampoTextoPersonalizado(
                          controller: edadCtrl,
                          label: "Edad", // Etiqueta más corta
                          prefixIcon: Icons.cake,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3, // Más espacio para el texto "Masculino/Femenino"
                        child: DropdownButtonFormField<String>(
                          initialValue: sexoSeleccionado,
                          isExpanded: true, // Evita overflow interno en el dropdown
                          decoration: InputDecoration(
                            labelText: "Sexo",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.wc),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Masculino', child: Text('Masculino', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Femenino', child: Text('Femenino', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => sexoSeleccionado = val!),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_cargando)
                    const Center(child: CircularProgressIndicator())
                  else
                    BotonGradiente(
                      text: "Guardar Datos",
                      icon: Icons.save,
                      onPressed: _guardarDatos,
                    ),
                  
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                        auth.cerrarSesion();
                        Navigator.pop(context);
                    }, 
                    child: const Text("Cancelar y Salir", style: TextStyle(color: ColoresApp.error))
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate()) return;
    
    // VALIDACIÓN: Celular es lo único obligatorio
    if (celularCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El celular es obligatorio para continuar"))
      );
      return;
    }

    setState(() => _cargando = true);
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    final exito = await auth.completarPerfil(
      celular: celularCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(), // Opcional
      edad: int.tryParse(edadCtrl.text) ?? 0, // Opcional
      sexo: sexoSeleccionado,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (exito) {
      // Éxito -> Ir al Menu
      Navigator.pushReplacementNamed(context, RutasApp.menuPrincipal);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al guardar perfil. Intente nuevamente."), backgroundColor: ColoresApp.error),
      );
    }
  }
}
