import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Usuario? usuario;

  AuthResponse({required this.success, this.message, this.token, this.usuario});
}

class AuthService {
  // Backend PHP hospedado na Kinghost, dentro de www/api/
  static const String baseUrl = 'https://visualpremium.com.br/api';

  Future<AuthResponse> login(String usuario, String senha) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'usuario': usuario, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return AuthResponse(
          success: true,
          token: data['token'] as String,
          usuario: Usuario.fromJson(data['user'] as Map<String, dynamic>),
        );
      }

      return AuthResponse(
        success: false,
        message: data['message'] as String? ?? 'Usuário ou senha inválidos',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }

  /// Verifica se o token ainda é válido no servidor.
  ///
  /// Retorna:
  /// - `true`  → token confirmado válido pelo servidor
  /// - `false` → servidor respondeu e disse que o token é inválido/expirado
  /// - `null`  → não foi possível confirmar (sem internet, timeout, erro
  ///             de servidor). Nesse caso NÃO se deve apagar a sessão local,
  ///             pois o token pode continuar válido.
  Future<bool?> verify(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/verify.php'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }

      if (response.statusCode != 200) {
        // Erro de servidor (5xx, etc): não dá pra confirmar nem negar.
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      // Sem internet, timeout, host inacessível etc: não sabemos se o
      // token é válido, então não derrubamos a sessão local.
      return null;
    }
  }

  /// Cadastra um novo usuário. Requer o token do usuário logado
  /// (todos os usuários são admin por enquanto, então qualquer
  /// sessão válida pode cadastrar novos usuários).
  Future<AuthResponse> cadastrar({
    required String token,
    required String nome,
    required String usuario,
    required String senha,
    required String role,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'nome': nome,
              'usuario': usuario,
              'senha': senha,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return AuthResponse(
          success: true,
          usuario: Usuario.fromJson(data['user'] as Map<String, dynamic>),
        );
      }

      return AuthResponse(
        success: false,
        message: data['message'] as String? ?? 'Não foi possível cadastrar o usuário',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Não foi possível conectar ao servidor. Verifique sua internet.',
      );
    }
  }
}