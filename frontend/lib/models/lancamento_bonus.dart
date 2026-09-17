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
  // Caminhos relativos (ex.: "uploads/lancamentos_bonus/xxx.jpg") das
  // imagens anexadas ao lançamento. Lista vazia quando não há anexos.
  final List<String> imagens;
  final int usuarioId;
  final String usuarioNome;
  final DateTime criadoEm;

  /// true quando o lançamento não veio de uma subcategoria do catálogo.
  bool get ehAvulsa => subcategoriaId == null;

  /// URLs completas das imagens anexadas, prontas para uso em
  /// Image.network. Lista vazia quando o lançamento não tem imagens.
  ///
  /// Usa [ApiConfig.baseUrl] (lido do .env) em vez de URL fixa, para que
  /// aponte corretamente tanto em produção quanto no ambiente local.
  List<String> get imagensUrl =>
      imagens.map((path) => '${ApiConfig.baseUrl}/$path').toList();

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
    this.imagens = const [],
    required this.usuarioId,
    required this.usuarioNome,
    required this.criadoEm,
  });

  factory LancamentoBonus.fromJson(Map<String, dynamic> json) {
    // O backend retorna `imagens` (lista) desde a migração multi-imagem.
    // Mantemos leitura do campo antigo `imagem_path` (string única) como
    // fallback, para não quebrar contra uma API ainda não atualizada.
    final imagensJson = json['imagens'] as List?;
    final imagens = imagensJson != null
        ? imagensJson.map((e) => e as String).toList()
        : (json['imagem_path'] != null
            ? [json['imagem_path'] as String]
            : <String>[]);

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
      imagens: imagens,
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