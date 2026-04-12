import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'modelo_usuario.dart';
import 'l_servicio_autenticacion.dart';
import 'm_repositorio_usuarios.dart';
import '../services/api_upload_service.dart';

class ControladorAuth extends ChangeNotifier {
  final ServicioAutenticacion _authService = ServicioAutenticacion();
  final RepositorioUsuarios _repoUsuarios = RepositorioUsuarios();

  Usuario? _usuarioActual;
  bool _cargando = false;
  
  bool _recordarUsuario = false;
  String _emailGuardado = '';
  String _passwordGuardado = '';

  Usuario? get usuarioActual => _usuarioActual;
  bool get cargando => _cargando;
  bool get esAdmin => _usuarioActual?.rol == 'Admin' || _usuarioActual?.rol == 'SuperAdmin';
  
  bool get recordarUsuario => _recordarUsuario;
  String get emailGuardado => _emailGuardado;
  String get passwordGuardado => _passwordGuardado;

  // ---------------------------------------------------------------------------
  // VERIFICAR SESIÃ“N INICIAL Y RECORDAR
  // ---------------------------------------------------------------------------
  Future<bool> verificarSesion() async {
    _cargando = true;
    notifyListeners();

    try {
      final user = _authService.usuarioFirebaseActual;
      if (user != null) {
        final result = await _repoUsuarios.sincronizarUsuarioBD(
          user.uid, user.email ?? '', user.displayName ?? 'Usuario', user.photoURL ?? ''
        );
        
        if (result['error'] != null) {
           return false; // Bloqueado u otro error
        }

        _usuarioActual = result['usuario'];
        
        if (result['status'] == 'UsuarioIncompleto') return true; 
        if (result['status'] == 'UsuarioNuevo') return true; // También necesita completar perfil
        if (result['status'] == 'OK') return true;
      }
      
      await cargarPreferencias();

    } catch (e) {
      debugPrint('Error verificando sesión SRP: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> cargarPreferencias() async {
    final prefs = await _authService.cargarPreferencias();
    _recordarUsuario = prefs['recordar_usuario'] == 'true';
    _emailGuardado = prefs['email_guardado'] ?? '';
    _passwordGuardado = prefs['password_guardado'] ?? '';
    notifyListeners();
  }

  Future<void> guardarPreferencias(String email, String password, bool recordar) async {
    await _authService.guardarPreferencias(email, password, recordar);
    _recordarUsuario = recordar;
    _emailGuardado = email;
    _passwordGuardado = recordar ? password : '';
  }

  // ---------------------------------------------------------------------------
  // INICIO DE SESIÃ“N TRADICIONAL (Correo y ContraseÃ±a)
  // ---------------------------------------------------------------------------
  Future<String?> iniciarSesion(String correo, String password) async {
    _cargando = true;
    notifyListeners();

    try {
      final cred = await _authService.iniciarSesionConCorreo(correo, password);
      
      if (cred.user != null) {
        if (!cred.user!.emailVerified) {
          return 'Debes validar tu correo antes de ingresar. Revisa tu bandeja.';
        }

        final result = await _repoUsuarios.sincronizarUsuarioBD(
          cred.user!.uid, cred.user!.email ?? '', cred.user!.displayName ?? 'Usuario', cred.user!.photoURL ?? ''
        );

        if (result['error'] != null) return result['error'];
        _usuarioActual = result['usuario'];
        
        if (result['status'] == 'UsuarioIncompleto') return 'UsuarioIncompleto';
        return null; // OK
      }
      return 'Credenciales incorrectas.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') return 'Usuario o contraseÃ±a incorrectos.';
      return 'Error de acceso: ${e.message}';
    } catch (e) {
      return 'Error interno: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // INICIO DE SESION GOOGLE
  // ---------------------------------------------------------------------------
  Future<String?> ingresarConGoogle() async {
    _cargando = true;
    notifyListeners();

    try {
      final cred = await _authService.iniciarSesionConGoogle();
      if (cred == null) return 'Inicio de sesión cancelado por el usuario.';

      if (cred.user != null) {
        final result = await _repoUsuarios.sincronizarUsuarioBD(
          cred.user!.uid, cred.user!.email ?? '', cred.user!.displayName ?? 'Usuario', cred.user!.photoURL ?? ''
        );

        if (result['error'] != null) return result['error'];
        _usuarioActual = result['usuario'];
        
        // 'UsuarioNuevo' también necesita completar perfil (celular vacío)
        if (result['status'] == 'UsuarioIncompleto' || result['status'] == 'UsuarioNuevo') {
          return 'UsuarioIncompleto';
        }
        return null; // OK
      }
      return 'No se pudo obtener la información del usuario de Google.';
    } catch (e) {
      return 'Error al iniciar con Google: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRO CON CONTROL TRANSACCIONAL (SRP)
  // ---------------------------------------------------------------------------
  Future<String?> registrarUsuarioCorreo({
    required String email, required String password, required String nombre,
    required String celular, required String direccion, required int edad, required String sexo
  }) async {
    _cargando = true;
    notifyListeners();

    User? usuarioMecanismoTemporal;

    try {
      // 1. Fase Nube (CreaciÃ³n Firebase)
      final credential = await _authService.crearUsuarioConCorreo(email, password);
      if (credential.user == null) return 'Error creando cuenta auth.';
      usuarioMecanismoTemporal = credential.user;

      // 2. Fase Servidor SQL (AquÃ­ ocurre el riesgo de fantasmas)
      final errorInsertSQL = await _repoUsuarios.insertarUsuarioEnBD(
        nombre: nombre, email: email, celular: celular, 
        direccion: direccion, edad: edad, sexo: sexo
      );

      if (errorInsertSQL != null) {
        // ï¼¼(Âº_Âº)/ ROLLBACK ACTIVO ï¼¼(Âº_Âº)/
        await _authService.purgarUsuarioEnNube(usuarioMecanismoTemporal!);
        return errorInsertSQL; // Devuelve al UI el error sin crear un huÃ©rfano
      }

      // 3. Fase Verificación
      await _authService.enviarCorreoValidacion(credential.user!);
      return 'VERIFICACION_ENVIADA';

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return 'Este correo ya esta registrado. Inicia sesión.';
      return 'Error Auth: ${e.message}';
    } catch (e) {
      return 'Error crítico al registrar: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // UTILIDADES DEL PERFIL
  // ---------------------------------------------------------------------------
  Future<bool> completarPerfil({
    required String celular, required String direccion, required int edad, required String sexo
  }) async {
    if (_usuarioActual == null) return false;
    final userCompleto = await _repoUsuarios.guardarPerfilCompletado(_usuarioActual!, celular, direccion, edad, sexo);
    if (userCompleto != null) {
      _usuarioActual = userCompleto;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> actualizarCelular(String nuevoCelular) async {
    if (_usuarioActual == null) return false;
    final r = await _repoUsuarios.actualizarElementoUsuario(_usuarioActual!, celular: nuevoCelular);
    if (r != null) { _usuarioActual = r; notifyListeners(); return true; }
    return false;
  }

  Future<bool> actualizarFoto(String nuevaUrl) async {
    if (_usuarioActual == null) return false;
    final r = await _repoUsuarios.actualizarElementoUsuario(_usuarioActual!, fotoUrl: nuevaUrl);
    if (r != null) { _usuarioActual = r; notifyListeners(); return true; }
    return false;
  }

  Future<String?> subirImagenStorage(File imagen) async {
    _cargando = true;
    notifyListeners();
    
    // Llamada directa al API Bunker Bypasseando Firebase!
    final result = await ApiUploadService().uploadFile(imagen);
    
    _cargando = false;
    notifyListeners();
    
    if (result['ok']) {
       return result['url']; // URL exacta para guardar en local y BD MySQL
    } else {
       debugPrint("Fallo Bunker: ${result['msj']}");
       return null; 
    }
  }

  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    await _authService.cerrarSesion();
    notifyListeners();
  }
}
