/// Um item do checklist: o snapshot do requisito no momento em que o
/// checklist foi lançado (nome/descrição não mudam retroativamente se
/// o requisito for editado depois), junto do resultado da conferência.
class ChecklistItem {
  final int id;
  final int requisitoId;
  final String requisitoNome;
  final String requisitoDescricao;
  final bool conforme;
  final String? observacao;

  ChecklistItem({
    required this.id,
    required this.requisitoId,
    required this.requisitoNome,
    required this.requisitoDescricao,
    required this.conforme,
    this.observacao,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as int,
      requisitoId: json['requisito_id'] as int,
      requisitoNome: json['requisito_nome'] as String,
      requisitoDescricao: json['requisito_descricao'] as String,
      conforme: json['conforme'] as bool,
      observacao: json['observacao'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'requisito_id': requisitoId,
        'conforme': conforme,
        if (!conforme) 'observacao': observacao,
      };
}

/// Um checklist = uma OS conferida por um colaborador comercial, com o
/// status de cada requisito no momento da conferência.
class ChecklistComercial {
  final int id;
  final int colaboradorId;
  final String os;
  final int usuarioId;
  final String usuarioNome;
  final List<ChecklistItem> itens;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  ChecklistComercial({
    required this.id,
    required this.colaboradorId,
    required this.os,
    required this.usuarioId,
    required this.usuarioNome,
    required this.itens,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  /// Requisitos marcados como não realizados neste checklist.
  List<ChecklistItem> get itensNaoConformes =>
      itens.where((i) => !i.conforme).toList();

  /// true quando todos os requisitos foram cumpridos.
  bool get tudoConforme => itensNaoConformes.isEmpty;

  factory ChecklistComercial.fromJson(Map<String, dynamic> json) {
    final itensJson = json['itens'] as List? ?? [];
    return ChecklistComercial(
      id: json['id'] as int,
      colaboradorId: json['colaborador_id'] as int,
      os: json['os'] as String,
      usuarioId: json['usuario_id'] as int,
      usuarioNome: json['usuario_nome'] as String? ?? '',
      itens: itensJson
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      // formato "YYYY-MM-DD HH:MM:SS" vindo do MySQL
      criadoEm: DateTime.tryParse(
            (json['criado_em'] as String).replaceFirst(' ', 'T'),
          ) ??
          DateTime.now(),
      atualizadoEm: DateTime.tryParse(
            (json['atualizado_em'] as String).replaceFirst(' ', 'T'),
          ) ??
          DateTime.now(),
    );
  }
}