import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/colaborador.dart';
import '../models/categoria_bonus.dart';
import '../models/subcategoria_bonus.dart';
import '../providers/bonus_provider.dart';
import '../providers/colaborador_provider.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

/// Página aberta ao tocar em um colaborador na listagem.
/// Mostra o saldo de pontos do mês (começa em 100) e todas as
/// categorias/subcategorias do bônus vinculado ao colaborador para que o
/// usuário possa lançar uma penalidade.
class PontuacaoColaboradorPage extends StatefulWidget {
  final Colaborador colaborador;

  const PontuacaoColaboradorPage({super.key, required this.colaborador});

  @override
  State<PontuacaoColaboradorPage> createState() =>
      _PontuacaoColaboradorPageState();
}

class _PontuacaoColaboradorPageState extends State<PontuacaoColaboradorPage> {
  // Mantém uma cópia local editável, já que o widget recebe o colaborador
  // via `extra` da rota e não é reconstruído automaticamente pelo provider.
  late Colaborador _colaborador;

  // Controla se os dados que estão nos providers (pontuação/bônus) já
  // pertencem a ESTE colaborador. Enquanto for false, a tela mostra um
  // loading em tela cheia, evitando o "flash" com os dados do colaborador
  // anterior (que ficam no provider até a nova busca terminar).
  bool _prontoParaExibir = false;

  @override
  void initState() {
    super.initState();
    _colaborador = widget.colaborador;
    // Usa microtask em vez de chamar direto: o provider pode notificar
    // listeners de forma síncrona (ex.: ao marcar carregando = true), e
    // fazer isso durante o build inicial do widget dispara
    // "setState() or markNeedsBuild() called during build".
    Future.microtask(_carregarTudo);
  }

  @override
  void didUpdateWidget(covariant PontuacaoColaboradorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Caso o Flutter reaproveite este State para outro colaborador
    // (mesma posição na árvore de widgets), recarrega tudo do zero.
    if (oldWidget.colaborador.id != widget.colaborador.id) {
      _colaborador = widget.colaborador;
      Future.microtask(_carregarTudo);
    }
  }

  Future<void> _carregarTudo() async {
    if (mounted) setState(() => _prontoParaExibir = false);

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    await context.read<LancamentoBonusProvider>().carregarPontuacao(
          token: token,
          colaboradorId: _colaborador.id,
        );

    final bonusId = _colaborador.bonusId;
    if (bonusId != null && mounted) {
      await context
          .read<BonusProvider>()
          .carregarDetalhe(token: token, id: bonusId);
    }

    if (mounted) setState(() => _prontoParaExibir = true);
  }

  Future<void> _selecionarSubcategoria(
    CategoriaBonus categoria,
    SubcategoriaBonus sub,
  ) async {
    final resultado = await showDialog<_DialogPenalidadeResultado>(
      context: context,
      builder: (_) => _DialogPenalidade(categoria: categoria, sub: sub),
    );

    if (resultado == null || !mounted) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro =
        await context.read<LancamentoBonusProvider>().lancarPenalidade(
              token: token,
              colaboradorId: _colaborador.id,
              subcategoriaId: sub.id,
              observacao: resultado.observacao,
              os: resultado.os,
            );

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Penalidade de ${sub.pontos} pontos lançada para "${sub.descricao}"',
          ),
        ),
      );
    }
  }

  Future<void> _editarPontosIniciais() async {
    final ctrl = TextEditingController(
      text: '${_colaborador.pontosIniciais}',
    );
    final formKey = GlobalKey<FormState>();

    final novoValor = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_moon_rounded,
                  color: AppTheme.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pontuação inicial do mês',
                style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pontos iniciais',
                helperText:
                    'Valor com o qual este colaborador começa cada mês, '
                    'antes de qualquer penalidade.',
                helperMaxLines: 3,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Informe um número válido';
                if (n < 0 || n > 1000) return 'Use um valor entre 0 e 1000';
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(int.parse(ctrl.text));
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(int.parse(ctrl.text));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novoValor == null || !mounted) return;
    if (novoValor == _colaborador.pontosIniciais) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro = await context.read<ColaboradorProvider>().editarPontosIniciais(
          token: token,
          colaborador: _colaborador,
          pontosIniciais: novoValor,
        );

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    setState(() {
      _colaborador = _colaborador.copyWith(pontosIniciais: novoValor);
    });

    // Recarrega o saldo do mês para refletir a nova base imediatamente.
    // (chamado direto no provider, sem passar por _carregarTudo, para não
    // acionar o loading de tela cheia numa simples atualização pontual)
    await context.read<LancamentoBonusProvider>().carregarPontuacao(
          token: token,
          colaboradorId: _colaborador.id,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pontuação inicial atualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colaborador = _colaborador;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          colaborador.nome,
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Histórico de penalidades',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(
              '/colaboradores/historico',
              extra: colaborador,
            ),
          ),
          IconButton(
            tooltip: 'Editar colaborador',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final resultado = await this.context.push<String>(
                '/colaboradores/editar',
                extra: colaborador,
              );
              if (!mounted) return;
              if (resultado != null) this.context.pop(resultado);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Enquanto os dados de pontuação/bônus deste colaborador ainda não
      // terminaram de carregar, mostra um loading em tela cheia. Isso evita
      // o "flash" com dados do colaborador visto anteriormente (que ficam
      // no provider até a nova busca terminar).
      body: !_prontoParaExibir
          ? const Center(child: CircularProgressIndicator())
          : _buildConteudo(context, colaborador),
    );
  }

  Widget _buildConteudo(BuildContext context, Colaborador colaborador) {
    final scheme = Theme.of(context).colorScheme;
    final lancamentoProvider = context.watch<LancamentoBonusProvider>();
    final bonusProvider = context.watch<BonusProvider>();

    final bonus = bonusProvider.bonusAtual != null &&
            bonusProvider.bonusAtual!.id == colaborador.bonusId
        ? bonusProvider.bonusAtual
        : null;

    final pontos = lancamentoProvider.pontosAtual;

    return RefreshIndicator(
      onRefresh: _carregarTudo,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _CartaoPontuacao(
                pontos: pontos,
                pontosIniciais: colaborador.pontosIniciais,
                carregando: lancamentoProvider.carregando && pontos == null,
                setor: colaborador.setor,
                onTap: _editarPontosIniciais,
              ),
              const SizedBox(height: 24),
              Text(
                'Categorias e subcategorias',
                style: GoogleFonts.raleway(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                'Toque em uma subcategoria para lançar uma penalidade.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                if (colaborador.bonusId == null) {
                  return const _EstadoVazio(
                    icon: Icons.link_off_rounded,
                    mensagem:
                        'Este colaborador ainda não tem um bônus vinculado.\n'
                        'Edite o cadastro para selecionar um.',
                  );
                }

                if (bonusProvider.carregando && bonus == null) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (bonus == null) {
                  return _EstadoVazio(
                    icon: Icons.error_outline_rounded,
                    mensagem: bonusProvider.erro ??
                        'Não foi possível carregar o bônus.',
                    corIcone: AppTheme.error,
                  );
                }

                if (bonus.categorias.isEmpty) {
                  return const _EstadoVazio(
                    icon: Icons.category_outlined,
                    mensagem: 'Este bônus ainda não tem categorias cadastradas.',
                  );
                }

                return Column(
                  children: bonus.categorias
                      .map((cat) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CategoriaSelecionavel(
                              categoria: cat,
                              onSelecionarSub: (sub) =>
                                  _selecionarSubcategoria(cat, sub),
                            ),
                          ))
                      .toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoPontuacao extends StatelessWidget {
  final int? pontos;
  final int pontosIniciais;
  final bool carregando;
  final String setor;
  final VoidCallback onTap;

  const _CartaoPontuacao({
    required this.pontos,
    required this.pontosIniciais,
    required this.carregando,
    required this.setor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valorPontos = pontos;
    final cor = valorPontos == null
        ? AppTheme.orange
        : valorPontos >= 70
            ? Colors.green
            : valorPontos >= 40
                ? AppTheme.orange
                : AppTheme.error;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_moon_rounded, color: cor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setor,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            '${pontos ?? pontosIniciais} pontos neste mês',
                            style: GoogleFonts.raleway(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: cor,
                            ),
                          ),
                    const SizedBox(height: 2),
                    Text(
                      'Base do mês: $pontosIniciais · toque para alterar',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriaSelecionavel extends StatelessWidget {
  final CategoriaBonus categoria;
  final void Function(SubcategoriaBonus sub) onSelecionarSub;

  const _CategoriaSelecionavel({
    required this.categoria,
    required this.onSelecionarSub,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.category_rounded,
                color: AppTheme.orange, size: 18),
          ),
          title: Text(
            categoria.nome,
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          children: categoria.subcategorias.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Sem subcategorias cadastradas.',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ]
              : categoria.subcategorias
                  .map((sub) => ListTile(
                        onTap: () => onSelecionarSub(sub),
                        mouseCursor: SystemMouseCursors.click,
                        title: Text(
                          sub.descricao,
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '-${sub.pontos}',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
        ),
      ),
    );
  }
}

/// Resultado do dialog de lançamento de penalidade.
class _DialogPenalidadeResultado {
  final String observacao;
  final String os;
  const _DialogPenalidadeResultado({required this.observacao, required this.os});
}

class _DialogPenalidade extends StatefulWidget {
  final CategoriaBonus categoria;
  final SubcategoriaBonus sub;

  const _DialogPenalidade({required this.categoria, required this.sub});

  @override
  State<_DialogPenalidade> createState() => _DialogPenalidadeState();
}

class _DialogPenalidadeState extends State<_DialogPenalidade> {
  final _formKey = GlobalKey<FormState>();
  final _observacaoCtrl = TextEditingController();
  final _osCtrl = TextEditingController();

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    _osCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // MediaQuery.of(context) dentro do Dialog já reflete o espaço visível
    // (descontando o teclado), então basta usar viewInsets.bottom uma vez.
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight - viewInsets.bottom - 80;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: maxDialogHeight > 200 ? maxDialogHeight : 200,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.report_gmailerrorred_rounded,
                                color: AppTheme.error,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lançar penalidade',
                              style: GoogleFonts.raleway(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${widget.categoria.nome} · ${widget.sub.descricao}',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '- ${widget.sub.pontos} pontos serão descontados',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _osCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Número da OS',
                          prefixIcon:
                              Icon(Icons.assignment_outlined, size: 18),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50)
                        ],
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a OS'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacaoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Observação',
                          hintText: 'Explique o motivo da penalidade',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500)
                        ],
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Explique o motivo'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.error),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.of(context).pop(
                          _DialogPenalidadeResultado(
                            observacao: _observacaoCtrl.text.trim(),
                            os: _osCtrl.text.trim(),
                          ),
                        );
                      }
                    },
                    child: const Text('Lançar penalidade'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final IconData icon;
  final String mensagem;
  final Color? corIcone;

  const _EstadoVazio({required this.icon, required this.mensagem, this.corIcone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: corIcone ?? scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}