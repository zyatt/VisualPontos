import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bonus.dart';
import '../models/colaborador.dart';
import '../providers/bonus_provider.dart';
import '../providers/colaborador_provider.dart';
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

class CadastroColaboradorPage extends StatefulWidget {
  /// Quando informado, a página entra em modo edição, pré-preenchendo os
  /// campos e chamando a API de atualização em vez de cadastro.
  final Colaborador? colaboradorParaEditar;

  const CadastroColaboradorPage({super.key, this.colaboradorParaEditar});

  bool get isEdicao => colaboradorParaEditar != null;

  @override
  State<CadastroColaboradorPage> createState() => _CadastroColaboradorPageState();
}

class _CadastroColaboradorPageState extends State<CadastroColaboradorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeCtrl = TextEditingController(text: widget.colaboradorParaEditar?.nome ?? '');
  late final _setorCtrl = TextEditingController(text: widget.colaboradorParaEditar?.setor ?? '');

  final _setorFocus = FocusNode();

  bool _carregando = false;
  String? _erro;
  String? _sucesso;

  // Bônus selecionado para vincular ao colaborador (opcional).
  int? _bonusIdSelecionado;
  String? _bonusNomeSelecionado;
  bool _bonusFoiAlterado = false;

  @override
  void initState() {
    super.initState();
    _bonusIdSelecionado = widget.colaboradorParaEditar?.bonusId;
    _bonusNomeSelecionado = widget.colaboradorParaEditar?.bonusNome;

    // Garante que a lista de bônus esteja carregada para o seletor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarBonusDisponiveis());
  }

  Future<void> _carregarBonusDisponiveis() async {
    final bonusProvider = context.read<BonusProvider>();
    if (bonusProvider.lista.isNotEmpty) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await bonusProvider.carregar(token: token);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _setorCtrl.dispose();
    _setorFocus.dispose();
    super.dispose();
  }

  Future<void> _abrirSeletorDeBonus() async {
    final bonusProvider = context.read<BonusProvider>();

    // Garante lista atualizada mesmo se algo mudou desde o initState.
    if (bonusProvider.lista.isEmpty && !bonusProvider.carregando) {
      await _carregarBonusDisponiveis();
    }

    if (!mounted) return;

    final resultado = await showModalBottomSheet<_SeletorBonusResultado>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SeletorBonusSheet(
        bonusSelecionadoId: _bonusIdSelecionado,
      ),
    );

    // Sheet fechado sem escolha explícita (ex.: toque fora, botão fechar):
    // não altera nada.
    if (resultado == null) return;

    setState(() {
      _bonusFoiAlterado = true;
      if (resultado.bonus == null) {
        _bonusIdSelecionado = null;
        _bonusNomeSelecionado = null;
      } else {
        _bonusIdSelecionado = resultado.bonus!.id;
        _bonusNomeSelecionado = resultado.bonus!.nome;
      }
    });
  }

  Future<void> _salvar() async {
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

    final provider = context.read<ColaboradorProvider>();
    final String? erro;

    if (widget.isEdicao) {
      erro = await provider.editarColaborador(
        token: token,
        id: widget.colaboradorParaEditar!.id,
        nome: _nomeCtrl.text.trim(),
        setor: _setorCtrl.text.trim(),
        bonusId: _bonusIdSelecionado,
        limparBonus: _bonusFoiAlterado && _bonusIdSelecionado == null,
      );
    } else {
      erro = await provider.cadastrarColaborador(
        token: token,
        nome: _nomeCtrl.text.trim(),
        setor: _setorCtrl.text.trim(),
        bonusId: _bonusIdSelecionado,
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
        _sucesso = 'Colaborador cadastrado com sucesso!';
      });
      _nomeCtrl.clear();
      _setorCtrl.clear();
      setState(() {
        _bonusIdSelecionado = null;
        _bonusNomeSelecionado = null;
        _bonusFoiAlterado = false;
      });
    } else {
      setState(() {
        _carregando = false;
        _erro = erro;
      });
    }
  }

  Future<void> _excluir() async {
    final colaborador = widget.colaboradorParaEditar;
    if (colaborador == null || _carregando) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir colaborador'),
        content: Text(
          'Deseja realmente excluir "${colaborador.nome}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
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

    final erro = await context.read<ColaboradorProvider>().excluirColaborador(
          token: token,
          id: colaborador.id,
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
        title: Text(isEdicao ? 'Editar colaborador' : 'Cadastrar colaborador'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
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
                            isEdicao ? Icons.edit_rounded : Icons.groups_2_rounded,
                            color: AppTheme.orange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isEdicao ? 'Editar colaborador' : 'Novo colaborador',
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
                          FocusScope.of(context).requestFocus(_setorFocus),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _setorCtrl,
                      focusNode: _setorFocus,
                      decoration: const InputDecoration(
                        labelText: 'Setor',
                        prefixIcon: Icon(Icons.apartment_outlined, size: 18),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        _PrimeiraLetraMaiusculaFormatter(),
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _carregando ? null : _salvar(),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o setor' : null,
                    ),
                    const SizedBox(height: 14),

                    // ─── Seletor de bônus vinculado ─────────────────────
                    Text(
                      'Bônus vinculado',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _carregando ? null : _abrirSeletorDeBonus,
                        borderRadius: BorderRadius.circular(10),
                        mouseCursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.workspace_premium_outlined,
                                size: 18,
                                color: _bonusIdSelecionado != null
                                    ? AppTheme.orange
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _bonusNomeSelecionado ?? 'Nenhum bônus selecionado',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: _bonusIdSelecionado != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _bonusIdSelecionado != null
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(Icons.expand_more_rounded,
                                  color: scheme.onSurfaceVariant, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _carregando ? null : _salvar,
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

                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: _carregando ? null : _excluir,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                              ),
                              label: Text(
                                'Excluir colaborador',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                                side: WidgetStateProperty.all(
                                  BorderSide(
                                    color: AppTheme.error.withValues(alpha: 0.5),
                                  ),
                                ),
                                mouseCursor: WidgetStateProperty.all(
                                  SystemMouseCursors.click,
                                ),
                              ),
                            ),
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

/// Resultado explícito da escolha no seletor de bônus.
/// [bonus] nulo significa que o usuário escolheu "Nenhum" (limpar vínculo).
/// Ausência total de resultado (sheet fechado sem toque em item) é
/// representada por `null` no `Future` do `showModalBottomSheet`, não por
/// esta classe — por isso a distinção nunca se perde.
class _SeletorBonusResultado {
  final Bonus? bonus;
  const _SeletorBonusResultado(this.bonus);
}

/// Bottom sheet que lista os bônus existentes para seleção.
class _SeletorBonusSheet extends StatelessWidget {
  final int? bonusSelecionadoId;

  const _SeletorBonusSheet({required this.bonusSelecionadoId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BonusProvider>();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selecionar bônus',
                        style: GoogleFonts.raleway(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Builder(builder: (context) {
                  if (provider.carregando && provider.lista.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (provider.lista.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nenhum bônus cadastrado ainda.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      ListTile(
                        leading: Icon(Icons.block_rounded,
                            color: scheme.onSurfaceVariant),
                        title: Text(
                          'Nenhum',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: bonusSelecionadoId == null
                            ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                            : null,
                        onTap: () => Navigator.of(context)
                            .pop(const _SeletorBonusResultado(null)),
                      ),
                      const Divider(height: 1),
                      for (final bonus in provider.lista)
                        ListTile(
                          leading: const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppTheme.orange,
                          ),
                          title: Text(
                            bonus.nome,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                          ),
                          trailing: bonusSelecionadoId == bonus.id
                              ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                              : null,
                          onTap: () => Navigator.of(context)
                              .pop(_SeletorBonusResultado(bonus)),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}