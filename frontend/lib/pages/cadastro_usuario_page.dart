import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/usuario.dart';
import '../providers/usuario_admin_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

class _PrimeiraLetraMaiusculaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;

    if (texto.isEmpty) {
      return newValue;
    }

    final novoTexto = texto.replaceAllMapped(
      RegExp(r'(^|[\s])([a-záàâãéêíóôõúç])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );

    return newValue.copyWith(
      text: novoTexto,
      selection: TextSelection.collapsed(
        offset: novoTexto.length,
      ),
    );
  }
}

class CadastroUsuarioPage extends StatefulWidget {
  /// Quando informado, a página entra em modo edição, pré-preenchendo os
  /// campos e chamando a API de atualização em vez de cadastro. A senha
  /// fica opcional nesse modo (só é enviada se preenchida).
  final Usuario? usuarioParaEditar;

  const CadastroUsuarioPage({super.key, this.usuarioParaEditar});

  bool get isEdicao => usuarioParaEditar != null;

  @override
  State<CadastroUsuarioPage> createState() => _CadastroUsuarioPageState();
}

class _CadastroUsuarioPageState extends State<CadastroUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeCtrl = TextEditingController(text: widget.usuarioParaEditar?.nome ?? '');
  late final _userCtrl = TextEditingController(text: widget.usuarioParaEditar?.usuario ?? '');
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  late String _role = widget.usuarioParaEditar?.role ?? 'ADMIN';

  final _userFocus = FocusNode();
  final _senhaFocus = FocusNode();
  final _confirmarSenhaFocus = FocusNode();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _carregando = false;
  String? _erro;
  String? _sucesso;

  /// GERENTE não pode editar/excluir um usuário ADMIN.
  bool get _bloqueadoPorPermissao {
    if (!widget.isEdicao) return false;
    final meuRole = context.read<UsuarioProvider>().usuario?.role;
    return meuRole == 'GERENTE' && widget.usuarioParaEditar!.role == 'ADMIN';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _userCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    _userFocus.dispose();
    _senhaFocus.dispose();
    _confirmarSenhaFocus.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_bloqueadoPorPermissao) {
      setState(() {
        _erro = 'Você não tem permissão para editar um administrador';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _erro = null;
      _sucesso = null;
    });

    final token = context.read<UsuarioProvider>().token;
    if (token == null) {
      setState(() {
        _carregando = false;
        _erro = 'Sessão inválida. Faça login novamente.';
      });
      return;
    }

    final String? erro;

    if (widget.isEdicao) {
      erro = await context.read<UsuarioAdminProvider>().editarUsuario(
            token: token,
            id: widget.usuarioParaEditar!.id,
            nome: _nomeCtrl.text.trim(),
            usuario: _userCtrl.text.trim(),
            role: _role,
            senha: _senhaCtrl.text.isEmpty ? null : _senhaCtrl.text,
          );
    } else {
      final usuarioProvider = context.read<UsuarioProvider>();
      erro = await usuarioProvider.cadastrarUsuario(
        nome: _nomeCtrl.text.trim(),
        usuario: _userCtrl.text.trim(),
        senha: _senhaCtrl.text,
        role: _role,
      );
    }

    if (!mounted) return;

    if (erro == null) {
      if (widget.isEdicao) {
        // Edição concluída: volta para a listagem.
        context.pop('editado');
        return;
      }
      setState(() {
        _carregando = false;
        _sucesso = 'Usuário cadastrado com sucesso!';
      });
      _nomeCtrl.clear();
      _userCtrl.clear();
      _senhaCtrl.clear();
      _confirmarSenhaCtrl.clear();
    } else {
      setState(() {
        _carregando = false;
        _erro = erro;
      });
    }
  }

  Future<void> _excluir() async {
    final usuario = widget.usuarioParaEditar;

    if (usuario == null || _carregando) return;

    final meuId = context.read<UsuarioProvider>().usuario?.id;

    // Segurança: um GERENTE não pode excluir um ADMIN.
    if (_bloqueadoPorPermissao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para excluir um administrador'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Segurança: o próprio usuário logado nunca pode ser excluído.
    if (usuario.id == meuId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não pode excluir o próprio usuário logado'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text(
          'Deseja realmente excluir "${usuario.nome}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          Tooltip(
            message: 'Cancelar',
            child: TextButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
          Tooltip(
            message: 'Excluir usuário',
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error,
              ).copyWith(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    setState(() {
      _carregando = true;
      _erro = null;
      _sucesso = null;
    });

    final token = context.read<UsuarioProvider>().token;

    if (token == null) {
      setState(() {
        _carregando = false;
        _erro = 'Sessão inválida. Faça login novamente.';
      });
      return;
    }

    final erro = await context.read<UsuarioAdminProvider>().excluirUsuario(
          token: token,
          id: usuario.id,
        );

    if (!mounted) return;

    if (erro == null) {
      context.pop('excluido');
    } else {
      setState(() {
        _carregando = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdicao = widget.isEdicao;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar usuário' : 'Cadastrar usuário'),
        leading: Tooltip(
          message: 'Voltar',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(36),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdicao ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                            color: AppTheme.orange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isEdicao ? 'Editar usuário' : 'Novo usuário',
                            style: GoogleFonts.raleway(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    if (_bloqueadoPorPermissao) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, color: AppTheme.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Como gerente, você não tem permissão para editar um administrador.',
                                style: GoogleFonts.nunito(color: AppTheme.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_erro != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _erro!,
                                style: GoogleFonts.nunito(color: AppTheme.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_sucesso != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _sucesso!,
                                style: GoogleFonts.nunito(color: Colors.green, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                   TextFormField(
                    controller: _nomeCtrl,
                    enabled: !_bloqueadoPorPermissao,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      _PrimeiraLetraMaiusculaFormatter(),
                    ],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_userFocus),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _userCtrl,
                      focusNode: _userFocus,
                      enabled: !_bloqueadoPorPermissao,
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_senhaFocus),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o usuário';
                        if (v.trim().length < 3) return 'Mínimo de 3 caracteres';
                        if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v.trim())) {
                          return 'Use apenas letras, números, "." "_" ou "-"';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _PerfilSelector(
                      value: _role,
                      enabled: !_bloqueadoPorPermissao,
                      onChanged: (v) => setState(() => _role = v),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _senhaCtrl,
                      focusNode: _senhaFocus,
                      enabled: !_bloqueadoPorPermissao,
                      obscureText: _obscureSenha,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmarSenhaFocus),
                      decoration: InputDecoration(
                        labelText: isEdicao ? 'Nova senha' : 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          mouseCursor: SystemMouseCursors.click,
                          icon: Icon(
                            _obscureSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                        ),
                      ),
                      validator: (v) {
                        if (isEdicao) {
                          // No modo edição, senha é opcional; se preenchida, valida tamanho.
                          if (v != null && v.isNotEmpty && v.length < 6) return 'Mínimo de 6 caracteres';
                          return null;
                        }
                        if (v == null || v.isEmpty) return 'Informe a senha';
                        if (v.length < 6) return 'Mínimo de 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _confirmarSenhaCtrl,
                      focusNode: _confirmarSenhaFocus,
                      enabled: !_bloqueadoPorPermissao,
                      obscureText: _obscureConfirmar,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _carregando ? null : _salvar(),
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          mouseCursor: SystemMouseCursors.click,
                          icon: Icon(
                            _obscureConfirmar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                        ),
                      ),
                      validator: (v) {
                        // Só exige confirmação se uma senha foi digitada
                        // (sempre obrigatório no cadastro; opcional na edição).
                        if (!isEdicao || _senhaCtrl.text.isNotEmpty) {
                          if (v == null || v.isEmpty) return 'Confirme a senha';
                          if (v != _senhaCtrl.text) return 'As senhas não coincidem';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_carregando || _bloqueadoPorPermissao) ? null : _salvar,
                            style: ButtonStyle(
                              mouseCursor: WidgetStateProperty.all(
                                SystemMouseCursors.click,
                              ),
                            ),
                            child: _carregando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEdicao ? 'Salvar alterações' : 'Cadastrar',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),

                        if (isEdicao) ...[
                          const SizedBox(height: 12),

                          Builder(
                            builder: (context) {
                              final meuId = context.read<UsuarioProvider>().usuario?.id;
                              final ehVoceMesmo =
                                  widget.usuarioParaEditar!.id == meuId;
                              final semPermissao = _bloqueadoPorPermissao;

                              return SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: (_carregando || ehVoceMesmo || semPermissao)
                                      ? null
                                      : _excluir,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                  ),
                                  label: Text(
                                    ehVoceMesmo
                                        ? 'Não é possível excluir seu usuário'
                                        : semPermissao
                                            ? 'Sem permissão para excluir'
                                            : 'Excluir usuário',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ButtonStyle(
                                    foregroundColor: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(WidgetState.disabled)) {
                                          return scheme.onSurfaceVariant
                                              .withValues(alpha: 0.5);
                                        }
                                        return AppTheme.error;
                                      },
                                    ),
                                    side: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(WidgetState.disabled)) {
                                          return BorderSide(
                                            color: scheme.outline.withValues(alpha: 0.3),
                                          );
                                        }
                                        return BorderSide(
                                          color: AppTheme.error.withValues(alpha: 0.5),
                                        );
                                      },
                                    ),
                                    mouseCursor: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(WidgetState.disabled)) {
                                          return SystemMouseCursors.basic;
                                        }
                                        return SystemMouseCursors.click;
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de seleção de "Perfil" com a mesma aparência de um
/// DropdownButtonFormField, porém com controle total sobre o cursor:
/// usa InkWell (que suporta mouseCursor nativamente) para abrir o menu,
/// então o botão inteiro e cada item da lista mostram o cursor de mão.
class _PerfilSelector extends StatefulWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PerfilSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_PerfilSelector> createState() => _PerfilSelectorState();
}

class _PerfilSelectorState extends State<_PerfilSelector> {
  static const _opcoes = [
    ('ADMIN', 'Administrador'),
    ('GERENTE', 'Gerente'),
  ];

  final _fieldKey = GlobalKey();

  String get _label => _opcoes
      .firstWhere((o) => o.$1 == widget.value, orElse: () => _opcoes.first)
      .$2;

  Future<void> _abrirMenu() async {
    final box = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
    final bottomRight = box.localToGlobal(
      Offset(box.size.width, box.size.height + 4),
      ancestor: overlay,
    );

    final selecionado = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(minWidth: box.size.width),
      items: _opcoes
          .map(
            (o) => PopupMenuItem<String>(
              value: o.$1,
              mouseCursor: SystemMouseCursors.click,
              child: Text(o.$2),
            ),
          )
          .toList(),
    );

    if (selecionado != null) widget.onChanged(selecionado);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      key: _fieldKey,
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      borderRadius: BorderRadius.circular(12),
      onTap: widget.enabled ? _abrirMenu : null,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: 'Perfil',
          prefixIcon: const Icon(Icons.shield_outlined, size: 18),
          suffixIcon: Icon(
            Icons.arrow_drop_down_rounded,
            color: widget.enabled
                ? scheme.onSurfaceVariant
                : scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          enabled: widget.enabled,
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: widget.enabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}