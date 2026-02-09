/// Modelo de operador/técnico de campo
class Operator {
  final int id;
  final String nome;
  final String? cpf;
  final String telefone;
  final String? email;
  final String? cargo;

  Operator({
    required this.id,
    required this.nome,
    this.cpf,
    required this.telefone,
    this.email,
    this.cargo,
  });

  factory Operator.fromJson(Map<String, dynamic> json) {
    return Operator(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] as String? ?? '',
      cpf: json['cpf'] as String?,
      telefone: json['telefone'] as String? ?? '',
      email: json['email'] as String?,
      cargo: json['cargo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'cpf': cpf,
    'telefone': telefone,
    'email': email,
    'cargo': cargo,
  };
}
