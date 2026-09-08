import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/colaborador.dart';
import '../models/lancamento_bonus.dart';
import '../providers/usuario_provider.dart';
import '../providers/visao_geral_provider.dart';
import '../theme/app_theme.dart';

/// Argumentos passados via `extra` para a rota de histórico quando se
/// quer abrir direto num mês específico com um lançamento destacado
/// (usado ao clicar numa penalidade na Visão Geral).
class HistoricoPenalidadesArgs {
  final Colaborador colaborador;
  final int ano;
  final int mes;
  final int lancamentoId;

  const HistoricoPenalidadesArgs({
    required this.colaborador,
    required this.ano,
    required this.mes,
    required this.lancamentoId,
  });
}

/// Tela que lista todos os colaboradores com a pontuação do mês corrente,
/// dando uma visão rápida de todo mundo sem precisar entrar em
/// "Colaboradores" um por um.
class VisaoGeralPage extends StatefulWidget {
  const VisaoGeralPage({super.key});

  @override
  State<VisaoGeralPage> createState() => _VisaoGeralPageState();
}

class _VisaoGeralPageState extends State<VisaoGeralPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<VisaoGeralProvider>().carregar(token: token);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<VisaoGeralProvider>();
    final resumos = provider.resumos;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visão geral',
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          style: ButtonStyle(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: provider.carregando ? null : _carregar,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: Builder(builder: (context) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.erro != null && provider.resumos.isEmpty) {
            return _EstadoVazio(
              icon: Icons.error_outline_rounded,
              mensagem: provider.erro!,
              corIcone: AppTheme.error,
            );
          }

          if (resumos.isEmpty) {
            return const _EstadoVazio(
              icon: Icons.groups_2_outlined,
              mensagem: 'Nenhum colaborador cadastrado ainda.',
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: resumos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ColaboradorCard(
                  resumo: resumos[i],
                  onTap: () async {
                    await context.push(
                      '/colaboradores/pontuacao',
                      extra: resumos[i].colaborador,
                    );
                    if (context.mounted) _carregar();
                  },
                  onTapPenalidade: (lancamento) async {
                    await context.push(
                      '/colaboradores/historico',
                      extra: HistoricoPenalidadesArgs(
                        colaborador: resumos[i].colaborador,
                        ano: lancamento.criadoEm.year,
                        mes: lancamento.criadoEm.month,
                        lancamentoId: lancamento.id,
                      ),
                    );
                    if (context.mounted) _carregar();
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ColaboradorCard extends StatelessWidget {
  final PontuacaoResumo resumo;
  final VoidCallback onTap;
  final ValueChanged<LancamentoBonus> onTapPenalidade;

  const _ColaboradorCard({
    required this.resumo,
    required this.onTap,
    required this.onTapPenalidade,
  });

  Color _corPercentual(double? percentual) {
    if (percentual == null) return AppTheme.orange;
    if (percentual >= 0.7) return Colors.green;
    if (percentual >= 0.4) return AppTheme.orange;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colaborador = resumo.colaborador;
    final cor = _corPercentual(resumo.percentual);
    final percentual = resumo.percentual;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_rounded, color: cor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          colaborador.nome,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.raleway(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          colaborador.setor,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (percentual != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentual.clamp(0, 1).toDouble(),
                              minHeight: 5,
                              backgroundColor:
                                  scheme.outline.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation(cor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (resumo.comErro)
                    Tooltip(
                      message: 'Não foi possível carregar a pontuação',
                      child: Icon(Icons.error_outline_rounded,
                          size: 20, color: scheme.onSurfaceVariant),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${resumo.pontosAtual ?? colaborador.pontosIniciais} pts',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: cor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (resumo.valorBonus != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatarValor(resumo.valorBonus!),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              if (resumo.penalidadesMes.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: _ListaPenalidadesHorizontal(
                    penalidades: resumo.penalidadesMes,
                    onTapPenalidade: onTapPenalidade,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatarValor(double valor) {
    final s = valor.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }
}

/// Chip clicável exibindo uma penalidade do mês, ex: "Retrabalho · -11".
/// Ao ser tocado, leva para o histórico com o lançamento destacado.
/// Lista horizontal de chips de penalidade. No desktop, permite rolar
/// usando a roda do mouse (que normalmente só rola verticalmente) e
/// também arrastando com o clique — no touch, o drag já funciona nativo.
class _ListaPenalidadesHorizontal extends StatefulWidget {
  final List<LancamentoBonus> penalidades;
  final ValueChanged<LancamentoBonus> onTapPenalidade;

  const _ListaPenalidadesHorizontal({
    required this.penalidades,
    required this.onTapPenalidade,
  });

  @override
  State<_ListaPenalidadesHorizontal> createState() =>
      _ListaPenalidadesHorizontalState();
}

class _ListaPenalidadesHorizontalState
    extends State<_ListaPenalidadesHorizontal> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _controller.hasClients) {
      final delta = event.scrollDelta.dy != 0
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      final min = _controller.position.minScrollExtent;
      final max = _controller.position.maxScrollExtent;
      final offset = _controller.offset;

      // Nos extremos da lista horizontal, deixa o evento seguir pro pai
      // (a página) para que ele continue rolando verticalmente. Enquanto
      // ainda há espaço pra rolar horizontalmente, o evento é consumido
      // aqui e não propaga.
      final chegouNoLimite =
          (delta < 0 && offset <= min) || (delta > 0 && offset >= max);
      if (chegouNoLimite) return;

      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        final e = event as PointerScrollEvent;
        final novoOffset = (_controller.offset + e.scrollDelta.dy).clamp(min, max);
        _controller.jumpTo(novoOffset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemCount: widget.penalidades.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final lancamento = widget.penalidades[i];
            return _PenalidadeChip(
              lancamento: lancamento,
              onTap: () => widget.onTapPenalidade(lancamento),
            );
          },
        ),
      ),
    );
  }
}

class _PenalidadeChip extends StatelessWidget {
  final LancamentoBonus lancamento;
  final VoidCallback onTap;

  const _PenalidadeChip({required this.lancamento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: AppTheme.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  lancamento.ehAvulsa
                      ? 'Penalidade avulsa'
                      : ((lancamento.categoriaNome?.isNotEmpty ?? false)
                          ? lancamento.categoriaNome!
                          : (lancamento.subcategoriaDesc ?? '')),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${lancamento.pontos}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: corIcone ?? scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    mensagem,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}