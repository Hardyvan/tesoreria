import 'dart:convert';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:googleapis_auth/auth_io.dart'; // Para ServiceAccountCredentials
import 'package:http/http.dart' as http;

class ServicioNotificaciones {
  // ID del Proyecto en Firebase
  static const String _projectId = 'insoft-tesoreria';
  
  // Alcance para Cloud Messaging
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  // 1. Obtener Access Token (OAuth 2.0)
  static Future<String?> _obtenerAccessToken() async {
    try {
      // Cargamos el JSON de la Service Account desde Assets
      final jsonString = await rootBundle.loadString('assets/firebase_admin.json');
      final credenciales = ServiceAccountCredentials.fromJson(jsonString);

      // Obtenemos el cliente autenticado
      final client = await clientViaServiceAccount(credenciales, _scopes);
      
      // Extraemos el token (el cliente lo maneja internamente, pero aquí lo exponemos para el Header)
      final accessCredentials = client.credentials;
      client.close(); // Cerramos el cliente, solo queríamos el token temporal
      
      return accessCredentials.accessToken.data;
    } catch (e) {
      debugPrint('Error obteniendo Access Token: $e');
      return null;
    }
  }

  // 2. Enviar Push (HTTP v1)
  static Future<bool> enviarPush({
    required String tokenDestino,
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      final token = await _obtenerAccessToken();
      if (token == null) return false;

      final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      final body = {
        'message': {
          'token': tokenDestino,
          'notification': {
            'title': titulo,
            'body': cuerpo,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'status': 'done'
          }
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notificación enviada a: $tokenDestino');
        return true;
      } else {
        debugPrint('❌ Error FCM (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error enviando push: $e');
      return false;
    }
  }
}
