import 'dart:io'; // Para manejar archivos
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
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
  String _passwordGuardado = '';

  // Instancia de almacenamiento seguro (AES encryption)
  final _storage = const FlutterSecureStorage();

  Usuario? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  bool get esAdmin => _usuarioActual?.rol == 'Admin' || _usuarioActual?.rol == 'SuperAdmin';
  // Getters para UI
  bool get recordarUsuario => _recordarUsuario;
  String get emailGuardado => _emailGuardado;
  String get passwordGuardado => _passwordGuardado;

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
      String nombreArchivo = 'fotos_perfil/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 2. Referencia
      final ref = FirebaseStorage.instance.ref().child(nombreArchivo);
      
      // 3. Subir
      await ref.putFile(imagen);
      
      // 4. Obtener URL
      final url = await ref.getDownloadURL();
      return url;
      
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
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
        debugPrint('Sesión encontrada: ${user.email}');
        
        // B. Revalidar contra MySQL (Para traer rol y datos frescos)
        final error = await _sincronizarUsuario(user);
        
        if (error == null || error == 'UsuarioIncompleto') {
           // Éxito o Parcialmente Éxito (dejar pasar a completar perfil)
           return true; 
        }
      }
      
      // Si no hay sesión, cargamos preferencias locales (Email recordado)
      await cargarPreferencias();

    } catch (e) {
      debugPrint('Error verificando sesión: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
    return false;
  }
  
  // ---------------------------------------------------------------------------
  // PREFERENCIAS (Flutter Secure Storage - Encriptado)
  // ---------------------------------------------------------------------------
  Future<void> cargarPreferencias() async {
    try {
      String? recordarFlag = await _storage.read(key: 'recordar_usuario');
      _recordarUsuario = recordarFlag == 'true';
      _emailGuardado = await _storage.read(key: 'email_guardado') ?? '';
      _passwordGuardado = await _storage.read(key: 'password_guardado') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando prefs seguras: $e');
    }
  }

  Future<void> guardarPreferencias(String email, String password, bool recordar) async {
    try {
      if (recordar) {
        await _storage.write(key: 'recordar_usuario', value: 'true');
        await _storage.write(key: 'email_guardado', value: email);
        await _storage.write(key: 'password_guardado', value: password);
      } else {
        await _storage.delete(key: 'recordar_usuario');
        await _storage.delete(key: 'email_guardado');
        await _storage.delete(key: 'password_guardado');
      }
      _recordarUsuario = recordar;
      _emailGuardado = email;
      _passwordGuardado = recordar ? password : '';
    } catch (e) {
      debugPrint('Error guardando prefs seguras: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 1. INICIO DE SESIÃ“N INTEGRADO (Manual: Admin, Test o Firebase)
  // ---------------------------------------------------------------------------
  Future<String?> iniciarSesion(String usuario, String password) async {
    _cargando = true;
    notifyListeners();

    try {
      // A. CREDENCIALES HARDCODED (Legacy/Admin)
      final userLower = usuario.trim().toLowerCase();
      if ((userLower == 'ivanadmin' || usuario == '999999999') && password == 'logan1992') {
        _usuarioActual = Usuario(id: 1, nombre: 'Administrador', celular: '999999999', email: 'admin@insoft.pe', fotoUrl: '', rol: 'Admin');
        return null;
      } else if (usuario == '123456789') {
         _usuarioActual = Usuario(id: 2, nombre: 'Alumno Test', celular: usuario, email: 'alumno@test.com', fotoUrl: '', rol: 'Alumno');
        return null; 
      }
      
      // B. AUTENTICACIÃ“N FIREBASE (Real para Alumnos)
      // Nota: Input 'usuario' se asume que es el email. 
      // Si el usuario ingresa celular, no funcionarÃ¡ con Firebase Auth directo (requiere mapeo),
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
             return 'Debes validar tu correo antes de ingresar. Revisa tu bandeja.';
           }

           return await _sincronizarUsuario(userCredential.user!);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-email') {
           return 'Usuario o contraseÃ±a incorrectos.';
        }
        return 'Error de acceso: ${e.message}';
      }

      return 'Credenciales incorrectas.';

    } catch (e) {
      debugPrint('Error en login manual: $e');
      return 'Error interno: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. INICIO DE SESIÃ“N CON GOOGLE
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
        return 'Inicio de sesiÃ³n cancelado por el usuario.';
      }

      // B. OBTENER CREDENCIALES
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // C. INICIAR SESIÃ“N EN FIREBASE
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // D. CONECTAR CON MYSQL (LÃ³gica de Negocio)
        // Validar usuario en MySQL y propagar error si falla
        return await _sincronizarUsuario(user);
      }
      
      return 'No se pudo obtener la informaciÃ³n del usuario de Google.';

    } on FirebaseAuthException catch (e) {
      debugPrint('Error Firebase Auth: ${e.code} - ${e.message}');
      return 'Error de Firebase: ${e.message}';
    } catch (e) {
      debugPrint('Error Google Auth: $e');
      return 'Error inesperado al iniciar con Google: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // SincronizaciÃ³n UID/Email
  Future<String?> _sincronizarUsuario(User firebaseUser) async {
    final db = BaseDatosRemota();
    try {
      final conn = await db.obtenerConexion();
      final String email = firebaseUser.email ?? '';
      final String uid = firebaseUser.uid;
      final String nombre = firebaseUser.displayName ?? 'Usuario';
      final String foto = firebaseUser.photoURL ?? '';

      // 1. BUSCAR POR UID
      var results = await conn.query(
        'SELECT id, uid, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM DSI_salon_usuarios WHERE uid = ?', 
        [uid]
      );

      // 2. SI NO EXISTE POR UID, BUSCAR POR EMAIL (Legacy Link)
      if (results.isEmpty && email.isNotEmpty) {
        results = await conn.query(
          'SELECT id, uid, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado FROM DSI_salon_usuarios WHERE email = ?', 
          [email]
        );
        
        // Si lo encontramos por email pero no tenÃ­a UID, ACTUALIZAMOS SU UID
        if (results.isNotEmpty) {
          final idLegacy = results.first['id'];
          await conn.query('UPDATE DSI_salon_usuarios SET uid = ? WHERE id = ?', [uid, idLegacy]);
          // (Opcional) Actualizar foto si viene de Google y no tenÃ­a
          if (foto.isNotEmpty) {
             await conn.query('UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ? AND (foto_url IS NULL OR foto_url = "")', [foto, idLegacy]);
          }
        }
      }

      if (results.isNotEmpty) {
        // A. EXISTE (Ya sea por UID o por Email vinculado)
        final fila = results.first;
        final direccion = _convertirAString(fila['direccion']);
        final celular = _convertirAString(fila['celular']);
        final estado = _convertirAString(fila['estado'] ?? 'activo');
        final uidDb = _convertirAString(fila['uid']);

        if (estado == 'inactivo') {
          return 'Tu cuenta ha sido bloqueada. Contacta al administrador.';
        }

        _usuarioActual = Usuario(
          id: fila['id'],
          uid: uidDb.isEmpty ? uid : uidDb, // Asegurar tener el UID en memoria
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
        
        // Si falta CELULAR, pedimos completar perfil. DIRECCIÃ“N YA ES OPCIONAL.
        if (celular.isEmpty) {
           return 'UsuarioIncompleto'; 
        }
        
        return null; // Ã‰xito total
      
      } else {
        // B. NO EXISTE (Usuario Nuevo TOTAL)
        // Insertamos con UID
        final resultInsert = await conn.query(
          'INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
          [uid, nombre, email, '', '', 0, '', foto, 'Alumno']
        );

        _usuarioActual = Usuario(
          id: resultInsert.insertId!, 
          uid: uid,
          nombre: nombre,
          celular: '',
          email: email,
          fotoUrl: foto,
          rol: 'Alumno',
        );
        return 'UsuarioNuevo'; 
      }
    } catch (e) {
      debugPrint('Error SQL Fase 1: $e');
      return 'Error DB: $e';
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

      if (credential.user == null) return 'Error creando usuario en Firebase.';

      // 2. CONFIGURAR IDIOMA Y ENVIAR EMAIL DE VERIFICACIÃ“N
      await FirebaseAuth.instance.setLanguageCode('es'); // Forzar EspaÃ±ol
      await credential.user!.sendEmailVerification();

      // 3. Guardar en MySQL
      final db = BaseDatosRemota();
      final conn = await db.obtenerConexion();
      
      await conn.query(
        'INSERT INTO DSI_salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
        [nombre, email, celular, direccion, edad, sexo, '', 'Alumno']
      );

      // (Nota: No seteamos _usuarioActual si queremos forzar el login despuÃ©s de verificar)
      
      return 'VERIFICACION_ENVIADA'; 

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // INTENTO DE RECUPERACIÃ“N (Para usuarios borrados de SQL pero vivos en Firebase)
        try {
          final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, 
            password: password
          );
          
          if (userCredential.user != null) {
            final db = BaseDatosRemota();
            final conn = await db.obtenerConexion();
            var results = await conn.query('SELECT id FROM DSI_salon_usuarios WHERE email = ?', [email]);
            
            if (results.isEmpty) {
               // RE-CREAR USER ORPHAN
               final resultInsert = await conn.query(
                'INSERT INTO DSI_salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
                [nombre, email, celular, direccion, edad, sexo, '', 'Alumno']
              );

              // Si re-creamos, verificamos validaciÃ³n
              if (!userCredential.user!.emailVerified) {
                  await userCredential.user!.sendEmailVerification();
                  return 'VERIFICACION_ENVIADA'; // Recuperado pero no validado
              }
              
              // SI YA ESTÃ VALIDADO, LO DEJAMOS PASAR
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
              return null; // Ã‰xito total (Recuperado y Validado)
            }
          }
        } catch (loginError) {
          // Fallo recuperaciÃ³n
        }

        return 'Este correo ya estÃ¡ registrado. Si ya lo validaste, inicia sesiÃ³n.';
      }
      return 'Error Firebase: ${e.message}';
    } catch (e) {
      return 'Error interno: $e';
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
          'INSERT INTO DSI_salon_usuarios (nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
          [_usuarioActual!.nombre, _usuarioActual!.email, celular, direccion, edad, sexo, _usuarioActual!.fotoUrl, 'Alumno']
        );
         _usuarioActual = _usuarioActual!.copyWith(id: resultInsert.insertId);
      } else {
        // CASO 2: Usuario Existente pero incompleto (UPDATE)
        await conn.query(
          'UPDATE DSI_salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?',
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
      debugPrint('Error al completar perfil: $e');
      return false;
    }
  }
  
  // Helper para manejar tipos de datos (Blob vs String)
  String _convertirAString(dynamic valor) {
    if (valor == null) return '';
    if (valor is String) return valor;
    // Si viene como Blob (Instance of Blob), forzamos su conversiÃ³n
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
          'UPDATE DSI_salon_usuarios SET celular = ? WHERE id = ?',
          [nuevoCelular, _usuarioActual!.id]
        );

        // Si tuvo Ã©xito, marcamos como sincronizado en local
        await BaseDatosLocal.instance.marcarSincronizado(_usuarioActual!.id);
        debugPrint('Celular actualizado en Nube âœ…');
        
      } catch (e) {
        debugPrint('Sin internet: Cambio guardado localmente para subir despuÃ©s â³');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error actualizando celular local: $e');
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
          'UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ?',
          [nuevaUrl, _usuarioActual!.id]
        );

        await BaseDatosLocal.instance.marcarSincronizado(_usuarioActual!.id);
        debugPrint('Foto actualizada en Nube âœ…');
        
      } catch (e) {
        debugPrint('Sin internet: Foto guardada localmente para subir despuÃ©s â³');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error actualizando foto: $e');
      return false;
    }
  }



  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    await FirebaseAuth.instance.signOut();
    // Usamos disconnect() en lugar de signOut() para que la prÃ³xima vez 
    // Google VUELVA A PREGUNTAR quÃ© cuenta usar (Account Picker).
    try {
      await GoogleSignIn().disconnect(); 
    } catch (e) {
      // Si no estaba logueado o falla, intentamos signOut normal por si acaso
      await GoogleSignIn().signOut();
    }
    notifyListeners();
  }
}
