import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/motivo_bonus.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/motivo_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';
import '../utils/relatorio_penalidades_pdf.dart';
import '../utils/seletor_mes_ano_relatorio.dart';

class MotivosBonusPage extends StatefulWidget {
  const MotivosBonusPage({super.key});

  @override
  State<MotivosBonusPage> createState() => _MotivosBonusPageState();
}

class _MotivosBonusPageState extends State<MotivosBonusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<MotivoBonusProvider>().carregar(token: token);
  }

  /// Abre o seletor de mês/ano e gera um PDF contendo apenas o resumo de
  /// penalidades por motivo (somando todos os colaboradores) — a mesma
  /// primeira página do relatório geral, sem as páginas de detalhe por
  /// colaborador.
  Future<void> _gerarPdfMotivos() async {
    final escolha = await selecionarMesAnoRelatorio(
      context,
      titulo: 'Relatório de motivos',
      subtitulo: 'Selecione o mês do resumo de penalidades por motivo',
    );
    if (escolha == null || !mounted) return;

    final (mes, ano) = escolha;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // colaboradorIds omitido: o backend soma penalidades de TODOS os
      // colaboradores quando a lista não é informada.
      final resumoMotivos =
          await context.read<LancamentoBonusProvider>().buscarResumoMotivos(
                token: token,
                mes: mes,
                ano: ano,
              );

      if (!mounted) return;

      await gerarRelatorioMotivosPdf(
        mes: mes,
        ano: ano,
        resumoMotivos: resumoMotivos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o PDF: $e')),
      );
    } finally {
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _abrirFormulario({MotivoBonus? motivo}) async {
    final editando = motivo != null;
    final ctrl = TextEditingController(text: motivo?.nome ?? '');
    final formKey = GlobalKey<FormState>();

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
              child: Icon(
                editando ? Icons.edit_rounded : Icons.add_rounded,
                color: AppTheme.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                editando ? 'Editar motivo' : 'Novo motivo',
                style: GoogleFonts.raleway(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do motivo',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
            ),
          ),
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
            message: editando ? 'Salvar' : 'Criar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(editando ? 'Salvar' : 'Criar'),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final provider = context.read<MotivoBonusProvider>();
    final erro = editando
        ? await provider.editar(
            token: token, id: motivo.id, nome: ctrl.text.trim())
        : await provider.criar(token: token, nome: ctrl.text.trim());

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editando
                ? 'Motivo atualizado com sucesso'
                : 'Motivo criado com sucesso',
          ),
        ),
      );
    }
  }

  Future<void> _excluir(MotivoBonus motivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir motivo'),
        content: Text(
          'Deseja excluir o motivo "${motivo.nome}"? '
          'Penalidades já lançadas com esse motivo manterão o registro.',
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro =
        await context.read<MotivoBonusProvider>().excluir(token: token, id: motivo.id);

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motivo excluído com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MotivoBonusProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Motivos',
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
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
            onPressed: _gerarPdfMotivos,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Novo motivo',
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(),
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo motivo'),
              ),
            ),
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
        child: Builder(builder: (context) {
          if (provider.carregando && provider.lista.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.erro != null && provider.lista.isEmpty) {
            return _EstadoVazio(
              icon: Icons.error_outline_rounded,
              mensagem: provider.erro!,
              corIcone: AppTheme.error,
            );
          }

          if (provider.lista.isEmpty) {
            return const _EstadoVazio(
              icon: Icons.label_outline_rounded,
              mensagem: 'Nenhum motivo cadastrado ainda.',
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: provider.lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final motivo = provider.lista[i];
                  return _MotivoTile(
                    motivo: motivo,
                    onEditar: () => _abrirFormulario(motivo: motivo),
                    onExcluir: () => _excluir(motivo),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MotivoTile extends StatelessWidget {
  final MotivoBonus motivo;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _MotivoTile({
    required this.motivo,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEditar,
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
                child: const Icon(Icons.label_rounded,
                    color: AppTheme.orange, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  motivo.nome,
                  style: GoogleFonts.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Tooltip(
                message: 'Excluir',
                child: IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: scheme.onSurfaceVariant, size: 20),
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: onExcluir,
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

  const _EstadoVazio(
      {required this.icon, required this.mensagem, this.corIcone});

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
                  Icon(icon,
                      size: 48, color: corIcone ?? scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(mensagem,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          fontSize: 14, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}