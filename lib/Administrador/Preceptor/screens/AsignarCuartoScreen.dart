import 'package:flutter/material.dart';
import 'package:gestion_dormitorios/services/dormitorio_service.dart';

class AsignarCuartoScreen extends StatefulWidget {
  const AsignarCuartoScreen({super.key});

  @override
  State<AsignarCuartoScreen> createState() => _AsignarCuartoScreenState();
}

class _AsignarCuartoScreenState extends State<AsignarCuartoScreen> {
  final DormitorioService _service = DormitorioService();

  // Listas de datos
  List<dynamic> _estudiantes = [];
  List<dynamic> _dormitorios = [];
  List<dynamic> _pasillos = [];
  List<dynamic> _cuartos = [];

  // Selecciones
  String? _matriculaSeleccionada;
  String? _nombreEstudianteSeleccionado; // Variable para mostrar el nombre tras seleccionar
  int? _dormitorioSeleccionado;
  int? _pasilloSeleccionado;
  int? _cuartoSeleccionado;

  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<bool> _mostrarAlertaCambio(String nombre, String numeroCuarto) async {
    return await showDialog(
          context: context,
          barrierDismissible: false, // Obliga a responder
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 10),
                Text('Aviso de Cambio'),
              ],
            ),
            content: Text(
              'El estudiante $nombre ya está asignado al Cuarto $numeroCuarto.\n\n'
              '¿Deseas moverlo al nuevo cuarto seleccionado?',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                child: const Text('SÍ, CAMBIAR', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _cargarDatosIniciales() async {
    try {
      final estudiantes = await _service.getEstudiantesParaAsignacion();
      final pasillos = await _service.getPasillos();
      final dormitorios = await _service.getDormitorios();

      if (mounted) {
        setState(() {
          _estudiantes = estudiantes;
          _pasillos = pasillos;
          _dormitorios = dormitorios;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _cargarCuartos(int idPasillo) async {
    setState(() {
      _cuartoSeleccionado = null;
      _cuartos = [];
    });

    final cuartos = await _service.getCuartosPorPasillo(idPasillo);
    if (mounted) {
      setState(() => _cuartos = cuartos);
    }
  }

  // --- LÓGICA DEL BUSCADOR DE ESTUDIANTES ---
  void _mostrarBuscadorEstudiantes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que ocupe más pantalla
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9, // Altura inicial (90% de la pantalla)
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _BuscadorEstudiantesModal(
              estudiantes: _estudiantes,
              scrollController: scrollController,
              onEstudianteSeleccionado: (matricula, nombre) {
                setState(() {
                  _matriculaSeleccionada = matricula;
                  _nombreEstudianteSeleccionado = nombre;
                });
                Navigator.pop(context); // Cierra el modal
              },
            );
          },
        );
      },
    );
  }
  // -------------------------------------------

  void _guardar() async {
    if (_matriculaSeleccionada == null ||
        _dormitorioSeleccionado == null ||
        _pasilloSeleccionado == null ||
        _cuartoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona todos los campos')));
      return;
    }

    // 1. Buscamos al estudiante en la lista local para ver si ya tiene cuarto
    final estudiante = _estudiantes.firstWhere(
      (est) => est['Matricula'].toString() == _matriculaSeleccionada,
      orElse: () => null,
    );

    // 2. Verificamos si IdCuarto no es null y es diferente de 0
    if (estudiante != null && estudiante['IdCuarto'] != null && estudiante['IdCuarto'] != 0) {
      bool confirmar = await _mostrarAlertaCambio(
        estudiante['NombreCompleto'], 
        estudiante['NumeroCuarto']?.toString() ?? "otro"
      );
      
      if (!confirmar) return; // Si dice que no, nos detenemos aquí
    }

    // 3. Si no tenía cuarto o si aceptó el cambio, procedemos a guardar
    setState(() => _saving = true);

    final exito = await _service.asignarCuarto(
        _matriculaSeleccionada!,
        _dormitorioSeleccionado!,
        _pasilloSeleccionado!,
        _cuartoSeleccionado!);

    setState(() => _saving = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Asignación exitosa'), backgroundColor: Colors.green));
      _cargarDatosIniciales(); // Recargamos la lista para actualizar estados de los chicos

      setState(() {
        _matriculaSeleccionada = null;
        _nombreEstudianteSeleccionado = null;
        _pasilloSeleccionado = null;
        _cuartoSeleccionado = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al asignar'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Cuarto')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Selecciona Estudiante:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // --- AQUÍ ESTÁ EL CAMBIO VISUAL ---
                  // En lugar de Dropdown, usamos un InkWell que parece Input
                  InkWell(
                    onTap: _mostrarBuscadorEstudiantes,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        suffixIcon: const Icon(Icons.search), // Icono de lupa
                        hintText: 'Toca para buscar estudiante...',
                      ),
                      child: Text(
                        _nombreEstudianteSeleccionado ?? 'Buscar estudiante...',
                        style: TextStyle(
                          color: _nombreEstudianteSeleccionado == null
                              ? Colors.grey[600]
                              : Colors.black,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // ----------------------------------

                  const SizedBox(height: 20),
                  const Text('2. Selecciona Dormitorio:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _dormitorioSeleccionado,
                    hint: const Text('Seleccionar edificio'),
                    items: _dormitorios.map((d) {
                      return DropdownMenuItem<int>(
                        value: d['IdDormitorio'],
                        child: Text(d['NombreDormitorio'] ??
                            'Edificio ${d['IdDormitorio']}'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _dormitorioSeleccionado = val),
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),

                  const SizedBox(height: 20),
                  const Text('3. Selecciona Pasillo:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _pasilloSeleccionado,
                    hint: const Text('Seleccionar pasillo'),
                    items: _pasillos.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['IdPasillo'],
                        child: Text(
                            p['NombrePasillo'] ?? 'Pasillo ${p['IdPasillo']}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _pasilloSeleccionado = val);
                      if (val != null) _cargarCuartos(val);
                    },
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),

                  const SizedBox(height: 20),
                  const Text('4. Selecciona Cuarto:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _cuartoSeleccionado,
                    hint: Text(_pasilloSeleccionado == null
                        ? 'Primero elige pasillo'
                        : 'Seleccionar cuarto'),
                    disabledHint: const Text('Primero elige pasillo'),
                    items: _cuartos.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['IdCuarto'],
                        child: Text(
                            'Cuarto ${c['NumeroCuarto']} (Cap: ${c['Capacidad']})'),
                      );
                    }).toList(),
                    onChanged: _pasilloSeleccionado == null
                        ? null
                        : (val) => setState(() => _cuartoSeleccionado = val),
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          foregroundColor: Colors.white),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('GUARDAR ASIGNACIÓN'),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

// --- WIDGET AUXILIAR PARA EL BUSCADOR ---
// Esto maneja la lógica de filtrar la lista sin ensuciar la pantalla principal
class _BuscadorEstudiantesModal extends StatefulWidget {
  final List<dynamic> estudiantes;
  final ScrollController scrollController;
  final Function(String, String) onEstudianteSeleccionado;

  const _BuscadorEstudiantesModal({
    required this.estudiantes,
    required this.scrollController,
    required this.onEstudianteSeleccionado,
  });

  @override
  State<_BuscadorEstudiantesModal> createState() =>
      _BuscadorEstudiantesModalState();
}

class _BuscadorEstudiantesModalState extends State<_BuscadorEstudiantesModal> {
  String _filtro = "";
  List<dynamic> _listaFiltrada = [];

  @override
  void initState() {
    super.initState();
    _listaFiltrada = widget.estudiantes;
  }

  void _filtrarLista(String texto) {
    setState(() {
      _filtro = texto;
      if (texto.isEmpty) {
        _listaFiltrada = widget.estudiantes;
      } else {
        _listaFiltrada = widget.estudiantes.where((est) {
          final nombre = est['NombreCompleto'].toString().toLowerCase();
          final matricula = est['Matricula'].toString().toLowerCase();
          final busqueda = texto.toLowerCase();
          return nombre.contains(busqueda) || matricula.contains(busqueda);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Barra de agarre visual
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Buscar Estudiante",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          // Campo de texto para buscar
          TextField(
            autofocus: true, // Abre el teclado automáticamente
            onChanged: _filtrarLista,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Escribe nombre o matrícula...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 10),
          
          // Lista de resultados
          Expanded(
            child: _listaFiltrada.isEmpty
                ? const Center(child: Text("No se encontraron resultados"))
                : ListView.builder(
                    controller: widget.scrollController, // Importante para el scroll
                    itemCount: _listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final est = _listaFiltrada[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(est['NombreCompleto'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Matrícula: ${est['Matricula']}'),
                        onTap: () {
                          // Devolvemos los datos al padre
                          widget.onEstudianteSeleccionado(
                            est['Matricula'].toString(),
                            '${est['Matricula']} - ${est['NombreCompleto']}',
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}