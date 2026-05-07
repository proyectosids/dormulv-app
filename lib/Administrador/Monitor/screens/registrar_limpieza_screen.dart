import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gestion_dormitorios/config/api_config.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:gestion_dormitorios/providers/user_provider.dart';
import 'package:gestion_dormitorios/services/limpieza_service.dart';
import 'package:gestion_dormitorios/Administrador/Monitor/models/criterio_limpieza_model.dart';

class RegistrarLimpiezaScreen extends StatefulWidget {
  final int idCuarto;

  const RegistrarLimpiezaScreen({super.key, required this.idCuarto});

  @override
  State<RegistrarLimpiezaScreen> createState() => _RegistrarLimpiezaScreenState();
}

class _RegistrarLimpiezaScreenState extends State<RegistrarLimpiezaScreen> {
  final LimpiezaService _limpiezaService = LimpiezaService();
  late Future<List<CriterioLimpieza>> _futureCriterios;

  int _ordenGeneral = 0;
  int _disciplina = 0;
  final TextEditingController _observacionesController = TextEditingController();
  
  // 📸 Variables para la foto
  File? _fotoEvidencia;
  final ImagePicker _picker = ImagePicker();

  List<CriterioLimpieza> _criteriosList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _futureCriterios = _limpiezaService.obtenerCriterios();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  // 📸 Función para tomar la foto con la cámara
  Future<void> _tomarFoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 50, // Reducimos calidad para ahorrar ancho de banda
    );
    if (photo != null) {
      setState(() {
        _fotoEvidencia = File(photo.path);
      });
    }
  }

  Future<void> _guardarLimpieza() async {
    if (_criteriosList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que carguen los criterios.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final monitorMatricula = userProvider.matricula;

    if (monitorMatricula.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se identificó al monitor.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 Usamos MultipartRequest para enviar archivos y campos de texto
      // Asumiendo que tu baseUrl es algo como 'http://192.168.1.100:5000/api'
      final url = Uri.parse('${ApiConfig.baseUrl}/limpieza/registrar');
      var request = http.MultipartRequest('POST', url);

      // Campos de texto simples
      request.fields['idCuarto'] = widget.idCuarto.toString();
      request.fields['evaluadoPor'] = monitorMatricula;
      request.fields['ordenGeneral'] = _ordenGeneral.toString();
      request.fields['disciplina'] = _disciplina.toString();
      request.fields['observaciones'] = _observacionesController.text;

      // Convertimos la lista de criterios a JSON String para que Multer la reciba
      final criteriosJson = _criteriosList.map((c) => {
        'idCriterio': c.idCriterio,
        'calificacion': c.calificacion,
      }).toList();
      request.fields['detallesMatutinos'] = json.encode(criteriosJson);

      // Adjuntar la foto si existe
      if (_fotoEvidencia != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'evidencia', // Debe coincidir con upload.single('evidencia') en el Backend
          _fotoEvidencia!.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      // Enviar y esperar respuesta
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado con éxito'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al guardar');
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluar Cuarto ${widget.idCuarto}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _guardarLimpieza, 
                    tooltip: 'Guardar',
                  ),
          ),
        ],
      ),
      body: FutureBuilder<List<CriterioLimpieza>>(
        future: _futureCriterios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay criterios definidos.'));
          }

          if (_criteriosList.isEmpty) {
            _criteriosList = snapshot.data!;
            }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Criterios Matutinos (Máx 80 pts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              
              ..._criteriosList.map((criterio) => _buildCriterioRow(criterio)).toList(),

              const Divider(height: 40, thickness: 2),

              const Text('Evaluación Nocturna (Máx 20 pts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              
              _buildAdditionalScoreRow('Orden General (Noche)', _ordenGeneral, (val) => setState(() => _ordenGeneral = val)),
              _buildAdditionalScoreRow('Disciplina (Noche)', _disciplina, (val) => setState(() => _disciplina = val)),

              const SizedBox(height: 20),
              
              // 📸 Sección de Evidencia Visual
              const Text('Evidencia (Fotos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    if (_fotoEvidencia != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.file(_fotoEvidencia!, height: 200, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ListTile(
                      leading: Icon(Icons.camera_alt, color: _fotoEvidencia != null ? Colors.green : Colors.blue),
                      title: Text(_fotoEvidencia == null ? 'Tomar foto de cuarto sucio' : 'Cambiar foto'),
                      subtitle: Text(_fotoEvidencia == null ? 'Evidencia para el preceptor' : 'Foto capturada'),
                      onTap: _tomarFoto,
                    ),
                    if (_fotoEvidencia != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _fotoEvidencia = null),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                      )
                  ],
                ),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 80), 
            ],
          );
        },
      ),
    );
  }

  Widget _buildCriterioRow(CriterioLimpieza criterio) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(criterio.descripcion, style: const TextStyle(fontSize: 16))),
            DropdownButton<int>(
              value: criterio.calificacion,
              underline: Container(),
              items: List.generate(11, (index) => index).map((val) {
                return DropdownMenuItem(value: val, child: Text(val.toString()));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => criterio.calificacion = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalScoreRow(String label, int value, Function(int) onChanged) {
    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
            DropdownButton<int>(
              value: value,
              underline: Container(),
              items: List.generate(11, (index) => index).map((val) {
                return DropdownMenuItem(value: val, child: Text(val.toString()));
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}