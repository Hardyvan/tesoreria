import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../myPagesTema/a_tema_app.dart';
import '../myPagesTema/b_componentes_globales.dart';
import '../myPagesBack/a_controlador_auth.dart';
import '../myMenu/b_rutas_app.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final nombreCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final celularCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final edadCtrl = TextEditingController();
  
  String sexoSeleccionado = 'Masculino';
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        title: const Text("Crear Cuenta"),
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
                   Text(
                    "Registro Completo",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ColoresApp.primario,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // 1. Datos de Cuenta
                  CampoTextoPersonalizado(
                    controller: emailCtrl,
                    label: "Correo Electrónico",
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El correo es obligatorio';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                         return 'Formato de correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: passCtrl,
                    label: "Contraseña",
                    prefixIcon: Icons.lock,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const Divider(height: 30),

                  // 2. Datos Personales
                  CampoTextoPersonalizado(
                    controller: nombreCtrl,
                    label: "Nombre Completo",
                    prefixIcon: Icons.person,
                    validator: (v) => (v == null || v.isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: celularCtrl,
                    label: "Celular",
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El celular es obligatorio';
                      if (!RegExp(r'^\d+$').hasMatch(v)) return 'Solo números';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoTextoPersonalizado(
                    controller: direccionCtrl,
                    label: "Dirección (Opcional)",
                    prefixIcon: Icons.home,
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoTextoPersonalizado(
                          controller: edadCtrl,
                          label: "Edad (Op.)", // Texto más corto para evitar overflow
                          prefixIcon: Icons.cake,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sexoSeleccionado,
                          isExpanded: true, // Evita overflow en el dropdown
                          decoration: InputDecoration(
                            labelText: "Sexo",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.wc),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Masculino', child: Text('Masc.', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Femenino', child: Text('Fem.', overflow: TextOverflow.ellipsis)),
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
                      text: "Registrarme",
                      icon: Icons.check_circle,
                      onPressed: _registrarUsuario,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    // VALIDACIÓN: El formulario ya se encargó de verificar vacíos y formatos.

    setState(() => _cargando = true);
    final auth = Provider.of<ControladorAuth>(context, listen: false);

    // Si edad o dirección están vacíos, mandamos valores por defecto
    final error = await auth.registrarUsuarioCorreo(
      email: emailCtrl.text.trim(),
      password: passCtrl.text.trim(),
      nombre: nombreCtrl.text.trim(),
      celular: celularCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(), // Puede ir vacío
      edad: int.tryParse(edadCtrl.text) ?? 0, // Si falla o es vacío, va 0
      sexo: sexoSeleccionado,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error == null) {
      // Éxito Total (Quizás recuperación inmediata) -> Ir al Home
      Navigator.pushNamedAndRemoveUntil(context, RutasApp.menuPrincipal, (route) => false);
    
    } else if (error == "VERIFICACION_ENVIADA") {
      // Registro exitoso, pero requiere validación
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("¡Registro Exitoso!"),
          content: const Text("Te hemos enviado un correo de verificación.\n\nPor favor revisa tu bandeja y haz clic en el enlace antes de iniciar sesión."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Ir al Login para que ingrese sus datos
                Navigator.pushNamedAndRemoveUntil(context, '/inicio_sesion', (route) => false);
              },
              child: const Text("Entendido, ir al Login"),
            )
          ],
        ),
      );

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: ColoresApp.error),
      );
    }
  }
}
