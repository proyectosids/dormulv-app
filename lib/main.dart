import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Importaciones del proyecto
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'login_screen.dart';
import 'Estudiantes/screens/home_screen.dart';
import 'Administrador/Preceptor/screens/dashboard_preceptor_screen.dart';
import 'Administrador/Monitor/screens/dashboard_monitor_screen.dart';

// --- CONFIGURACIÓN DE NOTIFICACIONES LOCALES ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // ID debe coincidir con el backend
  'High Importance Notifications',
  description: 'Este canal se usa para notificaciones importantes.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Manejador para notificaciones en segundo plano (App cerrada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurarse de que Firebase esté listo antes de procesar el mensaje en segundo plano
  await Firebase.initializeApp();
  print("Notificación en segundo plano recibida: ${message.messageId}");
}

void main() async {
  // 1. Lo primero: asegurar los bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializar fechas INMEDIATAMENTE para evitar la pantalla roja de LocaleDataException
  await initializeDateFormatting('es', null);
  
  try {
    // 3. Inicializar Firebase
    await Firebase.initializeApp();
    
    // 4. Configurar el manejador de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Configurar canal de notificaciones para Android (Foreground)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 6. Inicializar notificaciones locales con tu icono personalizado 'icono_hogar'
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('icono_hogar'); 
    
    const InitializationSettings initializationSettings = 
        InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 7. Escuchar mensajes con la APP ABIERTA (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'icono_hogar', // Icono configurado en AndroidManifest
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );
      }
    });
    
  } catch (e) {
    // Si algo falla en Firebase o Notificaciones, se imprime el error pero la app sigue al runApp
    print("Error crítico en la inicialización: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const GestionDormitoriosApp(),
    ),
  );
}

class GestionDormitoriosApp extends StatelessWidget {
  const GestionDormitoriosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HVU - ULV',
      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/home_preceptor': (context) => const DashboardPreceptorScreen(),
        '/home_monitor': (context) => const DashboardMonitorScreen(),
      },
    );
  }
}