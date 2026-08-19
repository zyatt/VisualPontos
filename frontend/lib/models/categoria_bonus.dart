import 'subcategoria_bonus.dart';

class CategoriaBonus {
  final int id;
  final int bonusId;
  final String nome;
  final List<SubcategoriaBonus> subcategorias;

  CategoriaBonus({
    required this.id,
    required this.bonusId,
    required this.nome,
    required this.subcategorias,
  });

  int get totalPontos =>
      subcategorias.fold(0, (soma, s) => soma + s.pontos);

  factory CategoriaBonus.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subcategorias'];
    return CategoriaBonus(
      id: json['id'] as int,
      bonusId: json['bonus_id'] as int,
      nome: json['nome'] as String? ?? '',
      subcategorias: rawSubs is List
          ? rawSubs
              .map((e) => SubcategoriaBonus.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bonus_id': bonusId,
        'nome': nome,
        'subcategorias': subcategorias.map((s) => s.toJson()).toList(),
      };

  CategoriaBonus copyWith({String? nome, List<SubcategoriaBonus>? subcategorias}) {
    return CategoriaBonus(
      id: id,
      bonusId: bonusId,
      nome: nome ?? this.nome,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }
}