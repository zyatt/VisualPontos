import 'package:flutter/material.dart';
import '../models/lancamento_bonus.dart';
import '../services/lancamento_bonus_service.dart';

class LancamentoBonusProvider extends ChangeNotifier {
  final LancamentoBonusService _service = LancamentoBonusService();

  bool _carregando = false;
  String? _erro;
  int? _pontosAtual;
  double? _percentualAtual;
  double? _faixaPercentual;
  double? _valorBonus;
  List<LancamentoBonus> _historico = [];
  final List<ResumoMotivo> _resumoMotivos = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  int? get pontosAtual => _pontosAtual;
  double? get percentualAtual => _percentualAtual;
  double? get faixaPercentual => _faixaPercentual;
  double? get valorBonus => _valorBonus;
  List<LancamentoBonus> get historico => _historico;
  List<ResumoMotivo> get resumoMotivos => _resumoMotivos;

  Future<void> carregarPontuacao({
    required String token,
    required int colaboradorId,
  }) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final res = await _service.buscarPontuacao(
      token: token,
      colaboradorId: colaboradorId,
    );

    _carregando = false;
    if (res.success) {
      _pontosAtual = res.pontosAtual;
      _percentualAtual = res.percentualAtual;
      _faixaPercentual = res.faixaPercentual;
      _valorBonus = res.valorBonus;
    } else {
      _erro = res.message;
    }
    notifyListeners();
  }

  Future<void> carregarHistorico({
    required String token,
    required int colaboradorId,
    int? mes,
    int? ano,
  }) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final res = await _service.buscarHistorico(
      token: token,
      colaboradorId: colaboradorId,
      mes: mes,
      ano: ano,
    );

    _carregando = false;
    if (res.success) {
      _historico = res.lista ?? [];
    } else {
      _erro = res.message;
    }
    notifyListeners();
  }

  /// Busca a contagem de penalidades por motivo (usada na 1ª página do
  /// PDF). Retorna a lista já pronta, sem alterar o estado do provider
  /// (evita conflito quando o relatório geral chama isso para vários
  /// colaboradores em sequência).
  Future<List<ResumoMotivo>> buscarResumoMotivos({
    required String token,
    required int mes,
    required int ano,
    List<int>? colaboradorIds,
  }) async {
    final res = await _service.buscarResumoMotivos(
      token: token,
      mes: mes,
      ano: ano,
      colaboradorIds: colaboradorIds,
    );
    return res.success ? (res.resumoMotivos ?? []) : [];
  }

  /// Lança a penalidade e já atualiza o saldo de pontos local.
  /// Retorna null em caso de sucesso, ou uma mensagem de erro.
  ///
  /// Informe [subcategoriaId] para uma penalidade do catálogo de
  /// categorias/subcategorias, ou [pontos] para uma penalidade AVULSA
  /// (sem vínculo com o catálogo).
  Future<String?> lancarPenalidade({
    required String token,
    required int colaboradorId,
    int? subcategoriaId,
    int? pontos,
    required int motivoId,
    required String observacao,
    required String os,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.lancar(
      token: token,
      colaboradorId: colaboradorId,
      subcategoriaId: subcategoriaId,
      pontos: pontos,
      motivoId: motivoId,
      observacao: observacao,
      os: os,
    );

    _carregando = false;

    if (res.success) {
      _pontosAtual = res.pontosAtual;
      _percentualAtual = res.percentualAtual;
      _faixaPercentual = res.faixaPercentual;
      _valorBonus = res.valorBonus;
      if (res.lancamento != null) {
        _historico = [res.lancamento!, ..._historico];
      }
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível lançar a penalidade';
  }

  Future<String?> desfazerLancamento({
    required String token,
    required int id,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.desfazer(token: token, id: id);

    _carregando = false;

    if (res.success) {
      _pontosAtual = res.pontosAtual;
      _percentualAtual = res.percentualAtual;
      _faixaPercentual = res.faixaPercentual;
      _valorBonus = res.valorBonus;
      _historico = _historico.where((l) => l.id != id).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível desfazer o lançamento';
  }
}