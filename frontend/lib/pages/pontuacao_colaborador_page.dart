import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/colaborador.dart';
import 'visao_geral_page.dart' show HistoricoPenalidadesArgs;
import '../models/categoria_bonus.dart';
import '../models/lancamento_bonus.dart';
import '../models/subcategoria_bonus.dart';
import '../models/motivo_bonus.dart';
import '../providers/bonus_provider.dart';
import '../providers/colaborador_provider.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/motivo_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';
import '../utils/relatorio_penalidades_pdf.dart';
import '../utils/seletor_mes_ano_relatorio.dart';
import '../widgets/visualizador_imagem_lancamento.dart';

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

  // Termo digitado no campo de busca de categorias/subcategorias.
  final _buscaCtrl = TextEditingController();
  String _buscaCategoria = '';

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

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  /// Filtra as categorias pelo termo de busca: mantém a categoria inteira
  /// se o nome dela bater, ou mantém apenas as subcategorias que baterem
  /// quando o nome da categoria não bater.
  List<CategoriaBonus> _filtrarCategorias(List<CategoriaBonus> categorias) {
    final termo = _buscaCategoria.trim().toLowerCase();
    if (termo.isEmpty) return categorias;

    final resultado = <CategoriaBonus>[];
    for (final cat in categorias) {
      final nomeCategoriaBate = cat.nome.toLowerCase().contains(termo);
      if (nomeCategoriaBate) {
        resultado.add(cat);
        continue;
      }

      final subsQueBatem = cat.subcategorias
          .where((sub) => sub.descricao.toLowerCase().contains(termo))
          .toList();
      if (subsQueBatem.isNotEmpty) {
        resultado.add(cat.copyWith(subcategorias: subsQueBatem));
      }
    }
    return resultado;
  }

  Future<void> _carregarTudo() async {
    if (mounted) setState(() => _prontoParaExibir = false);

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final agora = DateTime.now();

    await Future.wait([
      context.read<LancamentoBonusProvider>().carregarPontuacao(
            token: token,
            colaboradorId: _colaborador.id,
          ),
      // Necessário para poder gerar o PDF do mês corrente diretamente
      // desta tela (mostra as penalidades do mês atual).
      context.read<LancamentoBonusProvider>().carregarHistorico(
            token: token,
            colaboradorId: _colaborador.id,
            mes: agora.month,
            ano: agora.year,
          ),
      context.read<MotivoBonusProvider>().carregar(token: token),
    ]);

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
    final motivos = context.read<MotivoBonusProvider>().lista;
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final resultado = await showDialog<_DialogPenalidadeResultado>(
      context: context,
      builder: (_) => _DialogPenalidade(
        categoria: categoria,
        sub: sub,
        motivos: motivos,
        token: token,
        colaboradorId: _colaborador.id,
      ),
    );

    if (resultado == null || !mounted) return;

    String? imagemPath;
    if (resultado.imagemArquivo != null) {
      imagemPath = await context.read<LancamentoBonusProvider>().uploadImagem(
            token: token,
            arquivo: resultado.imagemArquivo!,
          );
      if (!mounted) return;
      if (imagemPath == null) {
        final prosseguirSemImagem = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Falha ao enviar imagem'),
                content: const Text(
                  'Não foi possível enviar a imagem anexada. Deseja lançar '
                  'a penalidade mesmo assim, sem a imagem?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Lançar sem imagem'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!prosseguirSemImagem || !mounted) return;
      }
    }

    final erro =
        await context.read<LancamentoBonusProvider>().lancarPenalidade(
              token: token,
              colaboradorId: _colaborador.id,
              subcategoriaId: sub.id,
              motivoId: resultado.motivoId,
              observacao: resultado.observacao,
              os: resultado.os,
              imagemPath: imagemPath,
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

  /// Abre o dialog de penalidade AVULSA (sem categoria/subcategoria do
  /// catálogo) — o usuário informa motivo, OS, observação e os pontos a
  /// descontar diretamente.
  Future<void> _lancarPenalidadeAvulsa() async {
    final motivos = context.read<MotivoBonusProvider>().lista;
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final resultado = await showDialog<_DialogPenalidadeAvulsaResultado>(
      context: context,
      builder: (_) => _DialogPenalidadeAvulsa(
        motivos: motivos,
        token: token,
        colaboradorId: _colaborador.id,
      ),
    );

    if (resultado == null || !mounted) return;

    String? imagemPath;
    if (resultado.imagemArquivo != null) {
      imagemPath = await context.read<LancamentoBonusProvider>().uploadImagem(
            token: token,
            arquivo: resultado.imagemArquivo!,
          );
      if (!mounted) return;
      if (imagemPath == null) {
        final prosseguirSemImagem = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Falha ao enviar imagem'),
                content: const Text(
                  'Não foi possível enviar a imagem anexada. Deseja lançar '
                  'a penalidade mesmo assim, sem a imagem?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Lançar sem imagem'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!prosseguirSemImagem || !mounted) return;
      }
    }

    final erro = await context.read<LancamentoBonusProvider>().lancarPenalidade(
          token: token,
          colaboradorId: _colaborador.id,
          pontos: resultado.pontos,
          motivoId: resultado.motivoId,
          observacao: resultado.observacao,
          os: resultado.os,
          imagemPath: imagemPath,
        );

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Penalidade avulsa de ${resultado.pontos} pontos lançada'),
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
          Tooltip(
            message: 'Cancelar',
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          Tooltip(
            message: 'Salvar pontuação inicial',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(int.parse(ctrl.text));
                }
              },
              child: const Text('Salvar'),
            ),
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

  Future<void> _gerarPdf() async {
    final escolha = await selecionarMesAnoRelatorio(
      context,
      titulo: 'Relatório de ${_colaborador.nome}',
      subtitulo: 'Selecione o mês do relatório de penalidades',
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
      final lancamentoProvider = context.read<LancamentoBonusProvider>();

      // Se o mês escolhido não é o corrente (já carregado em memória),
      // busca o histórico específico daquele período antes de gerar o PDF.
      if (!ehMesCorrente) {
        await lancamentoProvider.carregarHistorico(
          token: token,
          colaboradorId: _colaborador.id,
          mes: mes,
          ano: ano,
        );
      }

      if (!mounted) return;

      final resumoMotivos = await lancamentoProvider.buscarResumoMotivos(
        token: token,
        mes: mes,
        ano: ano,
        colaboradorIds: [_colaborador.id],
      );

      if (!mounted) return;

      await gerarRelatorioPenalidadesPdf(
        colaborador: _colaborador,
        mes: mes,
        ano: ano,
        lancamentos: lancamentoProvider.historico,
        pontosIniciais: _colaborador.pontosIniciais,
        bonus: context.read<BonusProvider>().bonusAtual,
        resumoMotivos: resumoMotivos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
      );
    } finally {
      if (navigator.canPop()) navigator.pop();

      // Se buscamos o histórico de outro mês, restaura o histórico do mês
      // corrente em memória para não deixar a tela (que exibe o mês atual)
      // com dados de um período diferente.
      if (!ehMesCorrente && mounted) {
        await context.read<LancamentoBonusProvider>().carregarHistorico(
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
            onPressed: _prontoParaExibir ? _gerarPdf : null,
          ),
          IconButton(
            tooltip: 'Histórico de penalidades',
            icon: const Icon(Icons.history_rounded),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () => context.push(
              '/colaboradores/historico',
              extra: colaborador,
            ),
          ),
          IconButton(
            tooltip: 'Editar colaborador',
            icon: const Icon(Icons.edit_outlined),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () async {
              final resultado = await this.context.push<String>(
                '/colaboradores/editar',
                extra: colaborador,
              );
              if (!mounted) return;
              if (resultado != null) this.context.pop(resultado);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: !_prontoParaExibir ? null : _carregarTudo,
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
    final valorBonus = lancamentoProvider.valorBonus;

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
                valorBonus: valorBonus,
                carregando: lancamentoProvider.carregando && pontos == null,
                setor: colaborador.setor,
                onTap: _editarPontosIniciais,
              ),
              const SizedBox(height: 16),
              _UltimasPenalidades(
                lancamentos: lancamentoProvider.historico,
                onVerTodas: () {
                  final agora = DateTime.now();
                  context.push(
                    '/colaboradores/historico',
                    extra: HistoricoPenalidadesArgs(
                      colaborador: colaborador,
                      ano: agora.year,
                      mes: agora.month,
                      // Sem lançamento específico para destacar — 0 não
                      // corresponde a nenhum id real, então nenhuma linha
                      // fica destacada na lista.
                      lancamentoId: 0,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (context.watch<UsuarioProvider>().usuario?.role.toUpperCase() ==
                  'ADMIN') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: 'Lançar penalidade avulsa (fora do catálogo)',
                    child: OutlinedButton.icon(
                      style: ButtonStyle(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                        foregroundColor:
                            WidgetStateProperty.all(AppTheme.error),
                        side: WidgetStateProperty.all(
                          BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                        ),
                      ),
                      onPressed: _lancarPenalidadeAvulsa,
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 18),
                      label: const Text('Lançar penalidade'),
                    ),
                  ),
                ),
              ],
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
              TextField(
                controller: _buscaCtrl,
                onChanged: (v) => setState(() => _buscaCategoria = v),
                decoration: InputDecoration(
                  hintText: 'Buscar categoria ou subcategoria',
                  hintStyle: GoogleFonts.nunito(fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _buscaCategoria.isEmpty
                      ? null
                      : Tooltip(
                          message: 'Limpar busca',
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            style: ButtonStyle(
                              mouseCursor: WidgetStateProperty.all(
                                  SystemMouseCursors.click),
                            ),
                            onPressed: () {
                              _buscaCtrl.clear();
                              setState(() => _buscaCategoria = '');
                            },
                          ),
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                style: GoogleFonts.nunito(fontSize: 14),
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

                final categoriasFiltradas =
                    _filtrarCategorias(bonus.categorias);

                if (categoriasFiltradas.isEmpty) {
                  return _EstadoVazio(
                    icon: Icons.search_off_rounded,
                    mensagem:
                        'Nenhum resultado para "${_buscaCtrl.text.trim()}".',
                  );
                }

                return Column(
                  children: categoriasFiltradas
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

/// Formata um valor double como moeda BRL simples (ex.: 1234.5 -> "R$ 1.234,50"),
/// sem depender de pacotes de internacionalização.
String _formatarValor(double valor) {
  final negativo = valor < 0;
  final abs = valor.abs();
  final partes = abs.toStringAsFixed(2).split('.');
  final inteiro = partes[0];
  final centavos = partes[1];

  final buffer = StringBuffer();
  for (int i = 0; i < inteiro.length; i++) {
    final posicaoDaDireita = inteiro.length - i;
    buffer.write(inteiro[i]);
    if (posicaoDaDireita > 1 && posicaoDaDireita % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${negativo ? '-' : ''}R\$ ${buffer.toString()},$centavos';
}

class _CartaoPontuacao extends StatelessWidget {
  final int? pontos;
  final int pontosIniciais;
  final double? valorBonus;
  final bool carregando;
  final String setor;
  final VoidCallback onTap;

  const _CartaoPontuacao({
    required this.pontos,
    required this.pontosIniciais,
    this.valorBonus,
    required this.carregando,
    required this.setor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valorPontos = pontos;
    final percentual = valorPontos == null || pontosIniciais <= 0
        ? null
        : valorPontos / pontosIniciais;
    final cor = percentual == null
        ? AppTheme.orange
        : percentual >= 0.7
            ? Colors.green
            : percentual >= 0.4
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
                    if (!carregando && valorBonus != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Bônus estimado: ${_formatarValor(valorBonus!)}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cor,
                        ),
                      ),
                    ],
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

/// Mostra as últimas penalidades lançadas ao colaborador (data/hora e OS),
/// com base no histórico do mês corrente já carregado pelo provider.
class _UltimasPenalidades extends StatelessWidget {
  final List<LancamentoBonus> lancamentos;
  final VoidCallback onVerTodas;

  static const int _limite = 3;

  const _UltimasPenalidades({
    required this.lancamentos,
    required this.onVerTodas,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (lancamentos.isEmpty) return const SizedBox.shrink();

    final ordenados = [...lancamentos]
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    final recentes = ordenados.take(_limite).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Últimas penalidades',
                    style: GoogleFonts.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Ver histórico completo',
                  child: TextButton(
                    onPressed: onVerTodas,
                    style: ButtonStyle(
                      mouseCursor:
                          WidgetStateProperty.all(SystemMouseCursors.click),
                    ),
                    child: const Text('Ver todas'),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < recentes.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            _PenalidadeRecenteTile(lancamento: recentes[i]),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _PenalidadeRecenteTile extends StatefulWidget {
  final LancamentoBonus lancamento;

  const _PenalidadeRecenteTile({required this.lancamento});

  @override
  State<_PenalidadeRecenteTile> createState() =>
      _PenalidadeRecenteTileState();
}

class _PenalidadeRecenteTileState extends State<_PenalidadeRecenteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lancamento = widget.lancamento;
    final dataFormatada =
        DateFormat('dd/MM/yyyy HH:mm').format(lancamento.criadoEm);
    final descricao = lancamento.ehAvulsa
        ? 'Penalidade avulsa'
        : (lancamento.subcategoriaDesc ?? 'Penalidade');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hover
            ? scheme.onSurface.withValues(alpha: 0.04)
            : Colors.transparent,
        child: InkWell(
          onTap: () => _abrirDetalheLancamento(context, lancamento),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dataFormatada · OS ${lancamento.os}',
                        style: GoogleFonts.nunito(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lancamento.imagemUrl != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.image_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${lancamento.pontos}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre um modal com todos os detalhes do lançamento: imagem (quando
/// houver), data/hora, OS, motivo e observação.
void _abrirDetalheLancamento(BuildContext context, LancamentoBonus lancamento) {
  final dataFormatada =
      DateFormat('dd/MM/yyyy HH:mm').format(lancamento.criadoEm);
  final descricao = lancamento.ehAvulsa
      ? 'Penalidade avulsa'
      : (lancamento.subcategoriaDesc ?? 'Penalidade');

  showDialog(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        descricao,
                        style: GoogleFonts.raleway(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                const SizedBox(height: 16),
                if (lancamento.imagemUrl != null) ...[
                  GestureDetector(
                    onTap: () => abrirImagemEmTelaCheia(
                        ctx, lancamento.imagemUrl!),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          lancamento.imagemUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 160,
                              alignment: Alignment.center,
                              color: scheme.surfaceContainerHighest,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Container(
                            height: 160,
                            alignment: Alignment.center,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _InfoLinhaDetalhe(rotulo: 'Data/Hora', valor: dataFormatada),
                const SizedBox(height: 10),
                _InfoLinhaDetalhe(rotulo: 'OS', valor: lancamento.os),
                if (lancamento.motivoNome != null &&
                    lancamento.motivoNome!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoLinhaDetalhe(
                      rotulo: 'Motivo', valor: lancamento.motivoNome!),
                ],
                if (lancamento.observacao.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoLinhaDetalhe(
                      rotulo: 'Observação', valor: lancamento.observacao),
                ],
                const SizedBox(height: 10),
                _InfoLinhaDetalhe(
                    rotulo: 'Lançado por', valor: lancamento.usuarioNome),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: 'Fechar',
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ButtonStyle(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      child: const Text('Fechar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _InfoLinhaDetalhe extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _InfoLinhaDetalhe({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: GoogleFonts.nunito(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: GoogleFonts.nunito(fontSize: 13.5, color: scheme.onSurface),
        ),
      ],
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
/// Verifica no backend se a [os] informada já teve uma penalidade lançada
/// para este colaborador nas últimas 24h. Se sim, mostra um dialog de
/// confirmação para o usuário decidir se quer prosseguir mesmo assim.
///
/// Retorna `true` quando é seguro prosseguir com o lançamento (OS não
/// encontrada, falha na verificação, ou o usuário confirmou mesmo com o
/// aviso) e `false` quando o usuário optou por cancelar.
Future<bool> _checarOsDuplicada({
  required BuildContext context,
  required String token,
  required int colaboradorId,
  required String os,
}) async {
  final resposta =
      await context.read<LancamentoBonusProvider>().verificarOsRecente(
            token: token,
            colaboradorId: colaboradorId,
            os: os,
          );

  if (!context.mounted) return false;

  // Sem indício de duplicidade (ou falha silenciosa na checagem): segue.
  if (resposta == null || !resposta.osEncontrada || resposta.osRecente == null) {
    return true;
  }

  final anterior = resposta.osRecente!;
  final dataFormatada =
      DateFormat('dd/MM/yyyy HH:mm').format(anterior.criadoEm);

  final confirmou = await showDialog<bool>(
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
            child: const Icon(Icons.warning_amber_rounded,
                color: AppTheme.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'OS já usada recentemente',
              style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        'Esta OS "$os" já teve uma penalidade lançada para este colaborador '
        'em $dataFormatada, por ${anterior.usuarioNome}'
        '${anterior.motivoNome != null && anterior.motivoNome!.isNotEmpty ? ' (${anterior.motivoNome})' : ''}.\n\n'
        'Deseja lançar mesmo assim?',
        style: GoogleFonts.nunito(fontSize: 13.5),
      ),
      actions: [
        Tooltip(
          message: 'Cancelar',
          child: TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        Tooltip(
          message: 'Lançar mesmo assim',
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.orange),
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lançar mesmo assim'),
          ),
        ),
      ],
    ),
  );

  return confirmou == true;
}

class _DialogPenalidadeResultado {
  final int motivoId;
  final String observacao;
  final String os;
  final File? imagemArquivo;
  const _DialogPenalidadeResultado({
    required this.motivoId,
    required this.observacao,
    required this.os,
    this.imagemArquivo,
  });
}

/// true quando o app está rodando em desktop (Windows/Linux/macOS), onde
/// não existe câmera integrada ao image_picker — nesses casos usamos o
/// file_picker (mais estável no Windows) para escolher um arquivo já
/// existente.
bool get _emDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Abre o seletor de arquivo nativo do desktop e retorna a imagem
/// escolhida, ou null se o usuário cancelar.
Future<File?> _escolherArquivoDesktop() async {
  final resultado = await FilePicker.platform.pickFiles(
    type: FileType.image,
  );
  final caminho = resultado?.files.single.path;
  return caminho != null ? File(caminho) : null;
}

/// Bottom sheet com as opções de anexar imagem: tirar foto agora ou
/// escolher um arquivo já existente no dispositivo (galeria/explorador).
/// No desktop não há câmera integrada, então só a opção de arquivo é
/// mostrada — indo direto ao seletor nativo, sem bottom sheet.
Future<File?> _escolherOrigemImagem(BuildContext context) {
  if (_emDesktop) {
    return _escolherArquivoDesktop();
  }

  return showModalBottomSheet<File?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () async {
              final foto = await ImagePicker()
                  .pickImage(source: ImageSource.camera, imageQuality: 80);
              if (ctx.mounted) {
                Navigator.of(ctx).pop(foto != null ? File(foto.path) : null);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () async {
              final arquivo = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (ctx.mounted) {
                Navigator.of(ctx)
                    .pop(arquivo != null ? File(arquivo.path) : null);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Campo reutilizável de anexo de imagem: mostra um botão para adicionar
/// quando vazio, ou uma miniatura com botão de remover quando já há uma
/// imagem escolhida.
class _CampoImagemAnexo extends StatelessWidget {
  final File? imagem;
  final ValueChanged<File?> onChanged;

  const _CampoImagemAnexo({
    required this.imagem,
    required this.onChanged,
  });

  Future<void> _selecionar(BuildContext context) async {
    final arquivo = await _escolherOrigemImagem(context);
    if (arquivo != null) {
      onChanged(arquivo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (imagem == null) {
      return OutlinedButton.icon(
        onPressed: () => _selecionar(context),
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: const Text('Anexar imagem (opcional)'),
        style: ButtonStyle(
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              imagem!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Imagem anexada',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Tooltip(
            message: 'Trocar imagem',
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _selecionar(context),
            ),
          ),
          Tooltip(
            message: 'Remover imagem',
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onChanged(null),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogPenalidade extends StatefulWidget {
  final CategoriaBonus categoria;
  final SubcategoriaBonus sub;
  final List<MotivoBonus> motivos;

  final String token;
  final int colaboradorId;

  const _DialogPenalidade({
    required this.categoria,
    required this.sub,
    required this.motivos,
    required this.token,
    required this.colaboradorId,
  });

  @override
  State<_DialogPenalidade> createState() => _DialogPenalidadeState();
}

class _DialogPenalidadeState extends State<_DialogPenalidade> {
  final _formKey = GlobalKey<FormState>();
  final _observacaoCtrl = TextEditingController();
  final _osCtrl = TextEditingController();
  int? _motivoId;
  bool _verificandoOs = false;
  File? _imagemSelecionada;

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    _osCtrl.dispose();
    super.dispose();
  }

  /// Confirma o envio: se a OS informada já teve penalidade lançada para
  /// este colaborador nas últimas 24h, avisa e pede confirmação antes de
  /// fechar o dialog com o resultado.
  Future<void> _confirmarEnvio() async {
    if (!_formKey.currentState!.validate()) return;

    final os = _osCtrl.text.trim();
    setState(() => _verificandoOs = true);
    final prosseguir = await _checarOsDuplicada(
      context: context,
      token: widget.token,
      colaboradorId: widget.colaboradorId,
      os: os,
    );
    if (!mounted) return;
    setState(() => _verificandoOs = false);

    if (!prosseguir) return;

    Navigator.of(context).pop(
      _DialogPenalidadeResultado(
        motivoId: _motivoId!,
        observacao: _observacaoCtrl.text.trim(),
        os: os,
        imagemArquivo: _imagemSelecionada,
      ),
    );
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
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _motivoId,
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          prefixIcon:
                              Icon(Icons.label_outline_rounded, size: 18),
                        ),
                        items: [
                          for (final motivo in widget.motivos)
                            DropdownMenuItem(
                              value: motivo.id,
                              child: Text(motivo.nome),
                            ),
                        ],
                        onChanged: (v) => setState(() => _motivoId = v),
                        validator: (v) =>
                            v == null ? 'Selecione o motivo' : null,
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      _CampoImagemAnexo(
                        imagem: _imagemSelecionada,
                        onChanged: (arquivo) =>
                            setState(() => _imagemSelecionada = arquivo),
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
                  Tooltip(
                    message: 'Cancelar',
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ButtonStyle(
                        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Lançar penalidade',
                    child: FilledButton(
                      style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(AppTheme.error),
                          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      onPressed: _verificandoOs ? null : _confirmarEnvio,
                      child: _verificandoOs
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lançar penalidade'),
                    ),
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

/// Resultado do dialog de lançamento de penalidade AVULSA (sem
/// categoria/subcategoria do catálogo — pontos informados manualmente).
class _DialogPenalidadeAvulsaResultado {
  final int pontos;
  final int motivoId;
  final String observacao;
  final String os;
  final File? imagemArquivo;
  const _DialogPenalidadeAvulsaResultado({
    required this.pontos,
    required this.motivoId,
    required this.observacao,
    required this.os,
    this.imagemArquivo,
  });
}

class _DialogPenalidadeAvulsa extends StatefulWidget {
  final List<MotivoBonus> motivos;
  final String token;
  final int colaboradorId;

  const _DialogPenalidadeAvulsa({
    required this.motivos,
    required this.token,
    required this.colaboradorId,
  });

  @override
  State<_DialogPenalidadeAvulsa> createState() =>
      _DialogPenalidadeAvulsaState();
}

class _DialogPenalidadeAvulsaState extends State<_DialogPenalidadeAvulsa> {
  final _formKey = GlobalKey<FormState>();
  final _pontosCtrl = TextEditingController();
  final _observacaoCtrl = TextEditingController();
  final _osCtrl = TextEditingController();
  int? _motivoId;
  bool _verificandoOs = false;
  File? _imagemSelecionada;

  @override
  void dispose() {
    _pontosCtrl.dispose();
    _observacaoCtrl.dispose();
    _osCtrl.dispose();
    super.dispose();
  }

  /// Confirma o envio: se a OS informada já teve penalidade lançada para
  /// este colaborador nas últimas 24h, avisa e pede confirmação antes de
  /// fechar o dialog com o resultado.
  Future<void> _confirmarEnvio() async {
    if (!_formKey.currentState!.validate()) return;

    final os = _osCtrl.text.trim();
    setState(() => _verificandoOs = true);
    final prosseguir = await _checarOsDuplicada(
      context: context,
      token: widget.token,
      colaboradorId: widget.colaboradorId,
      os: os,
    );
    if (!mounted) return;
    setState(() => _verificandoOs = false);

    if (!prosseguir) return;

    Navigator.of(context).pop(
      _DialogPenalidadeAvulsaResultado(
        pontos: int.parse(_pontosCtrl.text),
        motivoId: _motivoId!,
        observacao: _observacaoCtrl.text.trim(),
        os: os,
        imagemArquivo: _imagemSelecionada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                              'Lançar penalidade avulsa',
                              style: GoogleFonts.raleway(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sem categoria/subcategoria do catálogo — informe os '
                        'pontos manualmente.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pontosCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pontos a descontar',
                          prefixIcon:
                              Icon(Icons.remove_circle_outline_rounded, size: 18),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) {
                            return 'Informe um valor de pontos maior que zero';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _motivoId,
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          prefixIcon:
                              Icon(Icons.label_outline_rounded, size: 18),
                        ),
                        items: [
                          for (final motivo in widget.motivos)
                            DropdownMenuItem(
                              value: motivo.id,
                              child: Text(motivo.nome),
                            ),
                        ],
                        onChanged: (v) => setState(() => _motivoId = v),
                        validator: (v) =>
                            v == null ? 'Selecione o motivo' : null,
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      _CampoImagemAnexo(
                        imagem: _imagemSelecionada,
                        onChanged: (arquivo) =>
                            setState(() => _imagemSelecionada = arquivo),
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
                  Tooltip(
                    message: 'Cancelar',
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ButtonStyle(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Lançar penalidade',
                    child: FilledButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(AppTheme.error),
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      onPressed: _verificandoOs ? null : _confirmarEnvio,
                      child: _verificandoOs
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lançar penalidade'),
                    ),
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