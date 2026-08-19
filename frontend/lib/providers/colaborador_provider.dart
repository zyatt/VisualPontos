import 'package:flutter/material.dart';
import '../models/colaborador.dart';
import '../services/colaborador_service.dart';

class ColaboradorProvider extends ChangeNotifier {
  final ColaboradorService _service = ColaboradorService();

  bool _carregando = false;
  String? _erro;
  List<Colaborador> _colaboradores = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<Colaborador> get colaboradores => _colaboradores;

  /// Cadastra um novo colaborador (nome + setor + bônus opcional).
  /// Retorna uma mensagem de erro em caso de falha, ou null se OK.
  Future<String?> cadastrarColaborador({
    required String token,
    required String nome,
    required String setor,
    int? bonusId,
  }) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final result = await _service.cadastrar(
      token: token,
      nome: nome,
      setor: setor,
      bonusId: bonusId,
    );

    _carregando = false;

    if (result.success && result.colaborador != null) {
      _colaboradores = [..._colaboradores, result.colaborador!]
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível cadastrar o colaborador';
  }

  Future<String?> carregarColaboradores({required String token}) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final result = await _service.listar(token: token);

    _carregando = false;

    if (result.success) {
      _colaboradores = result.colaboradores ?? [];
      notifyListeners();
      return null;
    }

    _erro = result.message;
    notifyListeners();
    return _erro;
  }

  /// [limparBonus] deve ser `true` quando o usuário removeu explicitamente
  /// o bônus vinculado ao colaborador.
  Future<String?> editarColaborador({
    required String token,
    required int id,
    required String nome,
    required String setor,
    int? bonusId,
    bool limparBonus = false,
  }) async {
    _carregando = true;
    notifyListeners();

    final result = await _service.editar(
      token: token,
      id: id,
      nome: nome,
      setor: setor,
      bonusId: bonusId,
      limparBonus: limparBonus,
    );

    _carregando = false;

    if (result.success && result.colaborador != null) {
      _colaboradores = _colaboradores
          .map((c) => c.id == id ? result.colaborador! : c)
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível editar o colaborador';
  }

  /// Atualiza a pontuação inicial (base) do colaborador no mês.
  Future<String?> editarPontosIniciais({
    required String token,
    required Colaborador colaborador,
    required int pontosIniciais,
  }) async {
    _carregando = true;
    notifyListeners();

    final result = await _service.editarPontosIniciais(
      token: token,
      id: colaborador.id,
      nome: colaborador.nome,
      setor: colaborador.setor,
      bonusId: colaborador.bonusId,
      pontosIniciais: pontosIniciais,
    );

    _carregando = false;

    if (result.success && result.colaborador != null) {
      _colaboradores = _colaboradores
          .map((c) => c.id == colaborador.id ? result.colaborador! : c)
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível atualizar a pontuação inicial';
  }

  Future<String?> excluirColaborador({
    required String token,
    required int id,
  }) async {
    _carregando = true;
    notifyListeners();

    final result = await _service.excluir(token: token, id: id);

    _carregando = false;

    if (result.success) {
      _colaboradores = _colaboradores.where((c) => c.id != id).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível excluir o colaborador';
  }
}