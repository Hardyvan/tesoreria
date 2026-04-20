import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

      final response = await http.post(
        Uri.parse(_gatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_secretKey',
        },
        body: jsonEncode(body),
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
}
