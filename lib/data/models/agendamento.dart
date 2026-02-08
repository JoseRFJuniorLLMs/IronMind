class Agendamento {
  final int id;
  final int idosoId;
  final String tipo;
  final DateTime dataHoraAgendada;
  final DateTime? dataHoraRealizada;
  final String status;
  final String prioridade;
  final String? dadosTarefa;
  final int maxRetries;
  final int tentativasRealizadas;

  Agendamento({
    required this.id,
    required this.idosoId,
    required this.tipo,
    required this.dataHoraAgendada,
    this.dataHoraRealizada,
    required this.status,
    required this.prioridade,
    this.dadosTarefa,
    required this.maxRetries,
    required this.tentativasRealizadas,
  });

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      id: json['id'],
      idosoId: json['idoso_id'],
      tipo: json['tipo'],
      dataHoraAgendada: DateTime.parse(json['data_hora_agendada']),
      dataHoraRealizada: json['data_hora_realizada'] != null
          ? DateTime.parse(json['data_hora_realizada'])
          : null,
      status: json['status'],
      prioridade: json['prioridade'] ?? 'normal',
      dadosTarefa: json['dados_tarefa'],
      maxRetries: json['max_retries'] ?? 3,
      tentativasRealizadas: json['tentativas_realizadas'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idoso_id': idosoId,
      'tipo': tipo,
      'data_hora_agendada': dataHoraAgendada.toIso8601String(),
      'data_hora_realizada': dataHoraRealizada?.toIso8601String(),
      'status': status,
      'prioridade': prioridade,
      'dados_tarefa': dadosTarefa,
      'max_retries': maxRetries,
      'tentativas_realizadas': tentativasRealizadas,
    };
  }

  bool get isOverdue => DateTime.now().isAfter(dataHoraAgendada);
  bool get canRetry => tentativasRealizadas < maxRetries;
}
