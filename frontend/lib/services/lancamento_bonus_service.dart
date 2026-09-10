import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/lancamento_bonus.dart';

class LancamentoBonusResponse {
  final bool success;
  final String? message;
  final int? pontosAtual;
  final double? percentualAtual;
  final double? faixaPercentual;
  final double? valorBonus;
  final LancamentoBonus? lancamento;
  final List<LancamentoBonus>? lista;
  final List<ResumoMotivo>? resumoMotivos;
  // Preenchidos apenas pela verificação de OS recente.
  final bool osEncontrada;
  final OsRecente? osRecente;
  // Preenchido apenas pelo upload de imagem.
  final String? imagemPath;

  LancamentoBonusResponse({
    required this.success,
    this.message,
    this.pontosAtual,
    this.percentualAtual,
    this.faixaPercentual,
    this.valorBonus,
    this.lancamento,
    this.lista,
    this.resumoMotivos,
    this.osEncontrada = false,
    this.osRecente,
    this.imagemPath,
  });
}

/// Dados do lançamento anterior encontrado com a mesma OS (últimas 24h).
class OsRecente {
  final DateTime criadoEm;
  final String usuarioNome;
  final String? motivoNome;
  final int pontos;

  OsRecente({
    required this.criadoEm,
    required this.usuarioNome,
    this.motivoNome,
    required this.pontos,
  });

  factory OsRecente.fromJson(Map<String, dynamic> json) {
    return OsRecente(
      criadoEm: DateTime.parse(json['criado_em'] as String),
      usuarioNome: json['usuario_nome'] as String? ?? '',
      motivoNome: json['motivo_nome'] as String?,
      pontos: json['pontos'] as int,
    );
  }
}

/// Contagem de penalidades lançadas para um motivo em um mês/ano.
class ResumoMotivo {
  final int motivoId;
  final String motivoNome;
  final int total;

  ResumoMotivo({
    required this.motivoId,
    required this.motivoNome,
    required this.total,
  });

  factory ResumoMotivo.fromJson(Map<String, dynamic> json) {
    return ResumoMotivo(
      motivoId: json['motivo_id'] as int,
      motivoNome: json['motivo_nome'] as String? ?? '',
      total: json['total'] as int,
    );
  }
}

class LancamentoBonusService {
  static const String _base = 'https://visualpremium.com.br/api';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Retorna os pontos atuais do colaborador no mês/ano informado
  /// (ou no mês/ano corrente, se omitidos).
  Future<LancamentoBonusResponse> buscarPontuacao({
    required String token,
    required int colaboradorId,
    int? mes,
    int? ano,
  }) async {
    try {
      final query = {
        'recurso': 'pontuacao',
        'colaborador_id': '$colaboradorId',
        if (mes != null) 'mes': '$mes',
        if (ano != null) 'ano': '$ano',
      };
      final uri = Uri.parse('$_base/lancamentos_bonus.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.buscarPontuacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final pontuacao = data['pontuacao'] as Map<String, dynamic>;
        return LancamentoBonusResponse(
          success: true,
          pontosAtual: pontuacao['pontos_atual'] as int,
          percentualAtual: (pontuacao['percentual_atual'] as num?)?.toDouble(),
          faixaPercentual: (pontuacao['faixa_percentual'] as num?)?.toDouble(),
          valorBonus: (pontuacao['valor_bonus'] as num?)?.toDouble(),
        );
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar pontuação',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.buscarPontuacao] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Histórico de penalidades do colaborador (opcionalmente filtrado por mês/ano).
  Future<LancamentoBonusResponse> buscarHistorico({
    required String token,
    required int colaboradorId,
    int? mes,
    int? ano,
  }) async {
    try {
      final query = {
        'recurso': 'historico',
        'colaborador_id': '$colaboradorId',
        if (mes != null) 'mes': '$mes',
        if (ano != null) 'ano': '$ano',
      };
      final uri = Uri.parse('$_base/lancamentos_bonus.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.buscarHistorico] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final lista = (data['lancamentos'] as List)
            .map((e) => LancamentoBonus.fromJson(e as Map<String, dynamic>))
            .toList();
        return LancamentoBonusResponse(success: true, lista: lista);
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar histórico',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.buscarHistorico] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Contagem de penalidades por motivo, num mês/ano. Se [colaboradorIds]
  /// for informado, restringe a esses colaboradores (usado no relatório
  /// geral); se omitido, soma de todos.
  Future<LancamentoBonusResponse> buscarResumoMotivos({
    required String token,
    required int mes,
    required int ano,
    List<int>? colaboradorIds,
  }) async {
    try {
      final query = {
        'recurso': 'resumo_motivos',
        'mes': '$mes',
        'ano': '$ano',
        if (colaboradorIds != null && colaboradorIds.isNotEmpty)
          'colaborador_ids': colaboradorIds.join(','),
      };
      final uri = Uri.parse('$_base/lancamentos_bonus.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.buscarResumoMotivos] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final resumo = (data['resumo'] as List)
            .map((e) => ResumoMotivo.fromJson(e as Map<String, dynamic>))
            .toList();
        return LancamentoBonusResponse(success: true, resumoMotivos: resumo);
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar resumo de motivos',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.buscarResumoMotivos] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Verifica se o colaborador já teve uma penalidade lançada com a mesma
  /// OS nas últimas 24 horas. Usado para avisar o usuário antes de lançar
  /// uma possível duplicidade (ele ainda pode confirmar e prosseguir).
  Future<LancamentoBonusResponse> verificarOsRecente({
    required String token,
    required int colaboradorId,
    required String os,
  }) async {
    try {
      final query = {
        'recurso': 'verificar_os',
        'colaborador_id': '$colaboradorId',
        'os': os,
      };
      final uri = Uri.parse('$_base/lancamentos_bonus.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.verificarOsRecente] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final encontrado = data['encontrado'] == true;
        final lancamentoJson = data['lancamento'] as Map<String, dynamic>?;
        return LancamentoBonusResponse(
          success: true,
          osEncontrada: encontrado,
          osRecente: lancamentoJson != null
              ? OsRecente.fromJson(lancamentoJson)
              : null,
        );
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao verificar a OS',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.verificarOsRecente] ERRO: $e\n$st');
      // Falha de rede aqui não deve travar o fluxo de lançamento: apenas
      // segue sem o aviso (não há dado suficiente para checar).
      return LancamentoBonusResponse(success: true, osEncontrada: false);
    }
  }

  /// Envia uma imagem (foto ou arquivo escolhido pelo usuário) para o
  /// servidor antes de lançar a penalidade. Retorna o caminho relativo
  /// (imagemPath) em caso de sucesso, ou null em caso de falha — o
  /// chamador decide se quer bloquear o lançamento ou seguir sem a
  /// imagem quando o upload falhar.
  Future<LancamentoBonusResponse> uploadImagem({
    required String token,
    required File arquivo,
  }) async {
    try {
      final uri = Uri.parse('$_base/upload_imagem.php');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('imagem', arquivo.path));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamedResponse);
      developer.log('[LancamentoBonusService.uploadImagem] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return LancamentoBonusResponse(
          success: true,
          imagemPath: data['imagem_path'] as String?,
        );
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível enviar a imagem',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.uploadImagem] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível enviar a imagem. Verifique sua internet.',
      );
    }
  }

  /// Lança uma nova penalidade para o colaborador.
  ///
  /// Informe [subcategoriaId] para uma penalidade vinculada ao catálogo
  /// de categorias/subcategorias (os pontos são deduzidos no backend a
  /// partir da subcategoria). Para uma penalidade AVULSA (sem categoria
  /// do catálogo), omita [subcategoriaId] e informe [pontos] diretamente.
  ///
  /// [imagemPath] é o caminho relativo já retornado por [uploadImagem]
  /// (opcional — omita quando não há imagem anexada).
  Future<LancamentoBonusResponse> lancar({
    required String token,
    required int colaboradorId,
    int? subcategoriaId,
    int? pontos,
    required int motivoId,
    required String observacao,
    required String os,
    String? imagemPath,
  }) async {
    assert(
      subcategoriaId != null || pontos != null,
      'Informe subcategoriaId (catálogo) ou pontos (penalidade avulsa)',
    );
    try {
      final res = await http
          .post(
            Uri.parse('$_base/lancamentos_bonus.php?recurso=lancamento'),
            headers: _headers(token),
            body: jsonEncode({
              'colaborador_id': colaboradorId,
              if (subcategoriaId != null) 'subcategoria_id': subcategoriaId,
              if (pontos != null) 'pontos': pontos,
              'motivo_id': motivoId,
              'observacao': observacao,
              'os': os,
              if (imagemPath != null) 'imagem_path': imagemPath,
            }),
          )
          .timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.lancar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return LancamentoBonusResponse(
          success: true,
          lancamento:
              LancamentoBonus.fromJson(data['lancamento'] as Map<String, dynamic>),
          pontosAtual: data['pontos_atual'] as int,
          percentualAtual: (data['percentual_atual'] as num?)?.toDouble(),
          faixaPercentual: (data['faixa_percentual'] as num?)?.toDouble(),
          valorBonus: (data['valor_bonus'] as num?)?.toDouble(),
        );
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível lançar a penalidade',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.lancar] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Desfaz (soft delete) uma penalidade lançada por engano.
  Future<LancamentoBonusResponse> desfazer({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/lancamentos_bonus.php?recurso=lancamento&id=$id'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      developer.log('[LancamentoBonusService.desfazer] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return LancamentoBonusResponse(
          success: true,
          pontosAtual: data['pontos_atual'] as int,
          percentualAtual: (data['percentual_atual'] as num?)?.toDouble(),
          faixaPercentual: (data['faixa_percentual'] as num?)?.toDouble(),
          valorBonus: (data['valor_bonus'] as num?)?.toDouble(),
        );
      }
      return LancamentoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível desfazer o lançamento',
      );
    } catch (e, st) {
      developer.log('[LancamentoBonusService.desfazer] ERRO: $e\n$st');
      return LancamentoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}