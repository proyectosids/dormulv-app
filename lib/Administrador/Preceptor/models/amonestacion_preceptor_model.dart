class AmonestacionPreceptor {
  final int idAmonestacion;
  final String estudianteNombre; 
  final String preceptorNombre; 
  final String nivel; 
  final String motivo;
  final DateTime fecha;
  final String? firmaEstudiante;

  AmonestacionPreceptor({
    required this.idAmonestacion,
    required this.estudianteNombre,
    required this.preceptorNombre,
    required this.nivel,
    required this.motivo,
    required this.fecha,
    this.firmaEstudiante,

  });

  factory AmonestacionPreceptor.fromJson(Map<String, dynamic> json) {
     DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['Fecha']);
    } catch (e) {
      print('Error parseando Fecha en AmonestacionPreceptor: ${json['Fecha']} - ${e}');
      parsedDate = DateTime.now(); // Fallback
    }

    return AmonestacionPreceptor(
      idAmonestacion: json['IdAmonestacion'] ?? 0,
      estudianteNombre: json['Estudiante'] ?? 'Desconocido',
      preceptorNombre: json['Preceptor'] ?? 'Desconocido',
      nivel: json['Nivel'] ?? 'Desconocido',
      motivo: json['Motivo'] ?? 'Sin motivo',
      fecha: parsedDate,
      firmaEstudiante: json['FirmaEstudiante'],
    );
  }
}
