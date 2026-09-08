class FaixaBonus {
  final int id;
  final int bonusId;
  final int pontos;
  final double valor;

  FaixaBonus({
    required this.id,
    required this.bonusId,
    required this.pontos,
    required this.valor,
  });

  factory FaixaBonus.fromJson(Map<String, dynamic> json) {
    return FaixaBonus(
      id: json['id'] as int,
      bonusId: json['bonus_id'] as int,
      pontos: json['pontos'] as int,
      valor: (json['valor'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bonus_id': bonusId,
        'pontos': pontos,
        'valor': valor,
      };

  FaixaBonus copyWith({int? pontos, double? valor}) {
    return FaixaBonus(
      id: id,
      bonusId: bonusId,
      pontos: pontos ?? this.pontos,
      valor: valor ?? this.valor,
    );
  }
}