import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';

/// Serviço para operações administrativas sobre usuários (listar, editar,
/// excluir). Separado de [AuthService] para não misturar com login/sessão.
class UsuarioAdminResponse {
  final bool success;
  final String? message;
  final Usuario? usuario;
  final List<Usuario>? usuarios;

  UsuarioAdminResponse({
    required this.success,
    this.message,
    this.usuario,
    this.usuarios,
  });
}

class UsuarioAdminService {
  static const String baseUrl = 'https://visualpremium.com.br/api';

  Future<UsuarioAdminResponse> listar({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/register.php'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['usuarios'] as List)
            .map((e) => Usuario.fromJson(e as Map<String, dynamic>))
            .toList();
        return UsuarioAdminResponse(success: true, usuarios: list);
      }

      return UsuarioAdminResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível carregar os usuários',
      );
    } catch (e) {
      return UsuarioAdminResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<UsuarioAdminResponse> editar({
    required String token,
    required int id,
    required String nome,
    required String usuario,
    required String role,
    String? senha,
  }) async {
    try {
      final body = {
        'id': id,
        'nome': nome,
        'usuario': usuario,
        'role': role,
        if (senha != null && senha.isNotEmpty) 'senha': senha,
      };

      final response = await http
          .put(
            Uri.parse('$baseUrl/register.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return UsuarioAdminResponse(
          success: true,
          usuario: Usuario.fromJson(data['user'] as Map<String, dynamic>),
        );
      }

      return UsuarioAdminResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível editar o usuário',
      );
    } catch (e) {
      return UsuarioAdminResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  Future<UsuarioAdminResponse> excluir({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/register.php?id=$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return UsuarioAdminResponse(success: true);
      }

      return UsuarioAdminResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível excluir o usuário',
      );
    } catch (e) {
      return UsuarioAdminResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}