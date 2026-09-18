import 'package:flutter/material.dart';
import '../models/checklist_comercial.dart';
import '../services/checklist_comercial_service.dart';

class ChecklistComercialProvider extends ChangeNotifier {
  final ChecklistComercialService _service = ChecklistComercialService();

  bool _carregando = false;
  String? _erro;
  List<ChecklistComercial> _historico = [];
  final List<ResumoRequisito> _resumoRequisitos = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<ChecklistComercial> get historico => _historico;
  List<ResumoRequisito> get resumoRequisitos => _resumoRequisitos;

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

  /// Não altera o estado do provider (mesmo padrão de
  /// [LancamentoBonusProvider.buscarResumoMotivos]) — usado tanto pelo
  /// PDF individual quanto pelo geral, sem conflitar entre si.
  Future<List<ResumoRequisito>> buscarResumoRequisitos({
    required String token,
    required int mes,
    required int ano,
    List<int>? colaboradorIds,
  }) async {
    final res = await _service.buscarResumoRequisitos(
      token: token,
      mes: mes,
      ano: ano,
      colaboradorIds: colaboradorIds,
    );
    return res.success ? (res.resumoRequisitos ?? []) : [];
  }

  /// Busca um checklist existente para a OS informada (para reabrir e
  /// editar). Retorna null se não encontrado ou em caso de erro.
  Future<ChecklistComercial?> buscarPorOs({
    required String token,
    required int colaboradorId,
    required String os,
  }) async {
    final res = await _service.buscarPorOs(
      token: token,
      colaboradorId: colaboradorId,
      os: os,
    );
    return res.success && res.osEncontrada ? res.checklist : null;
  }

  /// Cria um novo checklist. Retorna null em caso de sucesso, ou uma
  /// mensagem de erro.
  Future<String?> criar({
    required String token,
    required int colaboradorId,
    required String os,
    required List<ChecklistItem> itens,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criar(
      token: token,
      colaboradorId: colaboradorId,
      os: os,
      itens: itens,
    );

    _carregando = false;
    if (res.success && res.checklist != null) {
      _historico = [res.checklist!, ..._historico];
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível salvar o checklist';
  }

  /// Edita um checklist já existente (apenas ADMIN — validado também
  /// no backend). Retorna null em caso de sucesso, ou uma mensagem de
  /// erro.
  Future<String?> editar({
    required String token,
    required int id,
    required String os,
    required List<ChecklistItem> itens,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.editar(token: token, id: id, os: os, itens: itens);

    _carregando = false;
    if (res.success && res.checklist != null) {
      _historico = _historico.map((c) => c.id == id ? res.checklist! : c).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível atualizar o checklist';
  }
}