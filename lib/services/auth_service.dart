import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gestion_dormitorios/config/api_config.dart';
import 'package:gestion_dormitorios/Estudiantes/models/institutional_user.dart';


class AuthService {
  // Rutas
  static const String _loginUrl = '${ApiConfig.baseUrl}/auth/login';
  static const String _registerUrl = '${ApiConfig.baseUrl}/auth/register';
  static const String _schoolApiBase = ApiConfig.ULVAPI;
  static const String _otpApiBase = ApiConfig.otpApiUrl;

// Credenciales para el servicio de OTP (Del PDF)
  final String _otpServiceUser = "irving.patricio@ulv.edu.mx";
  final String _otpServicePass = "irya0904";

  // 1. LOGIN
  Future<Map<String, dynamic>> login(String usuarioID, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuarioID': usuarioID, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Credenciales incorrectas'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

 // 2. CONSULTAR API PROFESOR
  Future<InstitutionalUser?> checkInstitutionalUser(String id) async {
    
    // --- INICIO CORRECCIÓN ---
    // 1. Detectamos si la base ya termina en '/' para no duplicarla
    String baseUrl = _schoolApiBase;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    // 2. Ahora sí concatenamos seguro: "base" + "/" + "id"
    final url = Uri.parse('$baseUrl/$id'); 
    // --- FIN CORRECCIÓN ---

    print("Consultando API Escuela: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return InstitutionalUser.fromJson(data);
      } else {
        print("API Escuela respondió error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error conectando a API Escuela: $e");
      return null;
    }
  }

  // 3. REGISTRAR EN TU BD CON DATOS COMPLETOS
  Future<Map<String, dynamic>> register({
    required String usuarioID, 
    required String password, 
    required int idRol,
    required String nombre,
    required String carrera,
    required String correo
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuarioID': usuarioID,
          'password': password,
          'idRol': idRol,
          'nombreCompleto': nombre, // Enviamos el nombre real
          'carrera': carrera,       // Enviamos la carrera
          'correo': correo          // Enviamos el correo
        }),
      ).timeout(const Duration(seconds: 10));
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }


// 4. CAMBIAR CONTRASEÑA (Reset)
  // 4. CAMBIAR CONTRASEÑA (Con depuración)
  Future<bool> resetPassword(String correo, String nuevaPassword) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/reset-password');
    print("Intentando conectar a: $url"); // Verificamos la URL
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'nuevaPassword': nuevaPassword
        }),
      );

      print("Estatus Respuesta: ${response.statusCode}"); // Verificamos el código (200, 404, 500?)
      print("Cuerpo Respuesta: '${response.body}'");    // Verificamos qué llega (¿Vacío? ¿HTML?)

      if (response.body.isEmpty) {
        print("ERROR CRÍTICO: El servidor respondió vacío.");
        return false;
      }

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print("Excepción en resetPassword: $e");
      return false;
    }
  }

// 5. Validar si tiene permiso ANTES de seguir
  Future<Map<String, dynamic>> checkAccess(String usuarioID, int idRol) async {
    try {
      final response = await http.post(
        // 👇 ESTA ES LA CORRECCIÓN CLAVE:
        Uri.parse('${ApiConfig.baseUrl}/auth/check-access'), 
        
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuarioID': usuarioID,
          'idRol': idRol
        }),
      );

      final body = jsonDecode(response.body);
      return body; 
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
  
//logica otp 
// A. Obtener Token del Servicio OTP
  Future <String?> _getOtpServiceToken() async{
    final url = Uri.parse('$_otpApiBase/user/login');
    try{
      final response = await http.post(
        url,
        headers: {'Content-Type' : 'application/json'},
        body: jsonEncode({
          "email" : _otpServiceUser,
          "password" : _otpServicePass
          }),
       );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
      return null;
    }catch (e) {
      print("Error obteniendo token OTP: $e");
      return null;
    }
  }
// B. Enviar el OTP al correo del alumno
  Future<bool> sendOtpToEmail(String targetEmail) async {
    print("Obteniendo token...");
    final token = await _getOtpServiceToken();
    
    if (token == null) {
      print("ERROR: No se pudo obtener el token.");
      return false;
    }

    final url = Uri.parse('$_otpApiBase/otp_app/');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // --- CORRECCIÓN FINAL: Usamos la cabecera específica ---
          'x-access-token': token  
        },
        body: jsonEncode({
          "email": targetEmail,
          "subject": "Código de Verificación - Hogar Varones",
          "message": "Tu código de verificación es:",
          "duration": 1
        }),
      );

      print("Respuesta Enviar OTP: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Error del servidor OTP: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Excepción enviando OTP: $e");
      return false;
    }
  }

  // C. Verificar si el código ingresado es correcto
  Future<bool> verifyOtpCode(String targetEmail, String code) async {
    final token = await _getOtpServiceToken(); 
    if (token == null) return false;

    final url = Uri.parse('$_otpApiBase/email_verification/verifyOTP');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // --- CORRECCIÓN FINAL: Usamos la cabecera específica ---
          'x-access-token': token
        },
        body: jsonEncode({
          "email": targetEmail,
          "otp": code
        }),
      );
      
      print("Respuesta Verificar OTP: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      }
      return false;
    } catch (e) {
      print("Error verificando OTP: $e");
      return false;
    }
  }

  // 6. ACTUALIZAR TOKEN FCM
Future<void> updateFCMToken(String usuarioID, String? token) async {
  if (token == null) return;
  final url = Uri.parse('${ApiConfig.baseUrl}/auth/update-token');
  try {
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuarioID': usuarioID, 'token': token}),
    );
    print("FCM Token sincronizado con éxito.");
  } catch (e) {
    print("Error sincronizando token: $e");
  }
}
}