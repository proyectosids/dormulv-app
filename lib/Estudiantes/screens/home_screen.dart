import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_dormitorios/providers/user_provider.dart';
import 'package:gestion_dormitorios/providers/theme_provider.dart';
// IMPORTA EL SERVICIO QUE CREAMOS ARRIBA
import 'package:gestion_dormitorios/services/notification_token_service.dart'; 

import 'package:gestion_dormitorios/Estudiantes/screens/limpieza_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/asistencia_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/amonestaciones_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/reportes_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/estadisticas_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/perfil_screen.dart';
import 'package:gestion_dormitorios/Estudiantes/screens/configuracio_screen.dart';
import 'package:gestion_dormitorios/foto_perfil_widget.dart';

// 1. CAMBIO A STATEFULWIDGET
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  // 2. INITSTATE: Aquí registramos el token apenas entra el alumno
  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para acceder al Provider de forma segura
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      if (user.matricula.isNotEmpty) {
        // LLAMADA AL SERVICIO
        NotificationTokenService.registerToken(user.matricula);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Provider.of<UserProvider>(context); 

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'HVU',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: theme.iconTheme.color),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      drawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FotoPerfilWidget(
                    matricula: user.matricula, 
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.nombre.isNotEmpty ? user.nombre : 'Usuario desconocido',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Matrícula: ${user.matricula}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configuración'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfiguracionScreen())),
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Provider.of<UserProvider>(context, listen: false).logout();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FotoPerfilWidget(
                  matricula: user.matricula,
                  size: 30,
                ),
                const SizedBox(width: 12),
                
                Expanded( 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nombre.isNotEmpty ? user.nombre : 'Cargando nombre...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Matrícula: ${user.matricula}',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 30),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  int crossAxisCount;

                  if (width > 900) {
                    crossAxisCount = 4; 
                  } else if (width > 600) {
                    crossAxisCount = 3; 
                  } else {
                    crossAxisCount = 2; 
                  }

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _menuCard(icon: Icons.cleaning_services, title: 'Limpieza', screen: const LimpiezaScreen(), isDark: isDark, context: context),
                      _menuCard(icon: Icons.check_circle_outline, title: 'Asistencia', screen: const AsistenciaScreen(), isDark: isDark, context: context),
                      _menuCard(icon: Icons.warning, title: 'Amonestación', screen: const AmonestacionesScreen(), isDark: isDark, context: context),
                      _menuCard(icon: Icons.description, title: 'Reportes', screen: const ReportesAlumnoScreen(), isDark: isDark, context: context),
                      _menuCard(icon: Icons.show_chart, title: 'Estadística', screen: const EstadisticasScreen(), isDark: isDark, context: context),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required Widget screen,
    required bool isDark,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final iconColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}