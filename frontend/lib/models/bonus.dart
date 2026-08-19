import 'categoria_bonus.dart';
import 'observacao_bonus.dart';

class Bonus {
  final int id;
  final String nome;
  final List<CategoriaBonus> categorias;
  final List<ObservacaoBonus> observacoes;

  Bonus({
    required this.id,
    required this.nome,
    required this.categorias,
    this.observacoes = const [],
  });

  int get totalPontos =>
      categorias.fold(0, (soma, c) => soma + c.totalPontos);

  factory Bonus.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categorias'];
    final rawObs = json['observacoes'];
    return Bonus(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      categorias: rawCats is List
          ? rawCats
              .map((e) => CategoriaBonus.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      observacoes: rawObs is List
          ? rawObs
              .map((e) => ObservacaoBonus.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'categorias': categorias.map((c) => c.toJson()).toList(),
        'observacoes': observacoes.map((o) => o.toJson()).toList(),
      };

  Bonus copyWith({
    String? nome,
    List<CategoriaBonus>? categorias,
    List<ObservacaoBonus>? observacoes,
  }) {
    return Bonus(
      id: id,
      nome: nome ?? this.nome,
      categorias: categorias ?? this.categorias,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}