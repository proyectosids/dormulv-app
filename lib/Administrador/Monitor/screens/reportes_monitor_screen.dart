import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Importaciones del proyecto
import 'package:gestion_dormitorios/config/api_config.dart';
import 'package:gestion_dormitorios/widgets/firma_dialog_widget.dart';
import 'package:gestion_dormitorios/widgets/ver_firma_dialog.dart';
import 'package:gestion_dormitorios/providers/user_provider.dart';
import 'package:gestion_dormitorios/services/reporte_service.dart';
import 'package:gestion_dormitorios/Administrador/Monitor/models/reporte_monitor_model.dart';
import 'package:gestion_dormitorios/Administrador/Monitor/screens/crear_reporte_screen.dart';

class ReportesMonitorScreen extends StatefulWidget {
  const ReportesMonitorScreen({super.key});

  @override
  State<ReportesMonitorScreen> createState() => _ReportesMonitorScreenState();
}

class _ReportesMonitorScreenState extends State<ReportesMonitorScreen> {
  final TextEditingController _matriculaController = TextEditingController();
  final ReporteService _reporteService = ReporteService();

  Future<List<ReporteMonitor>>? _futureReportes;
  String? _matriculaBuscada;
  bool _isLoading = false;
  String _mensaje = 'Ingresa una matrícula para ver sus reportes.';

  @override
  void dispose() {
    _matriculaController.dispose();
    super.dispose();
  }

  // --- NUEVA FUNCIONALIDAD: FIRMA ---
  void _abrirFirmaDialog(int idReporte) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FirmaDialogWidget(
        onConfirm: (String firmaBase64) async {
          await _enviarFirmaAlBackend(idReporte, 'REPORTE', firmaBase64);
        },
      ),
    );
  }

  Future<void> _enviarFirmaAlBackend(int id, String tipo, String base64) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/firmas/guardar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idDocumento': id, 'tipo': tipo, 'firmaBase64': base64}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Firma guardada con éxito"), backgroundColor: Colors.green),
          );
        }
        // 👇 ESTA ES LA CLAVE: Refrescamos la búsqueda para actualizar el estado del botón
        _buscarReportes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error de conexión: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _buscarReportes() {
    final matricula = _matriculaController.text.trim();
    if (matricula.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una matrícula.'), backgroundColor: Colors.orange),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _futureReportes = _reporteService.buscarReportesMonitor(matricula);
      _matriculaBuscada = matricula;
      _mensaje = '';
    });
    _futureReportes!.then((_) {
      if (mounted) setState(() => _isLoading = false);
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _mensaje = '$error'; 
        });
      }
    });
  }

  void _irACrearReporte() {
    if (_matriculaBuscada == null || _matriculaBuscada!.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero busca una matrícula válida.'), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearReporteScreen(matriculaEstudiante: _matriculaBuscada!),
      ),
    ).then((seGuardo) {
      if (seGuardo == true) {
        _buscarReportes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Reportes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _matriculaController,
              decoration: InputDecoration(
                labelText: 'Matrícula del Estudiante',
                hintText: 'Ej. 222100',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _matriculaController.clear();
                    setState(() {
                      _futureReportes = null;
                      _matriculaBuscada = null;
                      _mensaje = 'Ingresa una matrícula para ver sus reportes.';
                    });
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscarReportes(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _buscarReportes,
              icon: _isLoading 
                   ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) 
                   : const Icon(Icons.search),
              label: Text(_isLoading ? 'Buscando...' : 'Buscar Reportes'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              height: MediaQuery.of(context).size.height * 0.5, 
              child: _isLoading && _futureReportes == null
                  ? const Center(child: CircularProgressIndicator()) 
                  : (_futureReportes == null
                      ? Center(child: Text(_mensaje, textAlign: TextAlign.center))
                      : FutureBuilder<List<ReporteMonitor>>(
                          future: _futureReportes,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
                               return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError && _mensaje.isNotEmpty) {
                               return Center(child: Text(_mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(child: Text(_mensaje.isNotEmpty ? _mensaje : 'No se encontraron reportes.', textAlign: TextAlign.center));
                            }
                            final reportes = snapshot.data!;
                            return ListView.builder(
                              itemCount: reportes.length,
                              itemBuilder: (context, index) {
                                return _buildReporteCard(context, reportes[index]);
                              },
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _irACrearReporte,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Reporte'),
        tooltip: 'Crear un nuevo reporte para el estudiante buscado',
      ),
    );
  }

  Widget _buildReporteCard(BuildContext context, ReporteMonitor reporte) {
    final theme = Theme.of(context);
    final colorEstado = _colorEstado(reporte.estado); 
    final iconoEstado = _iconoEstado(reporte.estado);
    
    // 👇 Esta lógica detecta si ya existe la firma para decidir qué mostrar
    final bool estaFirmado = reporte.firmaEstudiante != null && reporte.firmaEstudiante!.isNotEmpty;
    final bool puedeFirmar = reporte.estado.toLowerCase() == 'aprobado';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estudiante: ${reporte.nombreEstudianteReportado}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('Matrícula: ${reporte.matriculaReportado ?? _matriculaBuscada ?? 'N/A'}', style: theme.textTheme.bodySmall),
            const Divider(height: 16),
            Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(reporte.fechaReporte)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Motivo: ${reporte.motivo}'),
            const SizedBox(height: 8),
            Text('Reportado por: ${reporte.reportadoPorNombre}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: colorEstado.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(iconoEstado, size: 16, color: colorEstado),
                      const SizedBox(width: 6),
                      Text(reporte.estado, style: TextStyle(color: colorEstado, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),

                // --- LÓGICA DE FIRMA DINÁMICA ---
                if (estaFirmado)
                  InkWell(
                    onTap: () => showDialog(
                      context: context, 
                      builder: (_) => VerFirmaDialog(
                        firmaBase64: reporte.firmaEstudiante!, 
                        titulo: "Firma Estudiante"
                      )
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 4),
                        Text("Firmado (Ver)", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ],
                    ),
                  )
                else if (puedeFirmar) 
                  ElevatedButton.icon(
                    onPressed: () => _abrirFirmaDialog(reporte.idReporte),
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text("Firmar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else 
                  const Text(
                    "Esperando aprobación", 
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'aprobado': return Colors.green;
      case 'pendiente': return Colors.orange;
      case 'rechazado': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'aprobado': return Icons.check_circle_outline;
      case 'pendiente': return Icons.hourglass_empty_rounded;
      case 'rechazado': return Icons.cancel_outlined;
      default: return Icons.info_outline;
    }
  }
}