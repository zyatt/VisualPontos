import 'package:flutter/material.dart';
import '../models/bonus.dart';
import '../services/bonus_service.dart';

class BonusProvider extends ChangeNotifier {
  final BonusService _service = BonusService();

  bool _carregando = false;
  String? _erro;
  List<Bonus> _lista = [];

  // Bônus atualmente aberto na tela de detalhe
  Bonus? _bonusAtual;

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<Bonus> get lista => _lista;
  Bonus? get bonusAtual => _bonusAtual;

  // ─── BÔNUS ──────────────────────────────────────────────────────────────

  Future<String?> carregar({required String token}) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final res = await _service.listar(token: token);
    _carregando = false;

    if (res.success) {
      _lista = res.lista ?? [];
      notifyListeners();
      return null;
    }

    _erro = res.message;
    notifyListeners();
    return _erro;
  }

  Future<String?> carregarDetalhe(
      {required String token, required int id}) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.buscar(token: token, id: id);
    _carregando = false;

    if (res.success && res.bonus != null) {
      _bonusAtual = res.bonus;
      // Atualiza também na lista principal
      _lista = _lista.map((b) => b.id == id ? res.bonus! : b).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Erro ao carregar bônus';
  }

  Future<String?> criar({required String token, required String nome}) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criar(token: token, nome: nome);
    _carregando = false;

    if (res.success && res.bonus != null) {
      _lista = [..._lista, res.bonus!]
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível criar o bônus';
  }

  Future<String?> editarNome({
    required String token,
    required int id,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.editarBonus(token: token, id: id, nome: nome);
    _carregando = false;

    if (res.success && res.bonus != null) {
      _lista = _lista.map((b) => b.id == id ? res.bonus! : b).toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      if (_bonusAtual?.id == id) _bonusAtual = res.bonus;
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar o bônus';
  }

  Future<String?> excluir({required String token, required int id}) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.excluirBonus(token: token, id: id);
    _carregando = false;

    if (res.success) {
      _lista = _lista.where((b) => b.id != id).toList();
      if (_bonusAtual?.id == id) _bonusAtual = null;
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir o bônus';
  }

  Future<String?> duplicar({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.duplicar(token: token, bonusId: bonusId, nome: nome);
    _carregando = false;

    if (res.success && res.bonus != null) {
      _lista = [..._lista, res.bonus!]
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível duplicar o bônus';
  }

  // ─── CATEGORIA ──────────────────────────────────────────────────────────

  Future<String?> criarCategoria({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criarCategoria(
        token: token, bonusId: bonusId, nome: nome);
    _carregando = false;

    if (res.success && res.categoria != null) {
      _atualizarBonusLocal(bonusId, (b) {
        final novasCats = [...b.categorias, res.categoria!];
        return b.copyWith(categorias: novasCats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível criar a categoria';
  }

  Future<String?> editarCategoria({
    required String token,
    required int bonusId,
    required int categoriaId,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.editarCategoria(token: token, id: categoriaId, nome: nome);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final cats = b.categorias.map((c) {
          if (c.id != categoriaId) return c;
          return c.copyWith(nome: nome);
        }).toList();
        return b.copyWith(categorias: cats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar a categoria';
  }

  Future<String?> excluirCategoria({
    required String token,
    required int bonusId,
    required int categoriaId,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.excluirCategoria(token: token, id: categoriaId);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final cats = b.categorias.where((c) => c.id != categoriaId).toList();
        return b.copyWith(categorias: cats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir a categoria';
  }

  // ─── SUBCATEGORIA ──────────────────────────────────────────────────────────

  Future<String?> criarSubcategoria({
    required String token,
    required int bonusId,
    required int categoriaId,
    required String descricao,
    required int pontos,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criarSubcategoria(
      token: token,
      categoriaId: categoriaId,
      descricao: descricao,
      pontos: pontos,
    );
    _carregando = false;

    if (res.success && res.subcategoria != null) {
      _atualizarBonusLocal(bonusId, (b) {
        final cats = b.categorias.map((c) {
          if (c.id != categoriaId) return c;
          final subs = [...c.subcategorias, res.subcategoria!];
          return c.copyWith(subcategorias: subs);
        }).toList();
        return b.copyWith(categorias: cats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível criar a subcategoria';
  }

  Future<String?> editarSubcategoria({
    required String token,
    required int bonusId,
    required int categoriaId,
    required int subcategoriaId,
    required String descricao,
    required int pontos,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.editarSubcategoria(
      token: token,
      id: subcategoriaId,
      descricao: descricao,
      pontos: pontos,
    );
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final cats = b.categorias.map((c) {
          if (c.id != categoriaId) return c;
          final subs = c.subcategorias.map((s) {
            if (s.id != subcategoriaId) return s;
            return s.copyWith(descricao: descricao, pontos: pontos);
          }).toList();
          return c.copyWith(subcategorias: subs);
        }).toList();
        return b.copyWith(categorias: cats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar a subcategoria';
  }

  Future<String?> excluirSubcategoria({
    required String token,
    required int bonusId,
    required int categoriaId,
    required int subcategoriaId,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.excluirSubcategoria(token: token, id: subcategoriaId);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final cats = b.categorias.map((c) {
          if (c.id != categoriaId) return c;
          final subs = c.subcategorias
              .where((s) => s.id != subcategoriaId)
              .toList();
          return c.copyWith(subcategorias: subs);
        }).toList();
        return b.copyWith(categorias: cats);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir a subcategoria';
  }

  // ─── OBSERVAÇÃO ─────────────────────────────────────────────────────────

  Future<String?> criarObservacao({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criarObservacao(
        token: token, bonusId: bonusId, nome: nome);
    _carregando = false;

    if (res.success && res.observacao != null) {
      _atualizarBonusLocal(bonusId, (b) {
        final novasObs = [...b.observacoes, res.observacao!];
        return b.copyWith(observacoes: novasObs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível criar a observação';
  }

  Future<String?> editarObservacao({
    required String token,
    required int bonusId,
    required int observacaoId,
    required String nome,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.editarObservacao(token: token, id: observacaoId, nome: nome);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final obs = b.observacoes.map((o) {
          if (o.id != observacaoId) return o;
          return o.copyWith(nome: nome);
        }).toList();
        return b.copyWith(observacoes: obs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar a observação';
  }

  Future<String?> excluirObservacao({
    required String token,
    required int bonusId,
    required int observacaoId,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.excluirObservacao(token: token, id: observacaoId);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final obs =
            b.observacoes.where((o) => o.id != observacaoId).toList();
        return b.copyWith(observacoes: obs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir a observação';
  }

  // ─── ITEM DE OBSERVAÇÃO ─────────────────────────────────────────────────

  Future<String?> criarItemObservacao({
    required String token,
    required int bonusId,
    required int observacaoId,
    required String descricao,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.criarItemObservacao(
      token: token,
      observacaoId: observacaoId,
      descricao: descricao,
    );
    _carregando = false;

    if (res.success && res.item != null) {
      _atualizarBonusLocal(bonusId, (b) {
        final obs = b.observacoes.map((o) {
          if (o.id != observacaoId) return o;
          final itens = [...o.itens, res.item!];
          return o.copyWith(itens: itens);
        }).toList();
        return b.copyWith(observacoes: obs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível criar o item da observação';
  }

  Future<String?> editarItemObservacao({
    required String token,
    required int bonusId,
    required int observacaoId,
    required int itemId,
    required String descricao,
  }) async {
    _carregando = true;
    notifyListeners();

    final res = await _service.editarItemObservacao(
      token: token,
      id: itemId,
      descricao: descricao,
    );
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final obs = b.observacoes.map((o) {
          if (o.id != observacaoId) return o;
          final itens = o.itens.map((i) {
            if (i.id != itemId) return i;
            return i.copyWith(descricao: descricao);
          }).toList();
          return o.copyWith(itens: itens);
        }).toList();
        return b.copyWith(observacoes: obs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível editar o item da observação';
  }

  Future<String?> excluirItemObservacao({
    required String token,
    required int bonusId,
    required int observacaoId,
    required int itemId,
  }) async {
    _carregando = true;
    notifyListeners();

    final res =
        await _service.excluirItemObservacao(token: token, id: itemId);
    _carregando = false;

    if (res.success) {
      _atualizarBonusLocal(bonusId, (b) {
        final obs = b.observacoes.map((o) {
          if (o.id != observacaoId) return o;
          final itens = o.itens.where((i) => i.id != itemId).toList();
          return o.copyWith(itens: itens);
        }).toList();
        return b.copyWith(observacoes: obs);
      });
      notifyListeners();
      return null;
    }

    notifyListeners();
    return res.message ?? 'Não foi possível excluir o item da observação';
  }

  // ─── Helper ─────────────────────────────────────────────────────────────

  void _atualizarBonusLocal(int bonusId, Bonus Function(Bonus) transform) {
    _lista = _lista.map((b) => b.id == bonusId ? transform(b) : b).toList();
    if (_bonusAtual?.id == bonusId) {
      _bonusAtual = transform(_bonusAtual!);
    }
  }
}