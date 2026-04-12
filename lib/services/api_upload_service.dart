import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ApiUploadService {
  // Patrón Singleton
  static final ApiUploadService _instance = ApiUploadService._internal();

  factory ApiUploadService() {
    return _instance;
  }

  ApiUploadService._internal();

  // Lee la URL estática desde .env (Seguridad y Mantenimiento)
  String get _uploadUrl => dotenv.env['API_UPLOAD_URL'] ?? 'https://api.insoft.com.pe/pollito/upload/api_tesoreria';
  
  // API KEY incrustada directamente (Por solicitud: Menos info en el .env)
  final String _secretKey = 'Insoft2026_SecureKey';

  /// Sube un archivo a la API Búnker
  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      if (!await file.exists()) {
        return {'ok': false, 'msj': 'El archivo seleccionado no existe localmente'};
      }

      // 1. PRIMER FILTRO EN CLIENTE: Validación Básica Rápida
      final ext = path.extension(file.path).toLowerCase();
      final extensionesPermitidas = ['.jpg', '.jpeg', '.png', '.webp', '.pdf', '.mp4', '.mp3', '.mpeg'];
      
      if (!extensionesPermitidas.contains(ext)) {
        return {'ok': false, 'msj': 'Tipo de archivo no permitido ($ext).'};
      }

      // Comprobar tamaño (14MB como límite preventivo en cliente)
      final limiteBytes = 14 * 1024 * 1024;
      final fileLength = await file.length();
      if (fileLength > limiteBytes) {
         return {'ok': false, 'msj': 'El archivo es demasiado grande (máximo recomendado: 14MB).'};
      }

      // 2. PREPARAR PETICIÓN MULTIPART
      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      
      // Añadir la Llave de Seguridad (API_KEY)
      request.headers['Authorization'] = 'Bearer $_secretKey';

      // Adjuntar el archivo físico
      request.files.add(await http.MultipartFile.fromPath('archivo', file.path));

      // 3. ENVIAR Y RECIBIR
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Debug: loguear siempre el status recibido para diagnóstico
      debugPrint('API Upload → HTTP ${response.statusCode}');
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'] ?? 'desconocida';
        debugPrint('⚠️ Redirect detectado hacia: $location — Revisar URL en .env');
        return {'ok': false, 'msj': 'Error de configuración del servidor (Redirect). Contacte al administrador.'};
      }

      // Tratamiento unificado de las respuestas del "Búnker"
      if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 500) {
        try {
            var data = jsonDecode(response.body);
            return data;
        } catch (e) {
            debugPrint('Respuesta RAW no capturada: ${response.body}');
            return {'ok': false, 'msj': 'Fallo al interpretar la respuesta del servidor.'};
        }
      } else if (response.statusCode == 401) {
         return {'ok': false, 'msj': 'Desautorizado. Las credenciales de subida fueron rechazadas.'};
      } else {
        return {'ok': false, 'msj': 'Error HTTP: Código ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error de conexión o I/O al subir: $e');
      return {'ok': false, 'msj': 'Pérdida de conexión o error de disco.'};
    }
  }
}
