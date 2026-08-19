class SubcategoriaBonus {
  final int id;
  final int categoriaId;
  final String descricao;
  final int pontos;

  SubcategoriaBonus({
    required this.id,
    required this.categoriaId,
    required this.descricao,
    required this.pontos,
  });

  factory SubcategoriaBonus.fromJson(Map<String, dynamic> json) {
    return SubcategoriaBonus(
      id: json['id'] as int,
      categoriaId: json['categoria_id'] as int,
      descricao: json['descricao'] as String? ?? '',
      pontos: int.tryParse(json['pontos'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria_id': categoriaId,
        'descricao': descricao,
        'pontos': pontos,
      };

  SubcategoriaBonus copyWith({String? descricao, int? pontos}) {
    return SubcategoriaBonus(
      id: id,
      categoriaId: categoriaId,
      descricao: descricao ?? this.descricao,
      pontos: pontos ?? this.pontos,
    );
  }
}