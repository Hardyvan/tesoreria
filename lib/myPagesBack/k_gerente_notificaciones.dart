import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class GerenteNotificaciones {
  static final GerenteNotificaciones _instancia = GerenteNotificaciones._interno();
  factory GerenteNotificaciones() => _instancia;
  GerenteNotificaciones._interno();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // --- CONFIGURACIÓN FCM (ID DEL PROYECTO) ---
  static const String _projectId = 'insoft-tesoreria';
  static const List<String> _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  // ===========================================================================
  // PARTE A: INICIALIZACIÓN Y RECEPCIÓN LOCAL
  // ===========================================================================
  Future<void> inicializar() async {
    tz.initializeTimeZones();

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('⚠️ Error iniciando Notificaciones Locales: $e');
    }

    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await _fcm.subscribeToTopic('general');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _mostrarNotificacionLocal(message);
      });
      
      debugPrint('✅ FCM Inicializado correctamente en GerenteNotificaciones.');
    } catch (e) {
      debugPrint('⚠️ Advertencia FCM: $e');
    }
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'canal_tesoreria',
            'Tesoreria Alertas',
            channelDescription: 'Alertas generales y pagos',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFF003366),
          ),
        ),
      );
    }
  }

  // Recordatorios Locales
  Future<void> programarRecordatorioDeuda(double montoDeuda) async {
    if (montoDeuda <= 0) {
      await cancelarRecordatorios();
      return;
    }

    await _localNotifications.zonedSchedule(
      id: 0,
      title: '🔔 Recordatorio de Tesorería',
      body: 'Tienes un saldo pendiente de S/ ${montoDeuda.toStringAsFixed(2)}. ¡Evita moras!',
      scheduledDate: _proximaInstancia(9),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'canal_recordatorios',
          'Recordatorios de Deuda',
          channelDescription: 'Avisos diarios para estar al día',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('✅ Recordatorio programado para las 9:00 AM.');
  }

  Future<void> cancelarRecordatorios() async {
    await _localNotifications.cancel(id: 0);
    debugPrint('✅ Recordatorios cancelados.');
  }

  tz.TZDateTime _proximaInstancia(int hora) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hora);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // ===========================================================================
  // PARTE B: ENVÍO MASIVO / PUSH A OTROS (HTTP V1)
  // ===========================================================================
  static Future<String?> _obtenerAccessToken() async {
    try {
      final jsonString = await rootBundle.loadString('assets/firebase_admin.json');
      final credenciales = ServiceAccountCredentials.fromJson(jsonString);
      final client = await clientViaServiceAccount(credenciales, _scopes);
      
      final token = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      debugPrint('Error obteniendo Token FCM: $e');
      return null;
    }
  }

  static Future<bool> enviarPush({
    required String tokenDestino,
    required String titulo,
    required String cuerpo,
  }) async {
    try {
      final token = await _obtenerAccessToken();
      if (token == null) return false;

      final isTopic = tokenDestino.startsWith('/topics/');
      final String targetKey = isTopic ? 'topic' : 'token';
      final String targetValue = isTopic ? tokenDestino.replaceFirst('/topics/', '') : tokenDestino;

      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      final body = {
        'message': {
          targetKey: targetValue,
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
        debugPrint('✅ Push enviado a: $tokenDestino');
        return true;
      } else {
        debugPrint('❌ FCM Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error enviando push: $e');
      return false;
    }
  }
}
