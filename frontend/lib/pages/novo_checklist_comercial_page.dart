import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/checklist_comercial.dart';
import '../models/colaborador.dart';
import '../models/requisito_comercial.dart';
import '../providers/checklist_comercial_provider.dart';
import '../providers/requisito_comercial_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

/// Estado local de um requisito dentro do formulário: começa sempre
/// como conforme (OK); ao desmarcar, exige uma observação.
class _EstadoItem {
  final RequisitoComercial requisito;
  bool conforme;
  String observacao;

  _EstadoItem({
    required this.requisito,
    this.conforme = true,
    this.observacao = '',
  });
}

/// Tela de conferência de OS para colaboradores do setor Comercial.
/// Busca (ou recebe) um checklist existente pela OS para edição — só
/// ADMIN pode salvar alterações num checklist já existente — ou cria
/// um novo checklist do zero.
class NovoChecklistComercialPage extends StatefulWidget {
  final Colaborador colaborador;

  /// Quando informada, a tela pula a etapa de digitar/buscar a OS e
  /// já abre direto no formulário de conferência daquela OS (usado ao
  /// tocar num checklist já existente, na tela de histórico).
  final String? osInicial;

  const NovoChecklistComercialPage({
    super.key,
    required this.colaborador,
    this.osInicial,
  });

  @override
  State<NovoChecklistComercialPage> createState() =>
      _NovoChecklistComercialPageState();
}

class _NovoChecklistComercialPageState
    extends State<NovoChecklistComercialPage> {
  final _osCtrl = TextEditingController();
  final _osFormKey = GlobalKey<FormState>();

  bool _carregandoRequisitos = true;
  bool _buscandoOs = false;
  bool _salvando = false;

  List<_EstadoItem> _itens = [];

  // Quando a OS digitada já tinha um checklist salvo, guardamos o id
  // pra saber que devemos EDITAR (PUT) em vez de CRIAR (POST).
  int? _checklistExistenteId;
  String? _osConfirmada;

  bool get _podeEditar =>
      context.read<UsuarioProvider>().usuario?.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    if (widget.osInicial != null) {
      _osCtrl.text = widget.osInicial!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _carregarRequisitos();
      if (widget.osInicial != null && mounted) {
        await _confirmarOs();
      }
    });
  }

  @override
  void dispose() {
    _osCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarRequisitos() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    await context.read<RequisitoComercialProvider>().carregar(token: token);

    if (!mounted) return;
    setState(() => _carregandoRequisitos = false);
  }

  /// Monta a lista de itens em branco (tudo conforme) a partir da
  /// lista atual de requisitos.
  List<_EstadoItem> _itensEmBranco() {
    final requisitos = context.read<RequisitoComercialProvider>().lista;
    return [for (final r in requisitos) _EstadoItem(requisito: r)];
  }

  /// Monta a lista de itens a partir de um checklist já salvo (para
  /// edição), casando pelo requisito_id.
  List<_EstadoItem> _itensDoChecklist(ChecklistComercial checklist) {
    final requisitos = context.read<RequisitoComercialProvider>().lista;
    return [
      for (final r in requisitos)
        _EstadoItem(
          requisito: r,
          conforme: checklist.itens
              .where((i) => i.requisitoId == r.id)
              .firstOrNull
              ?.conforme ??
              true,
          observacao: checklist.itens
                  .where((i) => i.requisitoId == r.id)
                  .firstOrNull
                  ?.observacao ??
              '',
        ),
    ];
  }

  Future<void> _confirmarOs() async {
    // Quando vindo de osInicial (edição a partir do histórico), o form
    // da etapa de OS nem chega a ser construído — pula a validação
    // visual, já que o texto vem de um checklist que já existe.
    if (widget.osInicial == null && !_osFormKey.currentState!.validate()) {
      return;
    }

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final os = _osCtrl.text.trim();

    setState(() => _buscandoOs = true);

    final existente = await context.read<ChecklistComercialProvider>().buscarPorOs(
          token: token,
          colaboradorId: widget.colaborador.id,
          os: os,
        );

    if (!mounted) return;

    if (existente != null && !_podeEditar) {
      setState(() => _buscandoOs = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Já existe um checklist para essa OS. Apenas administradores '
            'podem editá-lo.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _buscandoOs = false;
      _osConfirmada = os;
      _checklistExistenteId = existente?.id;
      _itens = existente != null ? _itensDoChecklist(existente) : _itensEmBranco();
    });
  }

  Future<void> _alterarConformidade(_EstadoItem item, bool novoValor) async {
    if (novoValor) {
      setState(() {
        item.conforme = true;
        item.observacao = '';
      });
      return;
    }

    final observacaoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.requisito.nome),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.requisito.descricao,
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: observacaoCtrl,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  hintText: 'Descreva o que foi encontrado',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a observação' : null,
              ),
            ],
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
            message: 'Marcar como não realizado',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Marcar como não realizado'),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() {
        item.conforme = false;
        item.observacao = observacaoCtrl.text.trim();
      });
    }
  }

  Future<void> _salvar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null || _osConfirmada == null) return;

    setState(() => _salvando = true);

    final itensPayload = [
      for (final item in _itens)
        ChecklistItem(
          id: 0,
          requisitoId: item.requisito.id,
          requisitoNome: item.requisito.nome,
          requisitoDescricao: item.requisito.descricao,
          conforme: item.conforme,
          observacao: item.conforme ? null : item.observacao,
        ),
    ];

    final provider = context.read<ChecklistComercialProvider>();
    final erro = _checklistExistenteId != null
        ? await provider.editar(
            token: token,
            id: _checklistExistenteId!,
            os: _osConfirmada!,
            itens: itensPayload,
          )
        : await provider.criar(
            token: token,
            colaboradorId: widget.colaborador.id,
            os: _osConfirmada!,
            itens: itensPayload,
          );

    if (!mounted) return;
    setState(() => _salvando = false);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novo checklist · ${widget.colaborador.nome}',
          style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          style: ButtonStyle(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _carregandoRequisitos
          ? const Center(child: CircularProgressIndicator())
          : _osConfirmada == null
              ? _FormularioOs(
                  formKey: _osFormKey,
                  controller: _osCtrl,
                  carregando: _buscandoOs,
                  onConfirmar: _confirmarOs,
                )
              : _FormularioChecklist(
                  os: _osConfirmada!,
                  itens: _itens,
                  salvando: _salvando,
                  ehEdicao: _checklistExistenteId != null,
                  onAlterarConformidade: _alterarConformidade,
                  onSalvar: _salvar,
                ),
    );
  }
}

class _FormularioOs extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool carregando;
  final VoidCallback onConfirmar;

  const _FormularioOs({
    required this.formKey,
    required this.controller,
    required this.carregando,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Informe a OS a ser conferida',
                  style: GoogleFonts.raleway(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Se já existir um checklist salvo para essa OS, ele será '
                  'aberto para consulta ou edição.',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(
                    labelText: 'Número da OS',
                    prefixIcon: Icon(Icons.assignment_outlined, size: 18),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe a OS' : null,
                  onFieldSubmitted: (_) => onConfirmar(),
                ),
                const SizedBox(height: 20),
                Tooltip(
                  message: 'Continuar',
                  child: FilledButton(
                    style: ButtonStyle(
                      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                    ),
                    onPressed: carregando ? null : onConfirmar,
                    child: carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continuar'),
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

class _FormularioChecklist extends StatelessWidget {
  final String os;
  final List<_EstadoItem> itens;
  final bool salvando;
  final bool ehEdicao;
  final Future<void> Function(_EstadoItem, bool) onAlterarConformidade;
  final VoidCallback onSalvar;

  const _FormularioChecklist({
    required this.os,
    required this.itens,
    required this.salvando,
    required this.ehEdicao,
    required this.onAlterarConformidade,
    required this.onSalvar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalNaoConformes = itens.where((i) => !i.conforme).length;

    return Column(
      children: [
        if (ehEdicao)
          Container(
            width: double.infinity,
            color: AppTheme.orange.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Editando checklist já existente para a OS $os',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.orange,
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: itens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = itens[index];
                  return _CardRequisito(
                    item: item,
                    onAlterarConformidade: (v) => onAlterarConformidade(item, v),
                  );
                },
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  totalNaoConformes == 0
                      ? 'Todos os requisitos conformes'
                      : '$totalNaoConformes '
                          '${totalNaoConformes == 1 ? 'requisito não conforme' : 'requisitos não conformes'}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: totalNaoConformes == 0 ? Colors.green[700] : AppTheme.error,
                  ),
                ),
              ),
              Tooltip(
                message: 'Salvar checklist',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: salvando ? null : onSalvar,
                  child: salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar checklist'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardRequisito extends StatelessWidget {
  final _EstadoItem item;
  final ValueChanged<bool> onAlterarConformidade;

  const _CardRequisito({required this.item, required this.onAlterarConformidade});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conforme = item.conforme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conforme
              ? scheme.outline.withValues(alpha: 0.5)
              : AppTheme.error.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.requisito.nome,
                  style: GoogleFonts.raleway(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Tooltip(
                message: conforme ? 'Marcar como não realizado' : 'Marcar como conforme',
                child: Switch(
                  value: conforme,
                  activeThumbColor: Colors.green[600],
                  inactiveThumbColor: AppTheme.error,
                  onChanged: onAlterarConformidade,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.requisito.descricao,
            style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (!conforme) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurface),
                  children: [
                    const TextSpan(
                      text: 'Observação: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: item.observacao),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}