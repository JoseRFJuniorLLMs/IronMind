/// Model para Medicamento
class Medicamento {
  final int id;
  final int idosoId;
  final String nome;
  final String? principioAtivo;
  final String dosagem;
  final String unidade; // mg, ml, comprimido, etc
  final String frequencia; // 1x ao dia, 2x ao dia, etc
  final List<String> horarios; // ["08:00", "20:00"]
  final String? instrucoes; // Com agua, em jejum, etc
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool ativo;
  final String? cor; // Para identificacao visual
  final String? formato; // comprimido, capsula, liquido, etc
  final String? imagemUrl;
  final DateTime? ultimaTomada;
  final int estoque; // Quantidade em estoque
  final int estoqueMinimo; // Alerta quando abaixo disso

  Medicamento({
    required this.id,
    required this.idosoId,
    required this.nome,
    this.principioAtivo,
    required this.dosagem,
    required this.unidade,
    required this.frequencia,
    required this.horarios,
    this.instrucoes,
    this.dataInicio,
    this.dataFim,
    this.ativo = true,
    this.cor,
    this.formato,
    this.imagemUrl,
    this.ultimaTomada,
    this.estoque = 0,
    this.estoqueMinimo = 5,
  });

  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'] ?? 0,
      idosoId: json['idoso_id'] ?? 0,
      nome: json['nome'] ?? '',
      principioAtivo: json['principio_ativo'],
      dosagem: json['dosagem'] ?? '',
      unidade: json['unidade'] ?? 'comprimido',
      frequencia: json['frequencia'] ?? '1x ao dia',
      horarios: (json['horarios'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      instrucoes: json['instrucoes'],
      dataInicio: json['data_inicio'] != null
          ? DateTime.parse(json['data_inicio'])
          : null,
      dataFim:
          json['data_fim'] != null ? DateTime.parse(json['data_fim']) : null,
      ativo: json['ativo'] ?? true,
      cor: json['cor'],
      formato: json['formato'],
      imagemUrl: json['imagem_url'],
      ultimaTomada: json['ultima_tomada'] != null
          ? DateTime.parse(json['ultima_tomada'])
          : null,
      estoque: json['estoque'] ?? 0,
      estoqueMinimo: json['estoque_minimo'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idoso_id': idosoId,
      'nome': nome,
      'principio_ativo': principioAtivo,
      'dosagem': dosagem,
      'unidade': unidade,
      'frequencia': frequencia,
      'horarios': horarios,
      'instrucoes': instrucoes,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'ativo': ativo,
      'cor': cor,
      'formato': formato,
      'imagem_url': imagemUrl,
      'ultima_tomada': ultimaTomada?.toIso8601String(),
      'estoque': estoque,
      'estoque_minimo': estoqueMinimo,
    };
  }

  /// Proximo horario de tomar
  DateTime? get proximoHorario {
    if (horarios.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final horario in horarios) {
      final parts = horario.split(':');
      if (parts.length == 2) {
        final hora = int.tryParse(parts[0]) ?? 0;
        final minuto = int.tryParse(parts[1]) ?? 0;
        final horarioHoje = today.add(Duration(hours: hora, minutes: minuto));

        if (horarioHoje.isAfter(now)) {
          return horarioHoje;
        }
      }
    }

    // Se todos os horarios de hoje ja passaram, retorna o primeiro de amanha
    if (horarios.isNotEmpty) {
      final parts = horarios.first.split(':');
      if (parts.length == 2) {
        final hora = int.tryParse(parts[0]) ?? 0;
        final minuto = int.tryParse(parts[1]) ?? 0;
        return today
            .add(const Duration(days: 1))
            .add(Duration(hours: hora, minutes: minuto));
      }
    }

    return null;
  }

  /// Verifica se o medicamento esta em baixo estoque
  bool get estoqueBaixo => estoque <= estoqueMinimo;

  /// Verifica se ja tomou hoje
  bool get tomouHoje {
    if (ultimaTomada == null) return false;
    final now = DateTime.now();
    return ultimaTomada!.year == now.year &&
        ultimaTomada!.month == now.month &&
        ultimaTomada!.day == now.day;
  }

  /// Copia com alteracoes
  Medicamento copyWith({
    int? id,
    int? idosoId,
    String? nome,
    String? principioAtivo,
    String? dosagem,
    String? unidade,
    String? frequencia,
    List<String>? horarios,
    String? instrucoes,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool? ativo,
    String? cor,
    String? formato,
    String? imagemUrl,
    DateTime? ultimaTomada,
    int? estoque,
    int? estoqueMinimo,
  }) {
    return Medicamento(
      id: id ?? this.id,
      idosoId: idosoId ?? this.idosoId,
      nome: nome ?? this.nome,
      principioAtivo: principioAtivo ?? this.principioAtivo,
      dosagem: dosagem ?? this.dosagem,
      unidade: unidade ?? this.unidade,
      frequencia: frequencia ?? this.frequencia,
      horarios: horarios ?? this.horarios,
      instrucoes: instrucoes ?? this.instrucoes,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      ativo: ativo ?? this.ativo,
      cor: cor ?? this.cor,
      formato: formato ?? this.formato,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      ultimaTomada: ultimaTomada ?? this.ultimaTomada,
      estoque: estoque ?? this.estoque,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
    );
  }
}

/// Registro de tomada de medicamento
class RegistroMedicamento {
  final int id;
  final int medicamentoId;
  final DateTime dataHora;
  final String status; // tomado, pulado, atrasado
  final String? observacao;
  final bool confirmadoPorScanner;

  RegistroMedicamento({
    required this.id,
    required this.medicamentoId,
    required this.dataHora,
    required this.status,
    this.observacao,
    this.confirmadoPorScanner = false,
  });

  factory RegistroMedicamento.fromJson(Map<String, dynamic> json) {
    return RegistroMedicamento(
      id: json['id'] ?? 0,
      medicamentoId: json['medicamento_id'] ?? 0,
      dataHora: DateTime.parse(json['data_hora']),
      status: json['status'] ?? 'tomado',
      observacao: json['observacao'],
      confirmadoPorScanner: json['confirmado_por_scanner'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicamento_id': medicamentoId,
      'data_hora': dataHora.toIso8601String(),
      'status': status,
      'observacao': observacao,
      'confirmado_por_scanner': confirmadoPorScanner,
    };
  }
}
