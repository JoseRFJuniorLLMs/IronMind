/// Model para Contato de Emergencia
class ContatoEmergencia {
  final int id;
  final int idosoId;
  final String nome;
  final String telefone;
  final String? email;
  final String parentesco; // filho, filha, neto, cuidador, etc
  final int prioridade; // 1 = principal, 2 = secundario
  final bool recebeAlertas;
  final bool recebeRelatorios;
  final List<String> canaisHabilitados; // push, sms, whatsapp, email, call
  final String? horarioNaoPerturbeInicio; // "22:00"
  final String? horarioNaoPerturbeEnd; // "07:00"
  final bool ativo;
  final DateTime? ultimoContato;
  final String? fotoUrl;

  ContatoEmergencia({
    required this.id,
    required this.idosoId,
    required this.nome,
    required this.telefone,
    this.email,
    required this.parentesco,
    this.prioridade = 1,
    this.recebeAlertas = true,
    this.recebeRelatorios = false,
    this.canaisHabilitados = const ['push', 'sms', 'whatsapp'],
    this.horarioNaoPerturbeInicio,
    this.horarioNaoPerturbeEnd,
    this.ativo = true,
    this.ultimoContato,
    this.fotoUrl,
  });

  factory ContatoEmergencia.fromJson(Map<String, dynamic> json) {
    return ContatoEmergencia(
      id: json['id'] ?? 0,
      idosoId: json['idoso_id'] ?? 0,
      nome: json['nome'] ?? '',
      telefone: json['telefone'] ?? '',
      email: json['email'],
      parentesco: json['parentesco'] ?? 'familiar',
      prioridade: json['prioridade'] ?? 1,
      recebeAlertas: json['recebe_alertas'] ?? true,
      recebeRelatorios: json['recebe_relatorios'] ?? false,
      canaisHabilitados: (json['canais_habilitados'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['push', 'sms', 'whatsapp'],
      horarioNaoPerturbeInicio: json['horario_nao_perturbe_inicio'],
      horarioNaoPerturbeEnd: json['horario_nao_perturbe_fim'],
      ativo: json['ativo'] ?? true,
      ultimoContato: json['ultimo_contato'] != null
          ? DateTime.parse(json['ultimo_contato'])
          : null,
      fotoUrl: json['foto_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idoso_id': idosoId,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'parentesco': parentesco,
      'prioridade': prioridade,
      'recebe_alertas': recebeAlertas,
      'recebe_relatorios': recebeRelatorios,
      'canais_habilitados': canaisHabilitados,
      'horario_nao_perturbe_inicio': horarioNaoPerturbeInicio,
      'horario_nao_perturbe_fim': horarioNaoPerturbeEnd,
      'ativo': ativo,
      'ultimo_contato': ultimoContato?.toIso8601String(),
      'foto_url': fotoUrl,
    };
  }

  /// Verifica se esta em horario de nao perturbe
  bool get emHorarioNaoPerturbe {
    if (horarioNaoPerturbeInicio == null || horarioNaoPerturbeEnd == null) {
      return false;
    }

    final now = DateTime.now();
    final horaAtual = now.hour * 60 + now.minute;

    final partsInicio = horarioNaoPerturbeInicio!.split(':');
    final partsFim = horarioNaoPerturbeEnd!.split(':');

    if (partsInicio.length != 2 || partsFim.length != 2) return false;

    final inicio =
        int.parse(partsInicio[0]) * 60 + int.parse(partsInicio[1]);
    final fim = int.parse(partsFim[0]) * 60 + int.parse(partsFim[1]);

    // Se o horario de fim e menor que o inicio, cruza meia-noite
    if (fim < inicio) {
      return horaAtual >= inicio || horaAtual < fim;
    }

    return horaAtual >= inicio && horaAtual < fim;
  }

  /// Icone baseado no parentesco
  String get iconeParentesco {
    switch (parentesco.toLowerCase()) {
      case 'filho':
      case 'filha':
        return 'child';
      case 'neto':
      case 'neta':
        return 'child_care';
      case 'esposo':
      case 'esposa':
        return 'favorite';
      case 'irmao':
      case 'irma':
        return 'people';
      case 'cuidador':
      case 'cuidadora':
        return 'medical_services';
      case 'medico':
      case 'medica':
        return 'local_hospital';
      default:
        return 'person';
    }
  }

  /// Copia com alteracoes
  ContatoEmergencia copyWith({
    int? id,
    int? idosoId,
    String? nome,
    String? telefone,
    String? email,
    String? parentesco,
    int? prioridade,
    bool? recebeAlertas,
    bool? recebeRelatorios,
    List<String>? canaisHabilitados,
    String? horarioNaoPerturbeInicio,
    String? horarioNaoPerturbeEnd,
    bool? ativo,
    DateTime? ultimoContato,
    String? fotoUrl,
  }) {
    return ContatoEmergencia(
      id: id ?? this.id,
      idosoId: idosoId ?? this.idosoId,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      parentesco: parentesco ?? this.parentesco,
      prioridade: prioridade ?? this.prioridade,
      recebeAlertas: recebeAlertas ?? this.recebeAlertas,
      recebeRelatorios: recebeRelatorios ?? this.recebeRelatorios,
      canaisHabilitados: canaisHabilitados ?? this.canaisHabilitados,
      horarioNaoPerturbeInicio:
          horarioNaoPerturbeInicio ?? this.horarioNaoPerturbeInicio,
      horarioNaoPerturbeEnd:
          horarioNaoPerturbeEnd ?? this.horarioNaoPerturbeEnd,
      ativo: ativo ?? this.ativo,
      ultimoContato: ultimoContato ?? this.ultimoContato,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}

/// Lista de opcoes de parentesco
class ParentescoOpcoes {
  static const List<String> opcoes = [
    'Filho(a)',
    'Neto(a)',
    'Esposo(a)',
    'Irmao(a)',
    'Sobrinho(a)',
    'Primo(a)',
    'Amigo(a)',
    'Vizinho(a)',
    'Cuidador(a)',
    'Medico(a)',
    'Enfermeiro(a)',
    'Outro',
  ];
}
