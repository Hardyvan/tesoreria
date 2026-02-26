import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServicioNotificaciones {
  static final ServicioNotificaciones _instancia = ServicioNotificaciones._interno();
  factory ServicioNotificaciones() => _instancia;
  ServicioNotificaciones._interno();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Inicialización
  Future<void> inicializar() async {
    // 1. Configurar Zona Horaria para Recordatorios
    tz.initializeTimeZones();

    try {
      // 2. Configurar Notificaciones Locales (Icono de la app)
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('⚠️ Error iniciando Notificaciones Locales: $e');
    }

    try {
      // 3. Permisos FCM (iOS requiere explícito, Android 13+ también)
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Suscribirse al canal "general" para recibir pagos de todos
      await _fcm.subscribeToTopic('general');

      // 5. Escuchar mensajes en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _mostrarNotificacionLocal(message);
      });
      
      debugPrint('✅ FCM Inicializado correctamente.');
    } catch (e) {
      debugPrint('⚠️ Advertencia FCM (Puede deberse al Emulador/Red): $e');
    }
  }

  // --- PARTE A: NOTIFICACIONES GLOBALES (PAGOS) ---
  
  // Mostrar notificación visual cuando la app está abierta
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
            'canal_pagos',
            'Pagos Recibidos',
            channelDescription: 'Notificaciones sobre pagos realizados',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFF003366),
          ),
        ),
      );
    }
  }

  // Enviar PUSH a todos (Llamado por el Admin al registrar pago)
  Future<void> enviarNotificacionGlobalPago(String nombreAlumno, double monto) async {
    final serverKey = dotenv.env['FCM_SERVER_KEY'];
    
    if (serverKey == null || serverKey.isEmpty) {
      debugPrint('⚠️ FALTAN CREDENCIALES: Agrega FCM_SERVER_KEY en tu .env');
      return;
    }

    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(
          <String, dynamic>{
            'to': '/topics/general', // Envía a todos los suscritos
            'notification': <String, dynamic>{
              'title': '💰 Nuevo Pago Recibido',
              'body': '$nombreAlumno ha pagado S/ ${monto.toStringAsFixed(2)}',
              'sound': 'default'
            },
            'data': <String, dynamic>{
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'tipo': 'pago'
            },
          },
        ),
      );
      debugPrint('✅ Notificación enviada a todos.');
    } catch (e) {
      debugPrint('❌ Error enviando notificación: $e');
    }
  }

  // --- PARTE B: RECORDATORIOS LOCALES (DEUDAS) ---

  // Programar recordatorio diario a las 9:00 AM si debe dinero
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
    
    debugPrint('✅ Recordatorio diario programado para las 9:00 AM.');
  }

  Future<void> cancelarRecordatorios() async {
    await _localNotifications.cancel(id: 0);
    debugPrint('✅ Recordatorio cancelado (Deuda saldada).');
  }

  tz.TZDateTime _proximaInstancia(int hora) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hora);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
