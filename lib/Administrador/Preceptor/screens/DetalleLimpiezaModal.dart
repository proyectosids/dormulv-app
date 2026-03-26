import 'package:flutter/material.dart';
import 'package:gestion_dormitorios/services/limpieza_service.dart';
import 'package:intl/intl.dart';

class DetalleLimpiezaModal extends StatelessWidget {
  final int idCuarto;
  final String numeroCuarto;

  const DetalleLimpiezaModal({
    super.key, 
    required this.idCuarto, 
    required this.numeroCuarto
  });

  @override
  Widget build(BuildContext context) {
    final LimpiezaService limpiezaService = LimpiezaService();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tirador visual del modal
          Center(
            child: Container(
              width: 40, 
              height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Detalle Cuarto $numeroCuarto', 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)
          ),
          const Divider(),
          
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: limpiezaService.obtenerDetalleLimpieza(idCuarto),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('No se pudieron cargar los detalles actuales.'));
                }

                try {
                  final data = snapshot.data!;
                  final detalles = data['Detalle'] as List<dynamic>;
                  final String? urlFoto = data['UrlFoto'];

                  return ListView(
                    children: [
                      _infoRow(Icons.calendar_today, 'Fecha', _formatearFecha(data['Fecha'])),
                      _infoRow(Icons.person, 'Evaluador', data['EvaluadoPor'] ?? 'No asignado'),
                      const SizedBox(height: 20),
                      
                      // --- 📸 SECCIÓN DE EVIDENCIA FOTOGRÁFICA ---
                      if (urlFoto != null && urlFoto.isNotEmpty) ...[
                        const Text('📸 Evidencia Visual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _mostrarFotoCompleta(context, urlFoto),
                            child: Image.network(
                              urlFoto,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              // Manejo de carga corregido para Image.network
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 220,
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              // Si la foto fue borrada por el Usuario SISTEMA tras 7 días
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade100)
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.red),
                                    SizedBox(height: 5),
                                    Text('Evidencia expirada (7 días)', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const Text('🌞 Evaluación Matutina', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      if (detalles.isEmpty) const Text('Sin criterios evaluados.'),
                      ...detalles.map((d) => _itemCalificacion(d['Criterio'] ?? 'Criterio', d['Calificacion'] ?? 0)),

                      const Divider(height: 30),

                      const Text('🌙 Evaluación Nocturna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      _itemCalificacion('Orden General', data['OrdenGeneral'] ?? 0),
                      _itemCalificacion('Disciplina', data['Disciplina'] ?? 0),

                      if (data['Observaciones'] != null && data['Observaciones'].toString().isNotEmpty) ...[
                        const Divider(height: 30),
                        const Text('💬 Observaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                          child: Text(data['Observaciones'], style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      ],

                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.blue[900], 
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('PUNTAJE TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${data['TotalFinal'] ?? 0}/100', 
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                } catch (e) {
                  return Center(child: Text("Error al procesar el detalle: $e"));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Visualizador de foto en pantalla completa con zoom
  void _mostrarFotoCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black87),
            ),
          ),
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(dynamic fechaRaw) {
    if (fechaRaw == null) return 'N/A';
    try {
      final fecha = DateTime.parse(fechaRaw.toString());
      return DateFormat('dd/MM/yyyy - hh:mm a').format(fecha);
    } catch (e) {
      return fechaRaw.toString();
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _itemCalificacion(String concepto, int puntaje) {
    Color colorPuntaje = puntaje >= 9 ? Colors.green : (puntaje >= 7 ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(concepto, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: colorPuntaje.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              puntaje.toString(), 
              style: TextStyle(fontWeight: FontWeight.bold, color: colorPuntaje)
            ),
          ),
        ],
      ),
    );
  }
}