import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/colaborador.dart';
import '../config/api_config.dart';

class ColaboradorResponse {
  final bool success;
  final String? message;
  final Colaborador? colaborador;
  final List<Colaborador>? colaboradores;

  ColaboradorResponse({
    required this.success,
    this.message,
    this.colaborador,
    this.colaboradores,
  });
}

class ColaboradorService {
  // URL base lida do .env (ApiConfig.baseUrl / API_BASE_URL).
  static String get baseUrl => ApiConfig.baseUrl;

  Future<ColaboradorResponse> cadastrar({
    required String token,
    required String nome,
    required String setor,
    int? bonusId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/colaboradores.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'nome': nome,
              'setor': setor,
              'bonus_id': bonusId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return ColaboradorResponse(
          success: true,
          colaborador: Colaborador.fromJson(data['colaborador'] as Map<String, dynamic>),
        );
      }

      return ColaboradorResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível cadastrar o colaborador',
      );
    } catch (e) {
      return ColaboradorResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<ColaboradorResponse> listar({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/colaboradores.php'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['colaboradores'] as List)
            .map((e) => Colaborador.fromJson(e as Map<String, dynamic>))
            .toList();
        return ColaboradorResponse(success: true, colaboradores: list);
      }

      return ColaboradorResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível carregar os colaboradores',
      );
    } catch (e) {
      return ColaboradorResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// [limparBonus] força o envio de `bonus_id: null` para remover um vínculo
  /// existente. Se for `false` e [bonusId] for `null`, o campo simplesmente
  /// não é alterado no servidor.
  Future<ColaboradorResponse> editar({
    required String token,
    required int id,
    required String nome,
    required String setor,
    int? bonusId,
    bool limparBonus = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'id': id,
        'nome': nome,
        'setor': setor,
      };
      if (bonusId != null || limparBonus) {
        body['bonus_id'] = bonusId;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/colaboradores.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return ColaboradorResponse(
          success: true,
          colaborador: Colaborador.fromJson(data['colaborador'] as Map<String, dynamic>),
        );
      }

      return ColaboradorResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível editar o colaborador',
      );
    } catch (e) {
      return ColaboradorResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Atualiza apenas a pontuação inicial (base) do colaborador no mês,
  /// sem alterar os demais campos.
  Future<ColaboradorResponse> editarPontosIniciais({
    required String token,
    required int id,
    required String nome,
    required String setor,
    int? bonusId,
    required int pontosIniciais,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/colaboradores.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'id': id,
              'nome': nome,
              'setor': setor,
              'bonus_id': bonusId,
              'pontos_iniciais': pontosIniciais,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return ColaboradorResponse(
          success: true,
          colaborador: Colaborador.fromJson(data['colaborador'] as Map<String, dynamic>),
        );
      }

      return ColaboradorResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível atualizar a pontuação inicial',
      );
    } catch (e) {
      return ColaboradorResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<ColaboradorResponse> excluir({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/colaboradores.php?id=$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return ColaboradorResponse(success: true);
      }

      return ColaboradorResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível excluir o colaborador',
      );
    } catch (e) {
      return ColaboradorResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}