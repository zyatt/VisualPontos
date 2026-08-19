import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/usuario_admin_service.dart';

/// Provider para operações administrativas sobre usuários (listar, editar,
/// excluir). Separado de [UsuarioProvider], que cuida da sessão/login do
/// usuário atualmente autenticado.
class UsuarioAdminProvider extends ChangeNotifier {
  final UsuarioAdminService _service = UsuarioAdminService();

  bool _carregando = false;
  String? _erro;
  List<Usuario> _usuarios = [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<Usuario> get usuarios => _usuarios;

  Future<String?> carregarUsuarios({required String token}) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final result = await _service.listar(token: token);

    _carregando = false;

    if (result.success) {
      _usuarios = result.usuarios ?? [];
      notifyListeners();
      return null;
    }

    _erro = result.message;
    notifyListeners();
    return _erro;
  }

  /// Adiciona um usuário recém-cadastrado à lista em memória, sem precisar
  /// recarregar do servidor.
  void adicionarUsuario(Usuario usuario) {
    _usuarios = [..._usuarios, usuario]..sort((a, b) => a.nome.compareTo(b.nome));
    notifyListeners();
  }

  Future<String?> editarUsuario({
    required String token,
    required int id,
    required String nome,
    required String usuario,
    required String role,
    String? senha,
  }) async {
    _carregando = true;
    notifyListeners();

    final result = await _service.editar(
      token: token,
      id: id,
      nome: nome,
      usuario: usuario,
      role: role,
      senha: senha,
    );

    _carregando = false;

    if (result.success && result.usuario != null) {
      _usuarios = _usuarios
          .map((u) => u.id == id ? result.usuario! : u)
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível editar o usuário';
  }

  Future<String?> excluirUsuario({
    required String token,
    required int id,
  }) async {
    _carregando = true;
    notifyListeners();

    final result = await _service.excluir(token: token, id: id);

    _carregando = false;

    if (result.success) {
      _usuarios = _usuarios.where((u) => u.id != id).toList();
      notifyListeners();
      return null;
    }

    notifyListeners();
    return result.message ?? 'Não foi possível excluir o usuário';
  }
}