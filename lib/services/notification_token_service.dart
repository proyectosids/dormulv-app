import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationTokenService {
  // ⚠️ Asegúrate de usar TU IP correcta aquí
  static const String baseUrl = 'http://172.19.43.105:5000/api'; 

  static Future<void> registerToken(String matricula) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Pedir permisos (Obligatorio para Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Obtener el Token
      String? token = await messaging.getToken();

      if (token != null) {
        print("📲 Token del dispositivo: $token");
        
        // 3. Enviar al Backend
        await _enviarTokenAlBackend(matricula, token);
      }
    } else {
      print('❌ Permiso de notificaciones denegado');
    }
  }

  static Future<void> _enviarTokenAlBackend(String matricula, String token) async {
    final url = Uri.parse('$baseUrl/auth/update-token');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'matricula': matricula,
          'fcmToken': token,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Token guardado en SQL Server correctamente");
      } else {
        print("⚠️ Error guardando token en BD: ${response.body}");
      }
    } catch (e) {
      print("❌ Error de conexión al guardar token: $e");
    }
  }
}