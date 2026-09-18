import 'package:flutter/material.dart';
import '../models/requisito_comercial.dart';
import '../services/requisito_comercial_service.dart';

class RequisitoComercialProvider extends ChangeNotifier {
  final RequisitoComercialService _service = RequisitoComercialService();

  bool _carregando = false;
  String? _erro;
  List<RequisitoComercial> _lista = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<RequisitoComercial> get lista => _lista;

  Future<void> carregar({required String token}) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final res = await _service.listar(token: token);

    _carregando = false;
    if (res.success) {
      _lista = res.lista ?? [];
    } else {
      _erro = res.message;
    }
    notifyListeners();
  }

  Future<String?> cadastrar({
    required String token,
    required String nome,
    required String descricao,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.cadastrar(token: token, nome: nome, descricao: descricao);

    _carregando = false;
    if (res.success && res.requisito != null) {
      // Mantém a ordem de cadastro (não reordena por nome): o novo
      // requisito é simplesmente adicionado ao final da lista, na
      // mesma ordem em que o backend devolve (ORDER BY id ASC).
      _lista = [..._lista, res.requisito!];
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível cadastrar o requisito';
  }

  Future<String?> editar({
    required String token,
    required int id,
    required String nome,
    required String descricao,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.editar(token: token, id: id, nome: nome, descricao: descricao);

    _carregando = false;
    if (res.success && res.requisito != null) {
      // Edita em-lugar, sem mudar a posição na lista (mantém a ordem
      // de cadastro mesmo depois de editar nome/descrição).
      _lista = _lista.map((r) => r.id == id ? res.requisito! : r).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar o requisito';
  }

  Future<String?> excluir({required String token, required int id}) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.excluir(token: token, id: id);

    _carregando = false;
    if (res.success) {
      _lista = _lista.where((r) => r.id != id).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir o requisito';
  }
}