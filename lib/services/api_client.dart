import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Ruta hacia el router central (refactorizado)
  String get _gatewayUrl => dotenv.env['API_GATEWAY_URL'] ?? 'https://api.insoft.com.pe/pollito/upload/api_tesoreria/index.php';
  
  final String _secretKey = 'Insoft2026_SecureKey';

  Future<Map<String, dynamic>> post(String accion, [Map<String, dynamic>? payload]) async {
    try {
      final Map<String, dynamic> body = payload ?? {};
      body['accion'] = accion;

      // Inyectar UID de Firebase automáticamente si hay sesión activa
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !body.containsKey('adminUid')) {
        body['adminUid'] = currentUser.uid;
      }

      // Inyectar nombre del dispositivo
      if (!body.containsKey('dispositivo')) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          if (defaultTargetPlatform == TargetPlatform.android) {
            final androidInfo = await deviceInfo.androidInfo;
            body['dispositivo'] = '${androidInfo.brand} ${androidInfo.model}';
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            final iosInfo = await deviceInfo.iosInfo;
            body['dispositivo'] = iosInfo.name;
          } else {
             body['dispositivo'] = 'Web/Desktop API';
          }
        } catch (_) {
          body['dispositivo'] = 'Flutter API';
        }
      }

      final response = await http.post(
        Uri.parse(_gatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_secretKey',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => http.Response('{"ok":false,"msj":"Tiempo de espera agotado"}', 408),
      );

      if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 500) {
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {'ok': false, 'msj': 'Autenticación API rechazada'};
      } else {
         return {'ok': false, 'msj': 'Error HTTP: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error ApiClient ($accion): $e');
      return {'ok': false, 'msj': 'Error de conexión con el servidor'};
    }
  }

  Future<Map<String, dynamic>> uploadImage(Uint8List bytes, String filename) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_gatewayUrl));
      request.headers['Authorization'] = 'Bearer $_secretKey';
      
      final multipartFile = http.MultipartFile.fromBytes(
        'archivo',
        bytes,
        filename: filename,
      );
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {'ok': false, 'msj': 'Error al subir archivo: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error ApiClient (uploadImage): $e');
      return {'ok': false, 'msj': 'Error de conexión con el servidor'};
    }
  }
}
