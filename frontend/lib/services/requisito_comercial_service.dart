import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/requisito_comercial.dart';
import '../config/api_config.dart';

class RequisitoComercialResponse {
  final bool success;
  final String? message;
  final RequisitoComercial? requisito;
  final List<RequisitoComercial>? lista;

  RequisitoComercialResponse({
    required this.success,
    this.message,
    this.requisito,
    this.lista,
  });
}

class RequisitoComercialService {
  static String get _base => ApiConfig.baseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<RequisitoComercialResponse> listar({required String token}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base/requisitos.php'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final lista = (data['requisitos'] as List)
            .map((e) => RequisitoComercial.fromJson(e as Map<String, dynamic>))
            .toList();
        return RequisitoComercialResponse(success: true, lista: lista);
      }
      return RequisitoComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Erro ao carregar requisitos',
      );
    } catch (e) {
      return RequisitoComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<RequisitoComercialResponse> cadastrar({
    required String token,
    required String nome,
    required String descricao,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/requisitos.php'),
            headers: _headers(token),
            body: jsonEncode({'nome': nome, 'descricao': descricao}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return RequisitoComercialResponse(
          success: true,
          requisito:
              RequisitoComercial.fromJson(data['requisito'] as Map<String, dynamic>),
        );
      }
      return RequisitoComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível cadastrar o requisito',
      );
    } catch (e) {
      return RequisitoComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<RequisitoComercialResponse> editar({
    required String token,
    required int id,
    required String nome,
    required String descricao,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/requisitos.php'),
            headers: _headers(token),
            body: jsonEncode({'id': id, 'nome': nome, 'descricao': descricao}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return RequisitoComercialResponse(
          success: true,
          requisito:
              RequisitoComercial.fromJson(data['requisito'] as Map<String, dynamic>),
        );
      }
      return RequisitoComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível editar o requisito',
      );
    } catch (e) {
      return RequisitoComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<RequisitoComercialResponse> excluir({
    required String token,
    required int id,
  }) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/requisitos.php?id=$id'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        return RequisitoComercialResponse(success: true);
      }
      return RequisitoComercialResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível excluir o requisito',
      );
    } catch (e) {
      return RequisitoComercialResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}