import 'package:flutter/material.dart';
import '../models/motivo_bonus.dart';
import '../services/motivo_bonus_service.dart';

class MotivoBonusProvider extends ChangeNotifier {
  final MotivoBonusService _service = MotivoBonusService();

  bool _carregando = false;
  String? _erro;
  List<MotivoBonus> _lista = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<MotivoBonus> get lista => _lista;

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

  Future<String?> criar({required String token, required String nome}) async {
    final res = await _service.criar(token: token, nome: nome);
    if (res.success && res.motivo != null) {
      _lista = [..._lista, res.motivo!]
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }
    return res.message ?? 'Não foi possível criar o motivo';
  }

  Future<String?> editar({
    required String token,
    required int id,
    required String nome,
  }) async {
    final res = await _service.editar(token: token, id: id, nome: nome);
    if (res.success && res.motivo != null) {
      _lista = _lista.map((m) => m.id == id ? res.motivo! : m).toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }
    return res.message ?? 'Não foi possível editar o motivo';
  }

  Future<String?> excluir({required String token, required int id}) async {
    final res = await _service.excluir(token: token, id: id);
    if (res.success) {
      _lista = _lista.where((m) => m.id != id).toList();
      notifyListeners();
      return null;
    }
    return res.message ?? 'Não foi possível excluir o motivo';
  }
}