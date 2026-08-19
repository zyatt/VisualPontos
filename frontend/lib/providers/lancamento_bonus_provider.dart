import 'package:flutter/material.dart';
import '../models/lancamento_bonus.dart';
import '../services/lancamento_bonus_service.dart';

class LancamentoBonusProvider extends ChangeNotifier {
  final LancamentoBonusService _service = LancamentoBonusService();

  bool _carregando = false;
  String? _erro;
  int? _pontosAtual;
  List<LancamentoBonus> _historico = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  int? get pontosAtual => _pontosAtual;
  List<LancamentoBonus> get historico => _historico;

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

  /// Lança a penalidade e já atualiza o saldo de pontos local.
  /// Retorna null em caso de sucesso, ou uma mensagem de erro.
  Future<String?> lancarPenalidade({
    required String token,
    required int colaboradorId,
    required int subcategoriaId,
    required String observacao,
    required String os,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.lancar(
      token: token,
      colaboradorId: colaboradorId,
      subcategoriaId: subcategoriaId,
      observacao: observacao,
      os: os,
    );

    _carregando = false;

    if (res.success) {
      _pontosAtual = res.pontosAtual;
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
      _historico = _historico.where((l) => l.id != id).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível desfazer o lançamento';
  }
}