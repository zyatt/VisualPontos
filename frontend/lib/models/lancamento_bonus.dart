import '../config/api_config.dart';

class LancamentoBonus {
  final int id;
  final int colaboradorId;
  // Nulos quando o lançamento é uma penalidade AVULSA (sem categoria/
  // subcategoria do catálogo — pontos informados diretamente pelo usuário).
  final int? bonusId;
  final int? categoriaId;
  final int? subcategoriaId;
  final String? categoriaNome;
  final String? subcategoriaDesc;
  final int? motivoId;
  final String? motivoNome;
  final int pontos; // sempre negativo
  final String observacao;
  final String os;
  // Caminho relativo (ex.: "uploads/lancamentos_bonus/xxx.jpg") de uma
  // imagem opcional anexada ao lançamento. Null quando não há anexo.
  final String? imagemPath;
  final int usuarioId;
  final String usuarioNome;
  final DateTime criadoEm;

  /// true quando o lançamento não veio de uma subcategoria do catálogo.
  bool get ehAvulsa => subcategoriaId == null;

  /// URL completa da imagem anexada (quando houver), pronta para uso em
  /// Image.network. Null quando o lançamento não tem imagem.
  ///
  /// Usa [ApiConfig.baseUrl] (lido do .env) em vez de URL fixa, para que
  /// aponte corretamente tanto em produção quanto no ambiente local.
  String? get imagemUrl =>
      imagemPath != null ? '${ApiConfig.baseUrl}/$imagemPath' : null;

  LancamentoBonus({
    required this.id,
    required this.colaboradorId,
    this.bonusId,
    this.categoriaId,
    this.subcategoriaId,
    this.categoriaNome,
    this.subcategoriaDesc,
    this.motivoId,
    this.motivoNome,
    required this.pontos,
    required this.observacao,
    required this.os,
    this.imagemPath,
    required this.usuarioId,
    required this.usuarioNome,
    required this.criadoEm,
  });

  factory LancamentoBonus.fromJson(Map<String, dynamic> json) {
    return LancamentoBonus(
      id: json['id'] as int,
      colaboradorId: json['colaborador_id'] as int,
      bonusId: json['bonus_id'] as int?,
      categoriaId: json['categoria_id'] as int?,
      subcategoriaId: json['subcategoria_id'] as int?,
      categoriaNome: json['categoria_nome'] as String?,
      subcategoriaDesc: json['subcategoria_desc'] as String?,
      motivoId: json['motivo_id'] as int?,
      motivoNome: json['motivo_nome'] as String?,
      pontos: json['pontos'] as int,
      observacao: json['observacao'] as String? ?? '',
      os: json['os'] as String? ?? '',
      imagemPath: json['imagem_path'] as String?,
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