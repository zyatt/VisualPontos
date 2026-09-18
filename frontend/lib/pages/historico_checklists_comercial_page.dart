import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/checklist_comercial.dart';
import '../models/colaborador.dart';
import '../providers/checklist_comercial_provider.dart';
import '../providers/usuario_provider.dart';
import '../services/checklist_comercial_service.dart' show ResumoRequisito;
import '../theme/app_theme.dart';
import '../utils/relatorio_checklist_comercial_pdf.dart';
import 'novo_checklist_comercial_page.dart';

/// Navegação em 3 níveis para o histórico de checklists de um
/// colaborador comercial: Ano -> Mês -> Checklists. Mesmo padrão de
/// HistoricoPenalidadesPage, adaptado para requisitos/não-conformidade
/// em vez de pontos/bônus.
class HistoricoChecklistsComercialPage extends StatefulWidget {
  final Colaborador colaborador;

  const HistoricoChecklistsComercialPage({super.key, required this.colaborador});

  @override
  State<HistoricoChecklistsComercialPage> createState() =>
      _HistoricoChecklistsComercialPageState();
}

enum _Nivel { anos, meses, checklists }

class _HistoricoChecklistsComercialPageState
    extends State<HistoricoChecklistsComercialPage> {
  _Nivel _nivel = _Nivel.anos;
  int? _anoSelecionado;
  int? _mesSelecionado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    await context.read<ChecklistComercialProvider>().carregarHistorico(
          token: token,
          colaboradorId: widget.colaborador.id,
        );
  }

  bool get _podeEditar =>
      context.read<UsuarioProvider>().usuario?.role == 'ADMIN';

  Future<void> _abrirParaEdicao(ChecklistComercial checklist) async {
    if (!_podeEditar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas administradores podem editar um checklist já salvo'),
        ),
      );
      return;
    }

    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovoChecklistComercialPage(
          colaborador: widget.colaborador,
          osInicial: checklist.os,
        ),
      ),
    );

    if (salvou == true && mounted) {
      _carregar();
    }
  }

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  List<_GrupoMes> _agruparPorMes(List<ChecklistComercial> historico) {
    final mapa = <String, _GrupoMes>{};
    for (final checklist in historico) {
      final data = checklist.criadoEm;
      final chave = '${data.year}-${data.month.toString().padLeft(2, '0')}';
      mapa.putIfAbsent(
        chave,
        () => _GrupoMes(
          ano: data.year,
          mes: data.month,
          rotulo: _meses[data.month - 1],
          checklists: [],
        ),
      );
      mapa[chave]!.checklists.add(checklist);
    }
    return mapa.values.toList();
  }

  List<_GrupoAno> _agruparPorAno(List<_GrupoMes> gruposMes) {
    final mapa = <int, List<_GrupoMes>>{};
    for (final grupo in gruposMes) {
      mapa.putIfAbsent(grupo.ano, () => []).add(grupo);
    }
    final anos = mapa.entries.map((e) => _GrupoAno(ano: e.key, meses: e.value)).toList()
      ..sort((a, b) => b.ano.compareTo(a.ano));
    return anos;
  }

  void _abrirAno(int ano) {
    setState(() {
      _anoSelecionado = ano;
      _nivel = _Nivel.meses;
    });
  }

  void _abrirMes(_GrupoMes grupo) {
    setState(() {
      _mesSelecionado = grupo.mes;
      _nivel = _Nivel.checklists;
    });
  }

  bool _voltarNivel() {
    switch (_nivel) {
      case _Nivel.checklists:
        setState(() {
          _mesSelecionado = null;
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
      final resumoRequisitos = token == null
          ? const <ResumoRequisito>[]
          : await context.read<ChecklistComercialProvider>().buscarResumoRequisitos(
                token: token,
                mes: grupo.mes,
                ano: grupo.ano,
                colaboradorIds: [widget.colaborador.id],
              );

      await gerarRelatorioChecklistComercialPdf(
        colaborador: widget.colaborador,
        mes: grupo.mes,
        ano: grupo.ano,
        checklists: grupo.checklists,
        resumoRequisitos: resumoRequisitos,
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
      case _Nivel.checklists:
        final rotulo = _mesSelecionado != null ? _meses[_mesSelecionado! - 1] : '';
        return '${colaborador.nome} · $rotulo de $_anoSelecionado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChecklistComercialProvider>();

    _GrupoMes? grupoAtual;
    if (_nivel == _Nivel.checklists && !provider.carregando && provider.historico.isNotEmpty) {
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
            style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () {
              if (_voltarNivel()) Navigator.of(context).pop();
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
                  mensagem: 'Nenhum checklist lançado para este colaborador.',
                );
              }

              final gruposMes = _agruparPorMes(provider.historico);

              switch (_nivel) {
                case _Nivel.anos:
                  final anos = _agruparPorAno(gruposMes);
                  return _ListaAnos(anos: anos, onTap: _abrirAno);

                case _Nivel.meses:
                  final meses = gruposMes.where((g) => g.ano == _anoSelecionado).toList()
                    ..sort((a, b) => b.mes.compareTo(a.mes));
                  return _ListaMeses(meses: meses, onTap: _abrirMes);

                case _Nivel.checklists:
                  final grupo = gruposMes.cast<_GrupoMes?>().firstWhere(
                        (g) => g?.ano == _anoSelecionado && g?.mes == _mesSelecionado,
                        orElse: () => null,
                      );

                  if (grupo == null) {
                    return const _EstadoVazio(
                      icon: Icons.history_toggle_off_rounded,
                      mensagem: 'Nenhum checklist encontrado para este mês.',
                    );
                  }

                  return _ListaChecklists(
                    checklists: grupo.checklists,
                    onTap: _abrirParaEdicao,
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _GrupoMes {
  final int ano;
  final int mes;
  final String rotulo;
  final List<ChecklistComercial> checklists;

  _GrupoMes({required this.ano, required this.mes, required this.rotulo, required this.checklists});

  int get totalNaoConformidades =>
      checklists.fold<int>(0, (soma, c) => soma + c.itensNaoConformes.length);
}

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
            final totalChecklists = grupo.meses.fold<int>(0, (s, m) => s + m.checklists.length);
            return _CardNavegacao(
              titulo: '${grupo.ano}',
              subtitulo: '${grupo.meses.length} '
                  '${grupo.meses.length == 1 ? 'mês registrado' : 'meses registrados'}'
                  ' · $totalChecklists ${totalChecklists == 1 ? 'checklist' : 'checklists'}',
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
            final pendencias = grupo.totalNaoConformidades;
            return _CardNavegacao(
              titulo: grupo.rotulo,
              subtitulo: '${grupo.checklists.length} '
                  '${grupo.checklists.length == 1 ? 'checklist' : 'checklists'}',
              icone: Icons.calendar_month_rounded,
              destaque: pendencias == 0 ? 'OK' : '$pendencias pendência(s)',
              corDestaque: pendencias == 0 ? Colors.green[700] : AppTheme.error,
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
                    Text(titulo,
                        style: GoogleFonts.raleway(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (destaque != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _ListaChecklists extends StatelessWidget {
  final List<ChecklistComercial> checklists;
  final ValueChanged<ChecklistComercial> onTap;

  const _ListaChecklists({required this.checklists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: checklists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _ChecklistCard(checklist: checklists[index], onTap: () => onTap(checklists[index])),
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final ChecklistComercial checklist;
  final VoidCallback onTap;

  const _ChecklistCard({required this.checklist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(checklist.criadoEm);
    final naoConformes = checklist.itensNaoConformes;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('OS ${checklist.os}',
                        style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (naoConformes.isEmpty ? Colors.green : AppTheme.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      naoConformes.isEmpty ? 'Conforme' : '${naoConformes.length} pendência(s)',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: naoConformes.isEmpty ? Colors.green[700] : AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(dataFormatada,
                  style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _InfoLinha(rotulo: 'Lançado por', valor: checklist.usuarioNome),
              if (naoConformes.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final item in naoConformes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${item.requisitoNome}',
                            style: GoogleFonts.nunito(
                                fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                        if (item.observacao != null && item.observacao!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(item.observacao!,
                                style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
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
          TextSpan(text: '$rotulo: ', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  Text(mensagem,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(fontSize: 14, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}