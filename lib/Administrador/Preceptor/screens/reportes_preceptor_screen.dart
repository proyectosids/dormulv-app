import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 

// Importaciones del proyecto
import 'package:gestion_dormitorios/config/api_config.dart';
import 'package:gestion_dormitorios/widgets/firma_dialog_widget.dart';
import 'package:gestion_dormitorios/widgets/ver_firma_dialog.dart';
import 'package:gestion_dormitorios/providers/user_provider.dart';
import 'package:gestion_dormitorios/services/reporte_service.dart';
import 'package:gestion_dormitorios/Administrador/Monitor/models/reporte_monitor_model.dart';
import 'package:gestion_dormitorios/Administrador/Preceptor/screens/crear_reporte_preceptor_screen.dart';

class ReportesPreceptorScreen extends StatefulWidget {
  const ReportesPreceptorScreen({super.key});

  @override
  State<ReportesPreceptorScreen> createState() => _ReportesPreceptorScreenState();
}

class _ReportesPreceptorScreenState extends State<ReportesPreceptorScreen> {
  final ReporteService _reporteService = ReporteService();
  List<ReporteMonitor> _reportes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _limit = 20;
  int _totalReportes = 0;
  bool _isLastPage = false;
  final ScrollController _scrollController = ScrollController(); 
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; 

  bool _isUpdatingReporte = false;
  int? _updatingReporteId;

  @override
  void initState() {
    super.initState();
    _cargarReportesIniciales(); 
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading && !_isLoadingMore && !_isLastPage) {
        _cargarMasReportes();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE FIRMA ---
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Firma guardada"), backgroundColor: Colors.green));
        
        // 👇 REFRESCAR LISTA: Esto hace que el botón desaparezca inmediatamente
        _cargarReportesIniciales(searchTerm: _searchController.text.trim());
      }
    } catch (e) { print(e); }
  }

  // --- CARGA DE DATOS ---
  Future<void> _cargarReportesIniciales({String? searchTerm}) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; _currentPage = 1; _isLastPage = false; _reportes = []; });
    try {
      final resultado = await _reporteService.getAllReportes(page: _currentPage, limit: _limit, search: searchTerm);
      if (!mounted) return;
      setState(() { _reportes = resultado['reportes'] as List<ReporteMonitor>; _totalReportes = resultado['total'] as int; _isLastPage = _reportes.length >= _totalReportes; });
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMessage = e.toString(); });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasReportes() async {
    if (_isLoading || _isLoadingMore || _isLastPage || !mounted) return; 
    setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
       final resultado = await _reporteService.getAllReportes(page: _currentPage, limit: _limit, search: _searchController.text.trim());
       if (!mounted) return;
       setState(() { _reportes.addAll(resultado['reportes'] as List<ReporteMonitor>); _isLastPage = _reportes.length >= _totalReportes; });
    } catch (e) {
       if (mounted) setState(() { _errorMessage = "Error al cargar más: $e"; _currentPage--; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red)); });
    } finally {
       if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _cargarReportesIniciales(searchTerm: query.trim()));
  }

  // --- ACCIONES DE ESTADO ---
  Future<void> _aprobarReporte(ReporteMonitor reporte) async {
    final preceptorId = Provider.of<UserProvider>(context, listen: false).usuarioID;
    setState(() { _isUpdatingReporte = true; _updatingReporteId = reporte.idReporte; });
    try {
      await _reporteService.aprobarReporte(reporte.idReporte, preceptorId);
      _cargarReportesIniciales(searchTerm: _searchController.text.trim());
    } finally {
       if (mounted) setState(() { _isUpdatingReporte = false; _updatingReporteId = null; });
    }
  }

  Future<void> _rechazarReporte(ReporteMonitor reporte) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar Rechazo'), content: const Text('¿Rechazar reporte?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí'))]));
    if (confirm != true) return;
    setState(() { _isUpdatingReporte = true; _updatingReporteId = reporte.idReporte; });
    try {
      await _reporteService.rechazarReporte(reporte.idReporte);
      _cargarReportesIniciales(searchTerm: _searchController.text.trim());
    } finally {
       if (mounted) setState(() { _isUpdatingReporte = false; _updatingReporteId = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Todos los Reportes (HVU)'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(labelText: 'Buscar...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildBodyContent(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearReportePreceptorScreen())).then((val) { if(val==true) _cargarReportesIniciales(); }), icon: const Icon(Icons.add), label: const Text('Nuevo Reporte')),
    );
  }

  Widget _buildBodyContent(ThemeData theme){
    if (_isLoading && _reportes.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_hasError && _reportes.isEmpty) return Center(child: Text('Error: $_errorMessage'));
    if (_reportes.isEmpty) return const Center(child: Text('No hay reportes.'));

    return RefreshIndicator(
      onRefresh: () async => _cargarReportesIniciales(searchTerm: _searchController.text.trim()),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
        itemCount: _reportes.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reportes.length) return const Center(child: CircularProgressIndicator());
          return _buildReporteCard(context, _reportes[index]);
        },
      ),
    );
  }

  Widget _buildReporteCard(BuildContext context, ReporteMonitor reporte) {
    final theme = Theme.of(context);
    final bool estaFirmado = reporte.firmaEstudiante != null && reporte.firmaEstudiante!.isNotEmpty;
    final bool esAprobado = reporte.estado.toLowerCase() == 'aprobado';
    final bool isUpdatingThisCard = _isUpdatingReporte && _updatingReporteId == reporte.idReporte;

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
            if(reporte.matriculaReportado != null) Text('Matrícula: ${reporte.matriculaReportado}', style: theme.textTheme.bodySmall),
            const Divider(height: 16),
            Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(reporte.fechaReporte)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Motivo: ${reporte.motivo}'),
            const SizedBox(height: 8),
            Text('Reportado por: ${reporte.reportadoPorNombre}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEstadoBadge(reporte),
                
                // --- LÓGICA DINÁMICA DE FIRMA ---
                if (estaFirmado)
                  _buildBotonVerFirma(reporte) // Al refrescar, este widget se mostrará
                else if (esAprobado)
                  TextButton.icon(
                    onPressed: () => _abrirFirmaDialog(reporte.idReporte),
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text("Recabar Firma"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            
            if (reporte.estado.toLowerCase() == 'pendiente')
              _buildAccionesAprobacion(theme, reporte, isUpdatingThisCard),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE LA TARJETA ---

  Widget _buildEstadoBadge(ReporteMonitor reporte) {
    final Color color = _colorEstado(reporte.estado);
    final IconData icono = _iconoEstado(reporte.estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Text(reporte.estado, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBotonVerFirma(ReporteMonitor reporte) {
    return InkWell(
      onTap: () => showDialog(
        context: context, 
        builder: (_) => VerFirmaDialog(firmaBase64: reporte.firmaEstudiante!, titulo: "Firma Estudiante")
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 4),
          Text("Firmado (Ver)", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
        ],
      ),
    );
  }

  Widget _buildAccionesAprobacion(ThemeData theme, ReporteMonitor reporte, bool isUpdating) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: isUpdating 
        ? const Center(child: CircularProgressIndicator()) 
        : Row(
            mainAxisAlignment: MainAxisAlignment.end, 
            children: [
              TextButton.icon(
                icon: const Icon(Icons.close, size: 18), 
                label: const Text('Rechazar'), 
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error), 
                onPressed: () => _rechazarReporte(reporte)
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18), 
                label: const Text('Aprobar'), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), 
                onPressed: () => _aprobarReporte(reporte)
              )
            ]
          ),
    );
  }

  Color _colorEstado(String estado) { 
    switch (estado.toLowerCase()) { 
      case 'aprobado': return Colors.green.shade700; 
      case 'pendiente': return Colors.orange.shade700; 
      case 'rechazado': return Colors.red.shade700; 
      default: return Colors.grey.shade600; 
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