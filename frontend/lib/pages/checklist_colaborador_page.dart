import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/checklist_comercial.dart';
import '../models/colaborador.dart';
import '../providers/checklist_comercial_provider.dart';
import '../providers/colaborador_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';
import '../utils/relatorio_checklist_comercial_pdf.dart';
import '../utils/relatorio_geral_penalidades.dart' show setorComercial;
import '../utils/seletor_mes_ano_relatorio.dart';
import 'novo_checklist_comercial_page.dart';

/// Página aberta ao tocar em um colaborador do setor Comercial.
/// Equivalente à PontuacaoColaboradorPage, mas sem pontos/bônus: mostra
/// os últimos checklists (conferências de OS) e permite lançar um novo.
/// Mantém o colaborador em memória (igual PontuacaoColaboradorPage) para
/// que "Editar" possa atualizar o nome exibido sem precisar recarregar
/// a lista de colaboradores.
class ChecklistColaboradorPage extends StatefulWidget {
  final Colaborador colaborador;

  const ChecklistColaboradorPage({super.key, required this.colaborador});

  @override
  State<ChecklistColaboradorPage> createState() =>
      _ChecklistColaboradorPageState();
}

class _ChecklistColaboradorPageState extends State<ChecklistColaboradorPage> {
  late Colaborador _colaborador = widget.colaborador;

  final _buscaCtrl = TextEditingController();
  String _busca = '';
  int _pagina = 0;
  static const _porPagina = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final agora = DateTime.now();
    await context.read<ChecklistComercialProvider>().carregarHistorico(
          token: token,
          colaboradorId: _colaborador.id,
          mes: agora.month,
          ano: agora.year,
        );
  }

  Future<void> _novoChecklist() async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovoChecklistComercialPage(colaborador: _colaborador),
      ),
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist salvo com sucesso')),
      );
      _carregar();
    }
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
          colaborador: _colaborador,
          osInicial: checklist.os,
        ),
      ),
    );

    if (salvou == true && mounted) {
      _carregar();
    }
  }

  List<ChecklistComercial> _filtrar(List<ChecklistComercial> historico) {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return historico;
    return historico.where((c) => c.os.toLowerCase().contains(termo)).toList();
  }

  void _abrirHistoricoCompleto() {
    context.push('/colaboradores/checklist/historico', extra: _colaborador);
  }

  Future<void> _editar() async {
    final resultado = await context.push<String>(
      '/colaboradores/editar',
      extra: _colaborador,
    );

    if (!mounted) return;

    if (resultado == 'editado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador atualizado com sucesso')),
      );
      // editarColaborador (chamado dentro da tela de edição) já
      // atualiza a lista do ColaboradorProvider — buscamos o registro
      // atualizado ali por id em vez de inventar um método novo.
      final lista = context.read<ColaboradorProvider>().colaboradores;
      final atualizado = lista.where((c) => c.id == _colaborador.id).firstOrNull;
      if (atualizado != null && mounted) {
        setState(() => _colaborador = atualizado);
        // Se o setor deixou de ser Comercial, essa tela não é mais a
        // adequada para esse colaborador — volta para a listagem.
        if (atualizado.setor != setorComercial) {
          context.pop('editado');
        }
      }
    } else if (resultado == 'excluido') {
      if (mounted) context.pop('excluido');
    }
  }

  Future<void> _gerarPdf() async {
    final escolha = await selecionarMesAnoRelatorio(
      context,
      titulo: 'Relatório de ${_colaborador.nome}',
      subtitulo: 'Selecione o mês do relatório de checklist',
    );
    if (escolha == null || !mounted) return;

    final (mes, ano) = escolha;
    final agora = DateTime.now();
    final ehMesCorrente = mes == agora.month && ano == agora.year;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final checklistProvider = context.read<ChecklistComercialProvider>();

      if (!ehMesCorrente) {
        await checklistProvider.carregarHistorico(
          token: token,
          colaboradorId: _colaborador.id,
          mes: mes,
          ano: ano,
        );
      }

      if (!mounted) return;

      final resumoRequisitos = await checklistProvider.buscarResumoRequisitos(
        token: token,
        mes: mes,
        ano: ano,
        colaboradorIds: [_colaborador.id],
      );

      if (!mounted) return;

      await gerarRelatorioChecklistComercialPdf(
        colaborador: _colaborador,
        mes: mes,
        ano: ano,
        checklists: checklistProvider.historico,
        resumoRequisitos: resumoRequisitos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
      );
    } finally {
      if (navigator.canPop()) navigator.pop();

      if (!ehMesCorrente && mounted) {
        await context.read<ChecklistComercialProvider>().carregarHistorico(
              token: token,
              colaboradorId: _colaborador.id,
              mes: agora.month,
              ano: agora.year,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ChecklistComercialProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _colaborador.nome,
          style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700),
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
            tooltip: 'Gerar PDF do mês',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _gerarPdf,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico completo',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _abrirHistoricoCompleto,
          ),
          IconButton(
            tooltip: 'Editar colaborador',
            icon: const Icon(Icons.edit_outlined),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _editar,
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

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fact_check_outlined, color: AppTheme.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${provider.historico.length} checklists neste mês',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: 'Novo checklist',
                            child: ElevatedButton.icon(
                              onPressed: _novoChecklist,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ).copyWith(
                                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 18),
                              label: const Text('Novo checklist'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Últimos checklists',
                      style: GoogleFonts.raleway(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buscaCtrl,
                      onChanged: (v) => setState(() {
                        _busca = v;
                        _pagina = 0;
                      }),
                      decoration: InputDecoration(
                        hintText: 'Buscar por OS',
                        hintStyle: GoogleFonts.nunito(fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _busca.isEmpty
                            ? null
                            : Tooltip(
                                message: 'Limpar busca',
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  style: ButtonStyle(
                                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                                  ),
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    setState(() {
                                      _busca = '';
                                      _pagina = 0;
                                    });
                                  },
                                ),
                              ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final filtrados = _filtrar(provider.historico);

                      if (filtrados.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              _busca.isEmpty
                                  ? 'Nenhum checklist lançado neste mês.'
                                  : 'Nenhum checklist encontrado para "${_buscaCtrl.text.trim()}".',
                              style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      }

                      final totalPaginas = (filtrados.length / _porPagina).ceil();
                      final paginaAtual = _pagina.clamp(0, totalPaginas - 1);
                      final inicio = paginaAtual * _porPagina;
                      final fim = (inicio + _porPagina).clamp(0, filtrados.length);
                      final pagina = filtrados.sublist(inicio, fim);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final checklist in pagina)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChecklistTile(
                                checklist: checklist,
                                onTap: () => _abrirParaEdicao(checklist),
                              ),
                            ),
                          if (totalPaginas > 1) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Tooltip(
                                  message: 'Página anterior',
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    style: ButtonStyle(
                                      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                                    ),
                                    onPressed: paginaAtual == 0
                                        ? null
                                        : () => setState(() => _pagina = paginaAtual - 1),
                                  ),
                                ),
                                Text(
                                  'Página ${paginaAtual + 1} de $totalPaginas',
                                  style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurfaceVariant),
                                ),
                                Tooltip(
                                  message: 'Próxima página',
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    style: ButtonStyle(
                                      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                                    ),
                                    onPressed: paginaAtual >= totalPaginas - 1
                                        ? null
                                        : () => setState(() => _pagina = paginaAtual + 1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ChecklistComercial checklist;
  final VoidCallback onTap;

  const _ChecklistTile({required this.checklist, required this.onTap});

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
                    child: Text(
                      'OS ${checklist.os}',
                      style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
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
              const SizedBox(height: 4),
              Text(
                dataFormatada,
                style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (naoConformes.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final item in naoConformes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${item.requisitoNome}',
                      style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurface),
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