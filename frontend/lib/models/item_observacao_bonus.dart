class ItemObservacaoBonus {
  final int id;
  final int observacaoId;
  final String descricao;

  ItemObservacaoBonus({
    required this.id,
    required this.observacaoId,
    required this.descricao,
  });

  factory ItemObservacaoBonus.fromJson(Map<String, dynamic> json) {
    return ItemObservacaoBonus(
      id: json['id'] as int,
      observacaoId: json['observacao_id'] as int,
      descricao: json['descricao'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'observacao_id': observacaoId,
        'descricao': descricao,
      };

  ItemObservacaoBonus copyWith({String? descricao}) {
    return ItemObservacaoBonus(
      id: id,
      observacaoId: observacaoId,
      descricao: descricao ?? this.descricao,
    );
  }
}