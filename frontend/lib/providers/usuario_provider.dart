import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

class UsuarioProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _usuarioKey = 'auth_usuario';

  final AuthService _authService = AuthService();

  Usuario? _usuario;
  String? _token;
  bool _carregando = false;
  String? _erro;

  Usuario? get usuario => _usuario;
  String? get token => _token;
  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get autenticado => _usuario != null && _token != null;

  /// Tenta restaurar a sessão salva ao abrir o app (ex: em app_shell ou splash).
  Future<bool> restaurarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final usuarioJson = prefs.getString(_usuarioKey);

    if (token == null || usuarioJson == null) return false;

    // Carrega a sessão local otimisticamente primeiro, para o app não
    // ficar "deslogado" enquanto aguarda a resposta do servidor.
    _token = token;
    _usuario = Usuario.fromJson(jsonDecode(usuarioJson) as Map<String, dynamic>);
    notifyListeners();

    final valido = await _authService.verify(token);

    // valido == false → servidor confirmou que o token expirou/é inválido.
    // valido == null  → não foi possível confirmar (sem internet/erro de
    //                    servidor); mantém a sessão local como está.
    if (valido == false) {
      await _limparSessao();
      _usuario = null;
      _token = null;
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<bool> login(String usuario, String senha) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final result = await _authService.login(usuario, senha);

    _carregando = false;

    if (result.success) {
      _usuario = result.usuario;
      _token = result.token;
      await _salvarSessao(result.token!, result.usuario!);
      notifyListeners();
      return true;
    }

    _erro = result.message;
    notifyListeners();
    return false;
  }

  /// Cadastra um novo usuário usando o token da sessão atual.
  /// Retorna uma mensagem de erro em caso de falha, ou null se OK.
  Future<String?> cadastrarUsuario({
    required String nome,
    required String usuario,
    required String senha,
    required String role,
  }) async {
    if (_token == null) return 'Sessão inválida. Faça login novamente.';

    final result = await _authService.cadastrar(
      token: _token!,
      nome: nome,
      usuario: usuario,
      senha: senha,
      role: role,
    );

    if (result.success) return null;
    return result.message ?? 'Não foi possível cadastrar o usuário';
  }

  Future<void> logout() async {
    _usuario = null;
    _token = null;
    _erro = null;
    await _limparSessao();
    notifyListeners();
  }

  Future<void> _salvarSessao(String token, Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usuarioKey, jsonEncode(usuario.toJson()));
  }

  Future<void> _limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usuarioKey);
  }
}