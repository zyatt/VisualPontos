import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/bonus.dart';
import '../models/categoria_bonus.dart';
import '../models/subcategoria_bonus.dart';
import '../models/observacao_bonus.dart';
import '../models/item_observacao_bonus.dart';

class BonusResponse {
  final bool success;
  final String? message;
  final Bonus? bonus;
  final List<Bonus>? lista;
  final CategoriaBonus? categoria;
  final SubcategoriaBonus? subcategoria;
  final ObservacaoBonus? observacao;
  final ItemObservacaoBonus? item;

  BonusResponse({
    required this.success,
    this.message,
    this.bonus,
    this.lista,
    this.categoria,
    this.subcategoria,
    this.observacao,
    this.item,
  });
}

class BonusService {
  static const String _base = 'https://visualpremium.com.br/api';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ─── BÔNUS ──────────────────────────────────────────────────────────────

  Future<BonusResponse> listar({required String token}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/bonus.php?recurso=bonus'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.listar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        final lista = (data['bonus'] as List)
            .map((e) => Bonus.fromJson(e as Map<String, dynamic>))
            .toList();
        return BonusResponse(success: true, lista: lista);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao carregar bônus');
    } catch (e, st) {
      developer.log('[BonusService.listar] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> buscar({required String token, required int id}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/bonus.php?recurso=bonus&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.buscar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            bonus: Bonus.fromJson(data['bonus'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Bônus não encontrado');
    } catch (e, st) {
      developer.log('[BonusService.buscar] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> criar(
      {required String token, required String nome}) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=bonus'),
              headers: _headers(token),
              body: jsonEncode({'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.criar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            bonus: Bonus.fromJson(data['bonus'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao criar bônus');
    } catch (e, st) {
      developer.log('[BonusService.criar] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> editarBonus(
      {required String token, required int id, required String nome}) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/bonus.php?recurso=bonus'),
              headers: _headers(token),
              body: jsonEncode({'id': id, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.editarBonus] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            bonus: Bonus.fromJson(data['bonus'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao editar bônus');
    } catch (e, st) {
      developer.log('[BonusService.editarBonus] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> excluirBonus(
      {required String token, required int id}) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/bonus.php?recurso=bonus&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.excluirBonus] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(success: true);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao excluir bônus');
    } catch (e, st) {
      developer.log('[BonusService.excluirBonus] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> duplicar({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=duplicar'),
              headers: _headers(token),
              body: jsonEncode({'bonus_id': bonusId, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.duplicar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            bonus: Bonus.fromJson(data['bonus'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao duplicar bônus');
    } catch (e, st) {
      developer.log('[BonusService.duplicar] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  // ─── CATEGORIA ──────────────────────────────────────────────────────────

  Future<BonusResponse> criarCategoria({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=categoria'),
              headers: _headers(token),
              body: jsonEncode({'bonus_id': bonusId, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.criarCategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            categoria: CategoriaBonus.fromJson(
                data['categoria'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao criar categoria');
    } catch (e, st) {
      developer.log('[BonusService.criarCategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> editarCategoria({
    required String token,
    required int id,
    required String nome,
  }) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/bonus.php?recurso=categoria'),
              headers: _headers(token),
              body: jsonEncode({'id': id, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.editarCategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            categoria: CategoriaBonus.fromJson(
                data['categoria'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao editar categoria');
    } catch (e, st) {
      developer.log('[BonusService.editarCategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> excluirCategoria({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/bonus.php?recurso=categoria&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.excluirCategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(success: true);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao excluir categoria');
    } catch (e, st) {
      developer.log('[BonusService.excluirCategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  // ─── SUBCATEGORIA ──────────────────────────────────────────────────────────

  Future<BonusResponse> criarSubcategoria({
    required String token,
    required int categoriaId,
    required String descricao,
    required int pontos,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=subcategoria'),
              headers: _headers(token),
              body: jsonEncode({
                'categoria_id': categoriaId,
                'descricao': descricao,
                'pontos': pontos,
              }))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.criarSubcategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            subcategoria: SubcategoriaBonus.fromJson(
                data['subcategoria'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao criar subcategoria');
    } catch (e, st) {
      developer.log('[BonusService.criarSubcategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> editarSubcategoria({
    required String token,
    required int id,
    required String descricao,
    required int pontos,
  }) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/bonus.php?recurso=subcategoria'),
              headers: _headers(token),
              body: jsonEncode(
                  {'id': id, 'descricao': descricao, 'pontos': pontos}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.editarSubcategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            subcategoria: SubcategoriaBonus.fromJson(
                data['subcategoria'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao editar subcategoria');
    } catch (e, st) {
      developer.log('[BonusService.editarSubcategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> excluirSubcategoria({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/bonus.php?recurso=subcategoria&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.excluirSubcategoria] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(success: true);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao excluir subcategoria');
    } catch (e, st) {
      developer.log('[BonusService.excluirSubcategoria] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  // ─── OBSERVAÇÃO ─────────────────────────────────────────────────────────

  Future<BonusResponse> criarObservacao({
    required String token,
    required int bonusId,
    required String nome,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=observacao'),
              headers: _headers(token),
              body: jsonEncode({'bonus_id': bonusId, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.criarObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            observacao: ObservacaoBonus.fromJson(
                data['observacao'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao criar observação');
    } catch (e, st) {
      developer.log('[BonusService.criarObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> editarObservacao({
    required String token,
    required int id,
    required String nome,
  }) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/bonus.php?recurso=observacao'),
              headers: _headers(token),
              body: jsonEncode({'id': id, 'nome': nome}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.editarObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            observacao: ObservacaoBonus.fromJson(
                data['observacao'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao editar observação');
    } catch (e, st) {
      developer.log('[BonusService.editarObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> excluirObservacao({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/bonus.php?recurso=observacao&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.excluirObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(success: true);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ?? 'Erro ao excluir observação');
    } catch (e, st) {
      developer.log('[BonusService.excluirObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  // ─── ITEM DE OBSERVAÇÃO ─────────────────────────────────────────────────

  Future<BonusResponse> criarItemObservacao({
    required String token,
    required int observacaoId,
    required String descricao,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_base/bonus.php?recurso=item_observacao'),
              headers: _headers(token),
              body: jsonEncode(
                  {'observacao_id': observacaoId, 'descricao': descricao}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.criarItemObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            item: ItemObservacaoBonus.fromJson(
                data['item'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message:
              data['message'] as String? ?? 'Erro ao criar item da observação');
    } catch (e, st) {
      developer.log('[BonusService.criarItemObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> editarItemObservacao({
    required String token,
    required int id,
    required String descricao,
  }) async {
    try {
      final res = await http
          .put(Uri.parse('$_base/bonus.php?recurso=item_observacao'),
              headers: _headers(token),
              body: jsonEncode({'id': id, 'descricao': descricao}))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.editarItemObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(
            success: true,
            item: ItemObservacaoBonus.fromJson(
                data['item'] as Map<String, dynamic>));
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ??
              'Erro ao editar item da observação');
    } catch (e, st) {
      developer.log('[BonusService.editarItemObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }

  Future<BonusResponse> excluirItemObservacao({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(
              Uri.parse('$_base/bonus.php?recurso=item_observacao&id=$id'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[BonusService.excluirItemObservacao] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return BonusResponse(success: true);
      }
      return BonusResponse(
          success: false,
          message: data['message'] as String? ??
              'Erro ao excluir item da observação');
    } catch (e, st) {
      developer.log('[BonusService.excluirItemObservacao] ERRO: $e\n$st');
      return BonusResponse(
          success: false,
          message: 'Não foi possível conectar ao servidor. ($e)');
    }
  }
}