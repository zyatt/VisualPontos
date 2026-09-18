import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/checklist_comercial.dart';
import '../config/api_config.dart';

class ResumoRequisito {
  final int requisitoId;
  final String requisitoNome;
  final int total;

  ResumoRequisito({
    required this.requisitoId,
    required this.requisitoNome,
    required this.total,
  });

  factory ResumoRequisito.fromJson(Map<String, dynamic> json) {
    return ResumoRequisito(
      requisitoId: json['requisito_id'] as int,
      requisitoNome: json['requisito_nome'] as String? ?? '',
      total: json['total'] as int,
    );
  }
}

class ChecklistComercialResponse {
  final bool success;
  final String? message;
  final ChecklistComercial? checklist;
  final List<ChecklistComercial>? lista;
  final List<ResumoRequisito>? resumoRequisitos;
  final bool osEncontrada;

  ChecklistComercialResponse({
    required this.success,
    this.message,
    this.checklist,
    this.lista,
    this.resumoRequisitos,
    this.osEncontrada = false,
  });
}

class ChecklistComercialService {
  static String get _base => ApiConfig.baseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Histórico de checklists do colaborador (opcionalmente filtrado por
  /// mês/ano), mesmo padrão de [buscarHistorico] em LancamentoBonusService.
  Future<ChecklistComercialResponse> buscarHistorico({
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
      final uri = Uri.parse('$_base/checklists_comercial.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final lista = (data['checklists'] as List)
            .map((e) => ChecklistComercial.fromJson(e as Map<String, dynamic>))
            .toList();
        return ChecklistComercialResponse(success: true, lista: lista);
      }
      return ChecklistComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar histórico',
      );
    } catch (e) {
      return ChecklistComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Busca um checklist já existente para a mesma OS (usado para
  /// reabrir/editar). [encontrado] indica se já existe um checklist
  /// salvo para essa OS deste colaborador.
  Future<ChecklistComercialResponse> buscarPorOs({
    required String token,
    required int colaboradorId,
    required String os,
  }) async {
    try {
      final query = {
        'recurso': 'buscar_os',
        'colaborador_id': '$colaboradorId',
        'os': os,
      };
      final uri = Uri.parse('$_base/checklists_comercial.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final checklistJson = data['checklist'] as Map<String, dynamic>?;
        return ChecklistComercialResponse(
          success: true,
          osEncontrada: data['encontrado'] == true,
          checklist:
              checklistJson != null ? ChecklistComercial.fromJson(checklistJson) : null,
        );
      }
      return ChecklistComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao verificar a OS',
      );
    } catch (e) {
      return ChecklistComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Contagem de não-conformidades por requisito num mês/ano.
  Future<ChecklistComercialResponse> buscarResumoRequisitos({
    required String token,
    required int mes,
    required int ano,
    List<int>? colaboradorIds,
  }) async {
    try {
      final query = {
        'recurso': 'resumo_requisitos',
        'mes': '$mes',
        'ano': '$ano',
        if (colaboradorIds != null && colaboradorIds.isNotEmpty)
          'colaborador_ids': colaboradorIds.join(','),
      };
      final uri = Uri.parse('$_base/checklists_comercial.php')
          .replace(queryParameters: query);

      final res =
          await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final resumo = (data['resumo'] as List)
            .map((e) => ResumoRequisito.fromJson(e as Map<String, dynamic>))
            .toList();
        return ChecklistComercialResponse(success: true, resumoRequisitos: resumo);
      }
      return ChecklistComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar resumo de requisitos',
      );
    } catch (e) {
      return ChecklistComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Cria um novo checklist para uma OS.
  Future<ChecklistComercialResponse> criar({
    required String token,
    required int colaboradorId,
    required String os,
    required List<ChecklistItem> itens,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/checklists_comercial.php?recurso=checklist'),
            headers: _headers(token),
            body: jsonEncode({
              'colaborador_id': colaboradorId,
              'os': os,
              'itens': itens.map((i) => i.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return ChecklistComercialResponse(
          success: true,
          checklist:
              ChecklistComercial.fromJson(data['checklist'] as Map<String, dynamic>),
        );
      }
      return ChecklistComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível salvar o checklist',
      );
    } catch (e) {
      return ChecklistComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Edita um checklist já existente. Só ADMIN pode chamar isso — o
  /// backend também valida, mas a checagem de role já evita a chamada
  /// (ver [ChecklistComercialProvider.editar]).
  Future<ChecklistComercialResponse> editar({
    required String token,
    required int id,
    required String os,
    required List<ChecklistItem> itens,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/checklists_comercial.php?recurso=checklist'),
            headers: _headers(token),
            body: jsonEncode({
              'id': id,
              'os': os,
              'itens': itens.map((i) => i.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return ChecklistComercialResponse(
          success: true,
          checklist:
              ChecklistComercial.fromJson(data['checklist'] as Map<String, dynamic>),
        );
      }
      return ChecklistComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível atualizar o checklist',
      );
    } catch (e) {
      return ChecklistComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}