import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FirmaDialogWidget extends StatefulWidget {
  // Esta función se ejecuta cuando el usuario le da a "Confirmar"
  // Devuelve el texto Base64 de la imagen
  final Function(String) onConfirm;

  const FirmaDialogWidget({super.key, required this.onConfirm});

  @override
  State<FirmaDialogWidget> createState() => _FirmaDialogWidgetState();
}

class _FirmaDialogWidgetState extends State<FirmaDialogWidget> {
  // Controlador del lienzo (Lápiz)
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3, // Grosor del trazo
    penColor: Colors.black, // Color del trazo
    exportBackgroundColor: Colors.white, // Fondo blanco al guardar
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardarFirma() async {
    if (_controller.isNotEmpty) {
      // 1. Convertir el dibujo a bytes (Formato PNG)
      final Uint8List? data = await _controller.toPngBytes();

      if (data != null) {
        // 2. Convertir bytes a String Base64 (Para enviar a SQL)
        final String base64Signature = base64Encode(data);
        
        // 3. Devolver la firma al padre y cerrar la ventana
        widget.onConfirm(base64Signature);
        Navigator.of(context).pop(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
        children: [
          // CABECERA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              "Firma del Estudiante",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          // ÁREA DE DIBUJO (CANVAS)
          Container(
            height: 300, // Altura del área de firma
            color: Colors.white,
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.white,
            ),
          ),
          
          const Divider(height: 1),

          // BOTONES DE ACCIÓN
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón Borrar
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text("Borrar", style: TextStyle(color: Colors.red)),
                  onPressed: () => _controller.clear(),
                ),
                
                // Botón Confirmar
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text("Confirmar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _guardarFirma,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}