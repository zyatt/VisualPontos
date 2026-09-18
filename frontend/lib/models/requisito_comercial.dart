class RequisitoComercial {
  final int id;
  final String nome;
  final String descricao;

  RequisitoComercial({
    required this.id,
    required this.nome,
    required this.descricao,
  });

  factory RequisitoComercial.fromJson(Map<String, dynamic> json) {
    return RequisitoComercial(
      id: json['id'] as int,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String,
    );
  }
}