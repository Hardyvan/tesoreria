import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ServicioAutenticacion {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get usuarioFirebaseActual => _auth.currentUser;

  Future<UserCredential> iniciarSesionConCorreo(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(), 
      password: password
    );
    return userCredential;
  }

  Future<UserCredential> crearUsuarioConCorreo(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _auth.setLanguageCode('es'); 
    return credential;
  }

  Future<void> enviarCorreoValidacion(User user) async {
    await user.sendEmailVerification();
  }

  Future<UserCredential?> iniciarSesionConGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> cerrarSesion() async {
    await _auth.signOut();
    try {
      await _googleSignIn.disconnect(); 
    } catch (e) {
      await _googleSignIn.signOut();
    }
  }

  Future<bool> purgarUsuarioEnNube(User user) async {
    try {
      await user.delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando fantasma auth: $e');
      return false;
    }
  }

  Future<Map<String, String?>> cargarPreferencias() async {
    final recordarFlag = await _storage.read(key: 'recordar_usuario');
    final emailGuardado = await _storage.read(key: 'email_guardado');
    final passwordGuardado = await _storage.read(key: 'password_guardado');

    return {
      'recordar_usuario': recordarFlag,
      'email_guardado': emailGuardado,
      'password_guardado': passwordGuardado
    };
  }

  Future<void> guardarPreferencias(String email, String password, bool recordar) async {
    if (recordar) {
      await _storage.write(key: 'recordar_usuario', value: 'true');
      await _storage.write(key: 'email_guardado', value: email);
      await _storage.write(key: 'password_guardado', value: password);
    } else {
      await _storage.delete(key: 'recordar_usuario');
      await _storage.delete(key: 'email_guardado');
      await _storage.delete(key: 'password_guardado');
    }
  }
}
