import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_dormitorios/services/auth_service.dart';
import 'package:gestion_dormitorios/providers/user_provider.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/home_screen.dart';
import 'package:gestion_dormitorios/Administrador/Preceptor/screens/dashboard_preceptor_screen.dart';
import 'package:gestion_dormitorios/Administrador/Monitor/screens/dashboard_monitor_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/registro_screen.dart';
import 'package:gestion_dormitorios/recuperar_password_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController matriculaController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true; 

  Future<void> _login() async {
    final usuarioID = matriculaController.text.trim(); 
    final password = passwordController.text.trim();

    if (usuarioID.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa usuario y contraseña')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final response = await _authService.login(usuarioID, password);

      if (response['success'] == true) {
        final userData = response['data'] as Map<String, dynamic>; 
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        userProvider.setUser(userData);
        
        try {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _authService.updateFCMToken(usuarioID, fcmToken);
          }
        } catch (fcmError) {
          debugPrint("Error obteniendo FCM Token: $fcmError");
        }
        
        final rol = userProvider.idRol; 
        
        if (!mounted) return; 

        if (rol == 1) { // Preceptor
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPreceptorScreen()));
        } else if (rol == 2) { // Monitor
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardMonitorScreen()));
        } else if (rol == 3) { // Estudiante
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        } 

      } else {
        if (!mounted) return;

        // 1. Primero extraemos el mensaje que viene del servicio
        String rawMessage = response['message'] ?? 'Credenciales incorrectas';
        
        // 2. Definimos valores por defecto (Naranja para credenciales)
        String finalMessage = rawMessage;
        Color snackColor = Colors.orange;

        // 3. Si el error es de red, cambiamos el mensaje y el color a ROJO
        if (rawMessage.toLowerCase().contains('conexión') || 
            rawMessage.toLowerCase().contains('timeout') || 
            rawMessage.toLowerCase().contains('connect')) {
          finalMessage = 'Sin conexión al servidor. Revisa tu internet.';
          snackColor = Colors.red;
        }

        // 4. USAMOS LAS VARIABLES finalMessage y snackColor AQUÍ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalMessage), 
            backgroundColor: snackColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Este bloque captura errores de código o fallos críticos
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'), 
          backgroundColor: Colors.red
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea( 
        child: Center( 
          child: SingleChildScrollView( 
            padding: const EdgeInsets.symmetric(horizontal: 24.0), 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Image.asset('assets/logoulv.png', height: 100, color: isDark ? Colors.white : null),
                const SizedBox(height: 16),
                Text('DORMITORIOS ULV',
                  textAlign: TextAlign.center, // Centramos el texto
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant, 
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                      )
                    ]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Text('Iniciar sesión', 
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: matriculaController, 
                        hint: 'Usuario (Matrícula/Clave)', 
                        icon: Icons.person_outline, 
                        isDark: isDark
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: passwordController, 
                        hint: 'Contraseña', 
                        icon: Icons.lock_outline, 
                        isPassword: _obscurePassword,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                     // ... (Después del TextField de contraseña)
                      const SizedBox(height: 24), // Espacio directo al botón

                      // 1. EL BOTÓN PRINCIPAL (ACCEDER)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary, 
                              foregroundColor: theme.colorScheme.onPrimary, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) 
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? SizedBox( 
                                  height: 24, 
                                  width: 24, 
                                  child: CircularProgressIndicator(
                                    color: theme.colorScheme.onPrimary, 
                                    strokeWidth: 3
                                  )
                                )
                              : const Text('ACCEDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),

                      const SizedBox(height: 16), // Espacio entre botón y enlaces

                      // 2. RECUPERAR CONTRASEÑA (Aquí lo movimos)
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RecuperarPasswordScreen()));
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          // Usamos un color un poco más suave para que no compita con el botón principal
                          foregroundColor: Colors.grey[700], 
                        ),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontWeight: FontWeight.w500, // Un poco menos grueso que el de registro
                            decoration: TextDecoration.underline, // Subrayado opcional para indicar enlace
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8), 

                      // 3. REGISTRO (¿Eres nuevo?)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿Eres nuevo? ',
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const RegistroScreen()),
                              );
                            },
                            child: Text(
                              'Regístrate aquí',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                // decoration: TextDecoration.underline, // Opcional, se ve bien sin él si es bold
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                //const SizedBox(height: 40), // Menos espacio inferior si está centrado
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    Widget? suffixIcon, 
  }) {
    final theme = Theme.of(context);
    return TextFormField( 
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color), 
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text,
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next, 
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7)),
        suffixIcon: suffixIcon, 
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.15) : Colors.grey.shade200, 
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, 
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.grey.shade400.withOpacity(0.5)), // Borde sutil cuando está habilitado
        ),
         focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: theme.colorScheme.primary, width: 2), // Borde resaltado al enfocar
        ),
      ),
    );
  }
}
