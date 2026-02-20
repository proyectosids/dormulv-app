class ReporteMonitor {
  final int idReporte;
  final String motivo;
  final DateTime fechaReporte;
  final String estado; 
  final String nombreEstudianteReportado; 
  final String reportadoPorNombre; 
  final String? matriculaReportado; 
  final String? reportadoPor; 
  final String? tipoUsuarioReportante;
  final String? firmaEstudiante;

  ReporteMonitor({
    required this.idReporte,
    required this.motivo,
    required this.fechaReporte,
    required this.estado,
    required this.nombreEstudianteReportado,
    required this.reportadoPorNombre,
    this.matriculaReportado, 
    this.reportadoPor,
    this.tipoUsuarioReportante,
    this.firmaEstudiante,
  });

  factory ReporteMonitor.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['FechaReporte']);
    } catch (e) {
      print('Error parseando FechaReporte en ReporteMonitor: ${json['FechaReporte']} - ${e}');
      parsedDate = DateTime.now(); 
    }

    return ReporteMonitor(
      idReporte: json['IdReporte'] ?? 0,
      motivo: json['Motivo'] ?? 'Sin motivo especificado',
      fechaReporte: parsedDate,
      estado: json['Estado'] ?? 'Desconocido',
      nombreEstudianteReportado: json['NombreEstudiante'] ?? json['NombreEstudianteReportado'] ?? 'Estudiante Desconocido',
      reportadoPorNombre: json['ReportadoPorNombre'] ?? 'Sistema',
      matriculaReportado: json['MatriculaReportado'], 
      reportadoPor: json['ReportadoPor'],
      tipoUsuarioReportante: json['TipoUsuarioReportante'],
      firmaEstudiante: json['FirmaEstudiante'],

    );
  }
}

