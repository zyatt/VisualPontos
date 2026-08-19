class LancamentoBonus {
  final int id;
  final int colaboradorId;
  final int bonusId;
  final int categoriaId;
  final int subcategoriaId;
  final String categoriaNome;
  final String subcategoriaDesc;
  final int pontos; // sempre negativo
  final String observacao;
  final String os;
  final int usuarioId;
  final String usuarioNome;
  final DateTime criadoEm;

  LancamentoBonus({
    required this.id,
    required this.colaboradorId,
    required this.bonusId,
    required this.categoriaId,
    required this.subcategoriaId,
    required this.categoriaNome,
    required this.subcategoriaDesc,
    required this.pontos,
    required this.observacao,
    required this.os,
    required this.usuarioId,
    required this.usuarioNome,
    required this.criadoEm,
  });

  factory LancamentoBonus.fromJson(Map<String, dynamic> json) {
    return LancamentoBonus(
      id: json['id'] as int,
      colaboradorId: json['colaborador_id'] as int,
      bonusId: json['bonus_id'] as int,
      categoriaId: json['categoria_id'] as int,
      subcategoriaId: json['subcategoria_id'] as int,
      categoriaNome: json['categoria_nome'] as String? ?? '',
      subcategoriaDesc: json['subcategoria_desc'] as String? ?? '',
      pontos: json['pontos'] as int,
      observacao: json['observacao'] as String? ?? '',
      os: json['os'] as String? ?? '',
      usuarioId: json['usuario_id'] as int,
      usuarioNome: json['usuario_nome'] as String? ?? '',
      // formato "YYYY-MM-DD HH:MM:SS" vindo do MySQL
      criadoEm: DateTime.tryParse(
            (json['criado_em'] as String).replaceFirst(' ', 'T'),
          ) ??
          DateTime.now(),
    );
  }
}