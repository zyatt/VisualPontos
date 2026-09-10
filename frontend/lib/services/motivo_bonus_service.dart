import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/motivo_bonus.dart';
import '../config/api_config.dart';

class MotivoBonusResponse {
  final bool success;
  final String? message;
  final MotivoBonus? motivo;
  final List<MotivoBonus>? lista;

  MotivoBonusResponse({
    required this.success,
    this.message,
    this.motivo,
    this.lista,
  });
}

class MotivoBonusService {
  // URL base lida do .env (ApiConfig.baseUrl / API_BASE_URL).
  static String get _base => ApiConfig.baseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<MotivoBonusResponse> listar({required String token}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/motivos.php'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      developer.log('[MotivoBonusService.listar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        final lista = (data['motivos'] as List)
            .map((e) => MotivoBonus.fromJson(e as Map<String, dynamic>))
            .toList();
        return MotivoBonusResponse(success: true, lista: lista);
      }
      return MotivoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar motivos',
      );
    } catch (e, st) {
      developer.log('[MotivoBonusService.listar] ERRO: $e\n$st');
      return MotivoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<MotivoBonusResponse> criar({
    required String token,
    required String nome,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/motivos.php'),
            headers: _headers(token),
            body: jsonEncode({'nome': nome}),
          )
          .timeout(const Duration(seconds: 15));
      developer.log('[MotivoBonusService.criar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return MotivoBonusResponse(
          success: true,
          motivo: MotivoBonus.fromJson(data['motivo'] as Map<String, dynamic>),
        );
      }
      return MotivoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível criar o motivo',
      );
    } catch (e, st) {
      developer.log('[MotivoBonusService.criar] ERRO: $e\n$st');
      return MotivoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<MotivoBonusResponse> editar({
    required String token,
    required int id,
    required String nome,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/motivos.php'),
            headers: _headers(token),
            body: jsonEncode({'id': id, 'nome': nome}),
          )
          .timeout(const Duration(seconds: 15));
      developer.log('[MotivoBonusService.editar] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return MotivoBonusResponse(
          success: true,
          motivo: MotivoBonus.fromJson(data['motivo'] as Map<String, dynamic>),
        );
      }
      return MotivoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível editar o motivo',
      );
    } catch (e, st) {
      developer.log('[MotivoBonusService.editar] ERRO: $e\n$st');
      return MotivoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<MotivoBonusResponse> excluir({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/motivos.php?id=$id'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      developer.log('[MotivoBonusService.excluir] status=${res.statusCode} body=${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        return MotivoBonusResponse(success: true);
      }
      return MotivoBonusResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível excluir o motivo',
      );
    } catch (e, st) {
      developer.log('[MotivoBonusService.excluir] ERRO: $e\n$st');
      return MotivoBonusResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}