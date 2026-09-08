import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/colaborador.dart';
import '../models/lancamento_bonus.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../services/lancamento_bonus_service.dart' show ResumoMotivo;
import '../theme/app_theme.dart';
import '../utils/relatorio_penalidades_pdf.dart';

const int _kPontosIniciaisMes = 100;

/// Navegação em 3 níveis para o histórico de penalidades de um colaborador:
/// Ano -> Mês (com saldo de pontos do mês, iniciando em 100) -> Lançamentos.
class HistoricoPenalidadesPage extends StatefulWidget {
  final Colaborador colaborador;

  /// Quando informados (junto com [mesInicial]), a tela abre direto no
  /// nível de lançamentos daquele mês/ano, pulando a navegação por
  /// ano -> mês. Usado ao vir da Visão Geral, clicando numa penalidade.
  final int? anoInicial;
  final int? mesInicial;

  /// Id do lançamento a destacar visualmente ao abrir (também usado
  /// para rolar até ele), quando se navega direto para um mês.
  final int? lancamentoDestacadoId;

  const HistoricoPenalidadesPage({
    super.key,
    required this.colaborador,
    this.anoInicial,
    this.mesInicial,
    this.lancamentoDestacadoId,
  });

  @override
  State<HistoricoPenalidadesPage> createState() =>
      _HistoricoPenalidadesPageState();
}

enum _Nivel { anos, meses, lancamentos }

class _HistoricoPenalidadesPageState extends State<HistoricoPenalidadesPage> {
  late _Nivel _nivel;
  late int? _anoSelecionado;
  late int? _mesSelecionado;
  int? _lancamentoDestacadoId;

  final _lancamentoDestacadoKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    final temAlvoDireto =
        widget.anoInicial != null && widget.mesInicial != null;

    _nivel = temAlvoDireto ? _Nivel.lancamentos : _Nivel.anos;
    _anoSelecionado = widget.anoInicial;
    _mesSelecionado = widget.mesInicial;
    _lancamentoDestacadoId = widget.lancamentoDestacadoId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _carregar();
      _rolarParaDestacado();
    });
  }

  void _rolarParaDestacado() {
    if (_lancamentoDestacadoId == null || !mounted) return;
    // Aguarda o frame ser desenhado com a lista já carregada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lancamentoDestacadoKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      }
    });
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    await context.read<LancamentoBonusProvider>().carregarHistorico(
          token: token,
          colaboradorId: widget.colaborador.id,
        );
  }

  bool get _podeDesfazer =>
      context.read<UsuarioProvider>().usuario?.role == 'ADMIN';

  Future<void> _desfazer(LancamentoBonus lancamento) async {
    if (!_podeDesfazer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas administradores podem desfazer lançamentos'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desfazer lançamento'),
        content: Text(
          'Deseja desfazer a penalidade de ${lancamento.pontos.abs()} '
          'pontos em "${lancamento.ehAvulsa ? 'Penalidade avulsa' : lancamento.subcategoriaDesc}"?\n\n'
          'Os pontos serão devolvidos ao colaborador.',
        ),
        actions: [
          Tooltip(
            message: 'Cancelar',
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          Tooltip(
            message: 'Desfazer',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Desfazer'),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro = await context.read<LancamentoBonusProvider>().desfazerLancamento(
          token: token,
          id: lancamento.id,
        );

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento desfeito com sucesso')),
      );
    }
  }

  /// Agrupa os lançamentos por ano/mês (com base em [LancamentoBonus.criadoEm]).
  List<_GrupoMes> _agruparPorMes(List<LancamentoBonus> historico) {
    final mapa = <String, _GrupoMes>{};

    for (final lancamento in historico) {
      final data = lancamento.criadoEm;
      final chave = '${data.year}-${data.month.toString().padLeft(2, '0')}';

      mapa.putIfAbsent(
        chave,
        () => _GrupoMes(
          ano: data.year,
          mes: data.month,
          rotulo: _meses[data.month - 1],
          lancamentos: [],
        ),
      );
      mapa[chave]!.lancamentos.add(lancamento);
    }

    return mapa.values.toList();
  }

  /// Agrupa os grupos de mês por ano, do mais recente para o mais antigo.
  List<_GrupoAno> _agruparPorAno(List<_GrupoMes> gruposMes) {
    final mapa = <int, List<_GrupoMes>>{};
    for (final grupo in gruposMes) {
      mapa.putIfAbsent(grupo.ano, () => []).add(grupo);
    }

    final anos = mapa.entries
        .map((e) => _GrupoAno(ano: e.key, meses: e.value))
        .toList()
      ..sort((a, b) => b.ano.compareTo(a.ano));

    return anos;
  }

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  void _abrirAno(int ano) {
    setState(() {
      _anoSelecionado = ano;
      _nivel = _Nivel.meses;
    });
  }

  void _abrirMes(_GrupoMes grupo) {
    setState(() {
      _mesSelecionado = grupo.mes;
      _nivel = _Nivel.lancamentos;
    });
  }

  bool _voltarNivel() {
    switch (_nivel) {
      case _Nivel.lancamentos:
        setState(() {
          _mesSelecionado = null;
          _lancamentoDestacadoId = null;
          _nivel = _Nivel.meses;
        });
        return false;
      case _Nivel.meses:
        setState(() {
          _anoSelecionado = null;
          _nivel = _Nivel.anos;
        });
        return false;
      case _Nivel.anos:
        return true;
    }
  }

  Future<void> _gerarPdf(_GrupoMes grupo) async {
    try {
      final token = context.read<UsuarioProvider>().token;
      final resumoMotivos = token == null
          ? const <ResumoMotivo>[]
          : await context.read<LancamentoBonusProvider>().buscarResumoMotivos(
                token: token,
                mes: grupo.mes,
                ano: grupo.ano,
                colaboradorIds: [widget.colaborador.id],
              );

      await gerarRelatorioPenalidadesPdf(
        colaborador: widget.colaborador,
        mes: grupo.mes,
        ano: grupo.ano,
        lancamentos: grupo.lancamentos,
        pontosIniciais: _kPontosIniciaisMes,
        resumoMotivos: resumoMotivos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
      );
    }
  }

  String get _tituloAppBar {
    final colaborador = widget.colaborador;
    switch (_nivel) {
      case _Nivel.anos:
        return 'Histórico · ${colaborador.nome}';
      case _Nivel.meses:
        return '${colaborador.nome} · $_anoSelecionado';
      case _Nivel.lancamentos:
        final rotulo = _mesSelecionado != null ? _meses[_mesSelecionado! - 1] : '';
        return '${colaborador.nome} · $rotulo de $_anoSelecionado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<LancamentoBonusProvider>();

    // Quando estamos no nível de lançamentos, calcula o grupo do mês
    // selecionado para poder mostrar o botão de gerar PDF no AppBar.
    _GrupoMes? grupoAtual;
    if (_nivel == _Nivel.lancamentos &&
        !provider.carregando &&
        provider.historico.isNotEmpty) {
      final gruposMes = _agruparPorMes(provider.historico);
      grupoAtual = gruposMes.cast<_GrupoMes?>().firstWhere(
            (g) => g?.ano == _anoSelecionado && g?.mes == _mesSelecionado,
            orElse: () => null,
          );
    }

    return PopScope(
      canPop: _nivel == _Nivel.anos,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _voltarNivel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _tituloAppBar,
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
            onPressed: () {
              if (_voltarNivel()) context.pop();
            },
          ),
          actions: [
            if (grupoAtual != null)
              IconButton(
                tooltip: 'Gerar PDF do mês',
                icon: const Icon(Icons.picture_as_pdf_rounded),
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                onPressed: () => _gerarPdf(grupoAtual!),
              ),
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
          child: Builder(
            builder: (context) {
              if (provider.carregando) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.erro != null && provider.historico.isEmpty) {
                return _EstadoVazio(
                  icon: Icons.error_outline_rounded,
                  mensagem: provider.erro!,
                  corIcone: AppTheme.error,
                );
              }

              if (provider.historico.isEmpty) {
                return const _EstadoVazio(
                  icon: Icons.history_toggle_off_rounded,
                  mensagem: 'Nenhuma penalidade lançada para este colaborador.',
                );
              }

              final gruposMes = _agruparPorMes(provider.historico);

              switch (_nivel) {
                case _Nivel.anos:
                  final anos = _agruparPorAno(gruposMes);
                  return _ListaAnos(anos: anos, onTap: _abrirAno);

                case _Nivel.meses:
                  final meses = gruposMes
                      .where((g) => g.ano == _anoSelecionado)
                      .toList()
                    ..sort((a, b) => b.mes.compareTo(a.mes));
                  return _ListaMeses(meses: meses, onTap: _abrirMes);

                case _Nivel.lancamentos:
                  final grupo = gruposMes.cast<_GrupoMes?>().firstWhere(
                        (g) =>
                            g?.ano == _anoSelecionado &&
                            g?.mes == _mesSelecionado,
                        orElse: () => null,
                      );

                  if (grupo == null) {
                    return const _EstadoVazio(
                      icon: Icons.history_toggle_off_rounded,
                      mensagem: 'Nenhuma penalidade encontrada para este mês.',
                    );
                  }

                  return _ListaLancamentos(
                    lancamentos: grupo.lancamentos,
                    onDesfazer: _desfazer,
                    podeDesfazer: _podeDesfazer,
                    lancamentoDestacadoId: _lancamentoDestacadoId,
                    lancamentoDestacadoKey: _lancamentoDestacadoKey,
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Agrupamento de lançamentos de um mesmo mês/ano.
class _GrupoMes {
  final int ano;
  final int mes;
  final String rotulo;
  final List<LancamentoBonus> lancamentos;

  _GrupoMes({
    required this.ano,
    required this.mes,
    required this.rotulo,
    required this.lancamentos,
  });

  /// Saldo de pontos do colaborador no mês: começa em 100 e desconta
  /// a soma (em módulo) das penalidades lançadas nesse mês.
  int get saldoPontos {
    final totalPenalidades =
        lancamentos.fold<int>(0, (soma, l) => soma + l.pontos.abs());
    return _kPontosIniciaisMes - totalPenalidades;
  }
}

/// Agrupamento de meses de um mesmo ano.
class _GrupoAno {
  final int ano;
  final List<_GrupoMes> meses;

  _GrupoAno({required this.ano, required this.meses});
}

class _ListaAnos extends StatelessWidget {
  final List<_GrupoAno> anos;
  final ValueChanged<int> onTap;

  const _ListaAnos({required this.anos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: anos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final grupo = anos[index];
            final totalPenalidades = grupo.meses
                .fold<int>(0, (soma, m) => soma + m.lancamentos.length);
            return _CardNavegacao(
              titulo: '${grupo.ano}',
              subtitulo: '${grupo.meses.length} '
                  '${grupo.meses.length == 1 ? 'mês registrado' : 'meses registrados'}'
                  ' · $totalPenalidades '
                  '${totalPenalidades == 1 ? 'penalidade' : 'penalidades'}',
              icone: Icons.calendar_today_rounded,
              onTap: () => onTap(grupo.ano),
            );
          },
        ),
      ),
    );
  }
}

class _ListaMeses extends StatelessWidget {
  final List<_GrupoMes> meses;
  final ValueChanged<_GrupoMes> onTap;

  const _ListaMeses({required this.meses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: meses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final grupo = meses[index];
            final saldo = grupo.saldoPontos;
            return _CardNavegacao(
              titulo: grupo.rotulo,
              subtitulo: '${grupo.lancamentos.length} '
                  '${grupo.lancamentos.length == 1 ? 'penalidade' : 'penalidades'}',
              icone: Icons.calendar_month_rounded,
              destaque: '$saldo pts',
              corDestaque: saldo < _kPontosIniciaisMes ? AppTheme.error : null,
              onTap: () => onTap(grupo),
            );
          },
        ),
      ),
    );
  }
}

class _CardNavegacao extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final String? destaque;
  final Color? corDestaque;
  final VoidCallback onTap;

  const _CardNavegacao({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.onTap,
    this.destaque,
    this.corDestaque,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: AppTheme.orange, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: GoogleFonts.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (destaque != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (corDestaque ?? AppTheme.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    destaque!,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: corDestaque ?? AppTheme.orange,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaLancamentos extends StatelessWidget {
  final List<LancamentoBonus> lancamentos;
  final ValueChanged<LancamentoBonus> onDesfazer;
  final bool podeDesfazer;
  final int? lancamentoDestacadoId;
  final Key? lancamentoDestacadoKey;

  const _ListaLancamentos({
    required this.lancamentos,
    required this.onDesfazer,
    required this.podeDesfazer,
    this.lancamentoDestacadoId,
    this.lancamentoDestacadoKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: lancamentos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final lancamento = lancamentos[index];
            final destacado = lancamento.id == lancamentoDestacadoId;
            return _LancamentoTile(
              key: destacado ? lancamentoDestacadoKey : null,
              lancamento: lancamento,
              onDesfazer: () => onDesfazer(lancamento),
              podeDesfazer: podeDesfazer,
              destacado: destacado,
            );
          },
        ),
      ),
    );
  }
}

class _LancamentoTile extends StatelessWidget {
  final LancamentoBonus lancamento;
  final VoidCallback onDesfazer;
  final bool podeDesfazer;
  final bool destacado;

  const _LancamentoTile({
    super.key,
    required this.lancamento,
    required this.onDesfazer,
    required this.podeDesfazer,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataFormatada =
        DateFormat('dd/MM/yyyy HH:mm').format(lancamento.criadoEm);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destacado
            ? AppTheme.orange.withValues(alpha: 0.08)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado
              ? AppTheme.orange.withValues(alpha: 0.6)
              : scheme.outline.withValues(alpha: 0.5),
          width: destacado ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lancamento.ehAvulsa
                          ? 'Penalidade avulsa'
                          : '${lancamento.categoriaNome} · ${lancamento.subcategoriaDesc}',
                      style: GoogleFonts.raleway(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dataFormatada,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lancamento.pontos}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lancamento.motivoNome != null &&
              lancamento.motivoNome!.isNotEmpty) ...[
            _InfoLinha(rotulo: 'Motivo', valor: lancamento.motivoNome!),
            const SizedBox(height: 6),
          ],
          _InfoLinha(rotulo: 'OS', valor: lancamento.os),
          const SizedBox(height: 6),
          _InfoLinha(rotulo: 'Observação', valor: lancamento.observacao),
          const SizedBox(height: 6),
          _InfoLinha(rotulo: 'Lançado por', valor: lancamento.usuarioNome),
          if (podeDesfazer) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Desfazer',
                child: TextButton.icon(
                  onPressed: onDesfazer,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Desfazer'),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all(AppTheme.error),
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _InfoLinha({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      text: TextSpan(
        style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurface),
        children: [
          TextSpan(
            text: '$rotulo: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: valor),
        ],
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