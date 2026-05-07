import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// Importaciones del proyecto
import 'package:gestion_dormitorios/config/api_config.dart';
import 'package:gestion_dormitorios/widgets/firma_dialog_widget.dart';
import 'package:gestion_dormitorios/widgets/ver_firma_dialog.dart';
import 'package:gestion_dormitorios/services/amonestacion_service.dart';
import 'package:gestion_dormitorios/Administrador/Preceptor/models/amonestacion_preceptor_model.dart';
import 'package:gestion_dormitorios/Administrador/Preceptor/screens/crear_amonestacion_screen.dart';

class AmonestacionesPreceptorScreen extends StatefulWidget {
  const AmonestacionesPreceptorScreen({super.key});

  @override
  State<AmonestacionesPreceptorScreen> createState() => _AmonestacionesPreceptorScreenState();
}

class _AmonestacionesPreceptorScreenState extends State<AmonestacionesPreceptorScreen> {
  final AmonestacionService _amonestacionService = AmonestacionService();
  late Future<List<AmonestacionPreceptor>> _futureAmonestaciones;

  @override
  void initState() {
    super.initState();
    _cargarAmonestaciones();
  }

  void _cargarAmonestaciones() {
    if (!mounted) return;
    setState(() { _futureAmonestaciones = _amonestacionService.getAllAmonestaciones(); });
  }

  // --- NUEVA LÓGICA: FIRMA ---
  void _abrirFirmaDialog(int idAmonestacion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FirmaDialogWidget(
        onConfirm: (String base64) => _enviarFirmaAlBackend(idAmonestacion, 'AMONESTACION', base64),
      ),
    );
  }

  Future<void> _enviarFirmaAlBackend(int id, String tipo, String base64) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/firmas/guardar');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idDocumento': id, 'tipo': tipo, 'firmaBase64': base64}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Firma registrada"), backgroundColor: Colors.green));
        _cargarAmonestaciones();
      }
    } catch (e) { print(e); }
  }
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Amonestaciones'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => _cargarAmonestaciones(),
        child: FutureBuilder<List<AmonestacionPreceptor>>(
          future: _futureAmonestaciones,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay amonestaciones.'));

            final amonestaciones = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: amonestaciones.length,
              itemBuilder: (context, index) => _buildAmonestacionCard(context, amonestaciones[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearAmonestacionScreen())).then((val) { if (val == true) _cargarAmonestaciones(); }),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Nueva Amonestación'),
      ),
    );
  }

  Widget _buildAmonestacionCard(BuildContext context, AmonestacionPreceptor amon) {
    final theme = Theme.of(context);
    final colorNivel = _getColorNivel(amon.nivel);
    final bool estaFirmado = amon.firmaEstudiante != null && amon.firmaEstudiante!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estudiante: ${amon.estudianteNombre}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('Registrada por: ${amon.preceptorNombre}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            const Divider(height: 16),
            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(amon.fecha)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Motivo: ${amon.motivo}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text(amon.nivel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)), backgroundColor: colorNivel, visualDensity: VisualDensity.compact, avatar: Icon(_getIconoNivel(amon.nivel), color: Colors.white, size: 14)),
                
                estaFirmado
                ? InkWell(
                    onTap: () => showDialog(context: context, builder: (_) => VerFirmaDialog(firmaBase64: amon.firmaEstudiante!, titulo: "Firma de: ${amon.estudianteNombre}")),
                    child: const Row(children: [Icon(Icons.verified_user, color: Colors.green, size: 18), SizedBox(width: 4), Text("Firmado (Ver)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))]),
                  )
                : OutlinedButton.icon(onPressed: () => _abrirFirmaDialog(amon.idAmonestacion), icon: const Icon(Icons.draw, size: 18), label: const Text("Firmar Recibido"), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueAccent), foregroundColor: Colors.blueAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorNivel(String nivel) { switch (nivel.toLowerCase()) { case 'leve': return Colors.green.shade600; case 'media': return Colors.orange.shade700; case 'grave': return Colors.red.shade700; default: return Colors.grey.shade500; } }
  IconData _getIconoNivel(String nivel) { switch (nivel.toLowerCase()) { case 'leve': return Icons.check_circle_outline; case 'media': return Icons.warning_amber_rounded; case 'grave': return Icons.error_outline; default: return Icons.info_outline; } }
}
