class Idoso {
  final int id;
  final String nome;
  final DateTime dataNascimento;
  final String telefone;
  final String cpf;
  final String? deviceToken;
  final bool ativo;
  final String nivelCognitivo;
  final bool limitacoesAuditivas;
  final bool usaAparelhoAuditivo;
  final String tomVoz;
  final String preferenciaHorario;

  Idoso({
    required this.id,
    required this.nome,
    required this.dataNascimento,
    required this.telefone,
    required this.cpf,
    this.deviceToken,
    required this.ativo,
    required this.nivelCognitivo,
    required this.limitacoesAuditivas,
    required this.usaAparelhoAuditivo,
    required this.tomVoz,
    required this.preferenciaHorario,
  });

  factory Idoso.fromJson(Map<String, dynamic> json) {
    return Idoso(
      id: json['id'],
      nome: json['nome'],
      dataNascimento: DateTime.parse(json['data_nascimento']),
      telefone: json['telefone'],
      cpf: json['cpf'],
      deviceToken: json['device_token'],
      ativo: json['ativo'] ?? true,
      nivelCognitivo: json['nivel_cognitivo'] ?? 'Normal',
      limitacoesAuditivas: json['limitacoes_auditivas'] ?? false,
      usaAparelhoAuditivo: json['usa_aparelho_auditivo'] ?? false,
      tomVoz: json['tom_voz'] ?? 'Normal',
      preferenciaHorario: json['preferencia_horario'] ?? 'Qualquer horário',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'data_nascimento': dataNascimento.toIso8601String(),
      'telefone': telefone,
      'cpf': cpf,
      'device_token': deviceToken,
      'ativo': ativo,
      'nivel_cognitivo': nivelCognitivo,
      'limitacoes_auditivas': limitacoesAuditivas,
      'usa_aparelho_auditivo': usaAparelhoAuditivo,
      'tom_voz': tomVoz,
      'preferencia_horario': preferenciaHorario,
    };
  }

  int get idade {
    final now = DateTime.now();
    int age = now.year - dataNascimento.year;
    if (now.month < dataNascimento.month ||
        (now.month == dataNascimento.month && now.day < dataNascimento.day)) {
      age--;
    }
    return age;
  }
}
