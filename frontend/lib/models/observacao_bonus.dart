import 'item_observacao_bonus.dart';

class ObservacaoBonus {
  final int id;
  final int bonusId;
  final String nome;
  final List<ItemObservacaoBonus> itens;

  ObservacaoBonus({
    required this.id,
    required this.bonusId,
    required this.nome,
    required this.itens,
  });

  factory ObservacaoBonus.fromJson(Map<String, dynamic> json) {
    final rawItens = json['itens'];
    return ObservacaoBonus(
      id: json['id'] as int,
      bonusId: json['bonus_id'] as int,
      nome: json['nome'] as String? ?? '',
      itens: rawItens is List
          ? rawItens
              .map((e) =>
                  ItemObservacaoBonus.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bonus_id': bonusId,
        'nome': nome,
        'itens': itens.map((i) => i.toJson()).toList(),
      };

  ObservacaoBonus copyWith({
    String? nome,
    List<ItemObservacaoBonus>? itens,
  }) {
    return ObservacaoBonus(
      id: id,
      bonusId: bonusId,
      nome: nome ?? this.nome,
      itens: itens ?? this.itens,
    );
  }
}