import 'dart:convert';
import 'package:flutter/material.dart';

class VerFirmaDialog extends StatelessWidget {
  final String firmaBase64;
  final String titulo;

  const VerFirmaDialog({
    super.key, 
    required this.firmaBase64, 
    this.titulo = "Visualización de Firma"
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            // 👇 Aquí ocurre la magia: convierte Base64 a imagen de Flutter
            child: Image.memory(
              base64Decode(firmaBase64),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),
          const Text("Firmado digitalmente por el estudiante.", 
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }
}