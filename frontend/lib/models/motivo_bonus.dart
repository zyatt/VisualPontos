class MotivoBonus {
  final int id;
  final String nome;

  MotivoBonus({
    required this.id,
    required this.nome,
  });

  factory MotivoBonus.fromJson(Map<String, dynamic> json) {
    return MotivoBonus(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
      };

  MotivoBonus copyWith({String? nome}) {
    return MotivoBonus(
      id: id,
      nome: nome ?? this.nome,
    );
  }
}