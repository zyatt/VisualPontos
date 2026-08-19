import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/lancamento_bonus.dart';

class LancamentoBonusResponse {
  final bool success;
  final String? message;
  final int? pontosAtual;
  final LancamentoBonus? lancamento;
  final List<LancamentoBonus>? lista;

  LancamentoBonusResponse({
    required this.success,
    this.message,
    this.pontosAtual,
    this.lancamento,
    this.lista,
  });
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
        message: 'Não foi possível conectar ao servidor. ($e)',
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
        message: 'Não foi possível conectar ao servidor. ($e)',
      );
    }
  }

  /// Lança uma nova penalidade para o colaborador.
  Future<LancamentoBonusResponse> lancar({
    required String token,
    required int colaboradorId,
    required int subcategoriaId,
    required String observacao,
    required String os,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/lancamentos_bonus.php?recurso=lancamento'),
            headers: _headers(token),
            body: jsonEncode({
              'colaborador_id': colaboradorId,
              'subcategoria_id': subcategoriaId,
              'observacao': observacao,
              'os': os,
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
        message: 'Não foi possível conectar ao servidor. ($e)',
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
        message: 'Não foi possível conectar ao servidor. ($e)',
      );
    }
  }
}