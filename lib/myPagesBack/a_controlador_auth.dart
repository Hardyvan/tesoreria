import 'dart:io'; // Para manejar archivos
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; // Storage
import 'modelo_usuario.dart';
import '../myPagesServer/b_base_datos_remota.dart'; 
import '../myPagesServer/c_base_datos_local.dart'; 

class ControladorAuth extends ChangeNotifier {
  Usuario? _usuarioActual;
  bool _cargando = false;
  
  // Variables para "Recordar Usuario"
  bool _recordarUsuario = false;
  String _emailGuardado = '';

  Usuario? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  bool get esAdmin => _usuarioActual?.rol == 'Admin';
  // Getters para UI
  bool get recordarUsuario => _recordarUsuario;
  String get emailGuardado => _emailGuardado;

  // ---------------------------------------------------------------------------
  // NUEVO: SUBIR IMAGEN A STORAGE
  // ---------------------------------------------------------------------------
  Future<String?> subirImagenStorage(File imagen) async {
    _cargando = true;
    notifyListeners();
    try {
      // 1. Nombre único (fotos_perfil/uid_timestamp.jpg)
      // Usamos el UID del usuario o 'anonimo' si es nuevo
      String uid = FirebaseAuth.instance.currentUser?.uid ?? 'nuevo_${DateTime.now().millisecondsSinceEpoch}';
      String nombreArchivo = "fotos_perfil/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      // 2. Referencia
      final ref = FirebaseStorage.instance.ref().child(nombreArchivo);
      
      // 3. Subir
      await ref.putFile(imagen);
      
      // 4. Obtener URL
      final url = await ref.getDownloadURL();
      return url;
      
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 0. VERIFICAR SESIÓN ACTIVA (Auto-Login al abrir app)
  // ---------------------------------------------------------------------------
  Future<bool> verificarSesion() async {
    _cargando = true;
    notifyListeners();

    try {
      // A. Verificar si hay usuario de Firebase persistido
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        debugPrint("Sesión encontrada: ${user.email}");
        
        // B. Revalidar contra MySQL (Para traer rol y datos frescos)
        final error = await _validarUsuarioEnMySQL(
          user.email!, 
          user.displayName ?? 'Usuario', 
          user.photoURL ?? ''
        );
        
        if (error == null || error == "UsuarioIncompleto") {
           // Éxito o Parcialmente Éxito (dejar pasar a completar perfil)
           return true; 
        }
      }
      
      // Si no hay sesión, cargamos preferencias locales (Email recordado)
      await cargarPreferencias();

    } catch (e) {
      debugPrint("Error verificando sesión: $e");
    } finally {
      _cargando = false;
      notifyListeners();
    }
    return false;
  }
  
  // ---------------------------------------------------------------------------
  // PREFERENCIAS (SharedPreferences)
  // ---------------------------------------------------------------------------
  Future<void> cargarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordarUsuario = prefs.getBool('recordar_usuario') ?? false;
      _emailGuardado = prefs.getString('email_guardado') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando prefs: $e");
    }
  }

  Future<void> guardarPreferencias(String email, bool recordar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (recordar) {
        await prefs.setBool('recordar_usuario', true);
        await prefs.setString('email_guardado', email);
      } else {
        await prefs.remove('recordar_usuario');
        await prefs.remove('email_guardado');
      }
      _recordarUsuario = recordar;
      _emailGuardado = email;
    } catch (e) {
      debugPrint("Error guardando prefs: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 1. INICIO DE SESIÓN INTEGRADO (Manual: Admin, Test o Firebase)
  // ---------------------------------------------------------------------------
  Future<String?> iniciarSesion(String usuario, String password) async {
    _cargando = true;
    notifyListeners();

    try {
      // A. CREDENCIALES HARDCODED (Legacy/Admin)
      final userLower = usuario.trim().toLowerCase();
      if ((userLower == 'admin' || usuario == '999999999') && password == 'admin123') {
        _usuarioActual = Usuario(id: 1, nombre: 'Administrador', celular: '999999999', email: 'admin@insoft.pe', fotoUrl: '', rol: 'Admin');
        return null;
      } else if (usuario == '123456789') {
         _usuarioActual = Usuario(id: 2, nombre: 'Alumno Test', celular: usuario, email: 'alumno@test.com', fotoUrl: '', rol: 'Alumno');
        return null; 
      }
      
      // B. AUTENTICACIÓN FIREBASE (Real para Alumnos)
      // Nota: Input 'usuario' se asume que es el email. 
      // Si el usuario ingresa celular, no funcionará con Firebase Auth directo (requiere mapeo),
      // pero por ahora asumimos que ingresa su CORREO.
      
      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: usuario.trim(), 
          password: password
        );

        if (userCredential.user != null) {
           // 1. Validar si el correo fue verificado (Solo para Email/Pass)
           // Los de Google suelen venir verificados por defecto, pero esto asegura calidad.
           if (!userCredential.user!.emailVerified) {
             return "Debes validar tu correo antes de ingresar. Revisa tu bandeja.";
           }

           return await _validarUsuarioEnMySQL(
             userCredential.user!.email!, 
             userCredential.user!.displayName ?? 'Usuario', 
             userCredential.user!.photoURL ?? ''
           );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-email') {
           return "Usuario o contraseña incorrectos.";
        }
        return "Error de acceso: ${e.message}";
      }

      return "Credenciales incorrectas.";

    } catch (e) {
      debugPrint('Error en login manual: $e');
      return "Error interno: $e";
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. INICIO DE SESIÓN CON GOOGLE
  // ---------------------------------------------------------------------------
  Future<String?> ingresarConGoogle() async {
    _cargando = true;
    notifyListeners();

    try {
      // A. INICIAR EL FLUJO DE GOOGLE
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        _cargando = false;
        notifyListeners();
        return "Inicio de sesión cancelado por el usuario.";
      }

      // B. OBTENER CREDENCIALES
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // C. INICIAR SESIÓN EN FIREBASE
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final String email = user.email ?? "";
        final String nombre = user.displayName ?? "Sin nombre";
        final String fotoUrl = user.photoURL ?? "";

        // D. CONECTAR CON MYSQL (Lógica de Negocio)
        // Validar usuario en MySQL y propagar error si falla
        return await _validarUsuarioEnMySQL(email, nombre, fotoUrl);
      }
      
      return "No se pudo obtener la información del usuario de Google.";

    } on FirebaseAuthException catch (e) {
      debugPrint("Error Firebase Auth: ${e.code} - ${e.message}");
      return "Error de Firebase: ${e.message}";
    } catch (e) {
      debugPrint("Error Google Auth: $e");
      return "Error inesperado al iniciar con Google: $e";
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // 126: _validarUsuarioEnMySQL
  Future<String?> _validarUsuarioEnMySQL(String email, String nombre, String foto) async {
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();

      // 1. BUSCAR SI EL USUARIO YA EXISTE
      var results = await conn.query(
        'SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM salon_usuarios WHERE email = ?', 
        [email]
      );

      if (results.isNotEmpty) {
        // A. EXISTE
        final fila = results.first;
        final direccion = _convertirAString(fila['direccion']);
        final celular = _convertirAString(fila['celular']);
        final estado = _convertirAString(fila['estado'] ?? 'activo');

        if (estado == 'inactivo') {
          return "Tu cuenta ha sido bloqueada. Contacta al administrador.";
        }

        _usuarioActual = Usuario(
          id: fila['id'],
          nombre: _convertirAString(fila['nombre']),
          celular: celular,
          email: _convertirAString(fila['email']),
          fotoUrl: _convertirAString(fila['foto_url']),
          rol: _convertirAString(fila['rol'] ?? 'Alumno'),
          direccion: direccion,
          edad: fila['edad'] ?? 0,
          sexo: _convertirAString(fila['sexo']),
          estado: estado,
        );
        
        // Si falta CELULAR, pedimos completar perfil. DIRECCIÓN YA ES OPCIONAL.
        if (celular.isEmpty) {
           return "UsuarioIncompleto"; 
        }
        
        return null; // Éxito total
      
      } else {
        // B. NO EXISTE (Usuario Nuevo)
        _usuarioActual = Usuario(
          id: 0, 
          nombre: nombre,
          celular: '',
          email: email,
          fotoUrl: foto,
          rol: 'Alumno',
        );
        return "UsuarioNuevo"; 
      }
    } catch (e) {
      // ... Error handling ...
      return "Error DB: $e";
    }
  }

  // 198: registrarUsuarioCorreo
  // ---------------------------------------------------------------------------
  // 4. REGISTRO COMPLETO (Correo) & COMPLETAR PERFIL (Google)
  // ---------------------------------------------------------------------------

  // A. Registrar Usuario Nuevo (Correo + Datos)
  Future<String?> registrarUsuarioCorreo({
    required String email, required String password,
    required String nombre, required String celular,
    required String direccion, required int edad, required String sexo
  }) async {
    _cargando = true;
    notifyListeners();

    try {
      // 1. Crear en Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return "Error creando usuario en Firebase.";

      // 2. CONFIGURAR IDIOMA Y ENVIAR EMAIL DE VERIFICACIÓN
      await FirebaseAuth.instance.setLanguageCode('es'); // Forzar Español
      await credential.user!.sendEmailVerification();

      // 3. Guardar en MySQL
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      await conn.query(
        'INSERT INTO salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
        [nombre, email, celular, direccion, edad, sexo, '', 'Alumno']
      );

      // (Nota: No seteamos _usuarioActual si queremos forzar el login después de verificar)
      
      return "VERIFICACION_ENVIADA"; 

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // INTENTO DE RECUPERACIÓN (Para usuarios borrados de SQL pero vivos en Firebase)
        try {
          final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, 
            password: password
          );
          
          if (userCredential.user != null) {
            final db = BaseDatosRemota();
            final conn = await db.obtenerConexion();
            var results = await conn.query('SELECT id FROM salon_usuarios WHERE email = ?', [email]);
            
            if (results.isEmpty) {
               // RE-CREAR USER ORPHAN
               final resultInsert = await conn.query(
                'INSERT INTO salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
                [nombre, email, celular, direccion, edad, sexo, '', 'Alumno']
              );

              // Si re-creamos, verificamos validación
              if (!userCredential.user!.emailVerified) {
                  await userCredential.user!.sendEmailVerification();
                  return "VERIFICACION_ENVIADA"; // Recuperado pero no validado
              }
              
              // SI YA ESTÁ VALIDADO, LO DEJAMOS PASAR
              _usuarioActual = Usuario(
                id: resultInsert.insertId!,
                nombre: nombre,
                celular: celular,
                email: email,
                fotoUrl: '',
                rol: 'Alumno',
                direccion: direccion,
                edad: edad,
                sexo: sexo
              );
              return null; // Éxito total (Recuperado y Validado)
            }
          }
        } catch (loginError) {
          // Fallo recuperación
        }

        return "Este correo ya está registrado. Si ya lo validaste, inicia sesión.";
      }
      return "Error Firebase: ${e.message}";
    } catch (e) {
      return "Error interno: $e";
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // B. Completar Perfil (Para usuarios de Google nuevos o incompletos)
  Future<bool> completarPerfil({
    required String celular, required String direccion, 
    required int edad, required String sexo
  }) async {
    if (_usuarioActual == null) return false;
    final db = BaseDatosRemota();

    try {
      final conn = await db.obtenerConexion();

      if (_usuarioActual!.id == 0) {
        // CASO 1: Usuario Nuevo de Google (INSERT)
        final resultInsert = await conn.query(
          'INSERT INTO salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
          [_usuarioActual!.nombre, _usuarioActual!.email, celular, direccion, edad, sexo, _usuarioActual!.fotoUrl, 'Alumno']
        );
         _usuarioActual = _usuarioActual!.copyWith(id: resultInsert.insertId);
      } else {
        // CASO 2: Usuario Existente pero incompleto (UPDATE)
        await conn.query(
          'UPDATE salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
          [celular, direccion, edad, sexo, _usuarioActual!.id]
        );
      }

      // Actualizar local
      _usuarioActual = _usuarioActual!.copyWith(
        celular: celular,
        direccion: direccion,
        edad: edad,
        sexo: sexo
      );
      
      notifyListeners();
      return true;

    } catch (e) {
      debugPrint("Error al completar perfil: $e");
      return false;
    }
  }
  
  // Helper para manejar tipos de datos (Blob vs String)
  String _convertirAString(dynamic valor) {
    if (valor == null) return '';
    if (valor is String) return valor;
    // Si viene como Blob (Instance of Blob), forzamos su conversión
    return valor.toString();
  }

  // ---------------------------------------------------------------------------
  // 5. ACTUALIZAR CELULAR (Offline First)
  // ---------------------------------------------------------------------------
  Future<bool> actualizarCelular(String nuevoCelular) async {
    if (_usuarioActual == null) return false;

    try {
      // 1. APLICAR CAMBIO LOCALMENTE (Siempre funciona)
      final usuarioActualizado = _usuarioActual!.copyWith(celular: nuevoCelular);
      
      // Guardar en SQLite (Marcado como NO sincronizado por defecto)
      // Nota: Necesitamos importar BaseDatosLocal
      await BaseDatosLocal.instance.insertarUsuario(usuarioActualizado, sincronizado: false);

      // Actualizar estado en memoria
      _usuarioActual = usuarioActualizado;
      notifyListeners();

      // 2. INTENTAR SINCRONIZAR A LA NUBE (Si hay internet)
      try {
        final db = BaseDatosRemota();
        final conn = await db.obtenerConexion();
        
        await conn.query(
          'UPDATE salon_usuarios SET celular = ? WHERE id = ?',
          [nuevoCelular, _usuarioActual!.id]
        );

        // Si tuvo éxito, marcamos como sincronizado en local
        await BaseDatosLocal.instance.marcarSincronizado(_usuarioActual!.id);
        debugPrint("Celular actualizado en Nube ✅");
        
      } catch (e) {
        debugPrint("Sin internet: Cambio guardado localmente para subir después ⏳");
      }
      
      return true;
    } catch (e) {
      debugPrint("Error actualizando celular local: $e");
      return false;
    }
  }

  // 6. ACTUALIZAR FOTO DE PERFIL
  Future<bool> actualizarFoto(String nuevaUrl) async {
    if (_usuarioActual == null) return false;

    try {
      // 1. APLICAR CAMBIO LOCALMENTE
      final usuarioActualizado = _usuarioActual!.copyWith(fotoUrl: nuevaUrl);
      
      // Guardar en SQLite
      await BaseDatosLocal.instance.insertarUsuario(usuarioActualizado, sincronizado: false);

      // Actualizar estado en memoria
      _usuarioActual = usuarioActualizado;
      notifyListeners();

      // 2. INTENTAR SINCRONIZAR A LA NUBE
      try {
        final db = BaseDatosRemota();
        final conn = await db.obtenerConexion();
        
        await conn.query(
          'UPDATE salon_usuarios SET foto_url = ? WHERE id = ?',
          [nuevaUrl, _usuarioActual!.id]
        );

        await BaseDatosLocal.instance.marcarSincronizado(_usuarioActual!.id);
        debugPrint("Foto actualizada en Nube ✅");
        
      } catch (e) {
        debugPrint("Sin internet: Foto guardada localmente para subir después ⏳");
      }
      
      return true;
    } catch (e) {
      debugPrint("Error actualizando foto: $e");
      return false;
    }
  }



  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    await FirebaseAuth.instance.signOut();
    // Usamos disconnect() en lugar de signOut() para que la próxima vez 
    // Google VUELVA A PREGUNTAR qué cuenta usar (Account Picker).
    try {
      await GoogleSignIn().disconnect(); 
    } catch (e) {
      // Si no estaba logueado o falla, intentamos signOut normal por si acaso
      await GoogleSignIn().signOut();
    }
    notifyListeners();
  }
}
