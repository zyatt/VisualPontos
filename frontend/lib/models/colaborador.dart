class Colaborador {
  final int id;
  final String nome;
  final String setor;
  final int? bonusId;
  final String? bonusNome;
  final int pontosIniciais;

  Colaborador({
    required this.id,
    required this.nome,
    required this.setor,
    this.bonusId,
    this.bonusNome,
    this.pontosIniciais = 100,
  });

  factory Colaborador.fromJson(Map<String, dynamic> json) {
    return Colaborador(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      setor: json['setor'] as String? ?? '',
      bonusId: json['bonus_id'] as int?,
      bonusNome: json['bonus_nome'] as String?,
      pontosIniciais: json['pontos_iniciais'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'setor': setor,
        'bonus_id': bonusId,
        'bonus_nome': bonusNome,
        'pontos_iniciais': pontosIniciais,
      };

  Colaborador copyWith({
    String? nome,
    String? setor,
    int? bonusId,
    String? bonusNome,
    bool limparBonus = false,
    int? pontosIniciais,
  }) {
    return Colaborador(
      id: id,
      nome: nome ?? this.nome,
      setor: setor ?? this.setor,
      bonusId: limparBonus ? null : (bonusId ?? this.bonusId),
      bonusNome: limparBonus ? null : (bonusNome ?? this.bonusNome),
      pontosIniciais: pontosIniciais ?? this.pontosIniciais,
    );
  }
}