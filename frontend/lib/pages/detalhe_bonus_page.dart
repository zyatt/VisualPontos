import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bonus.dart';
import '../models/categoria_bonus.dart';
import '../models/subcategoria_bonus.dart';
import '../models/observacao_bonus.dart';
import '../models/item_observacao_bonus.dart';
import '../providers/bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

class DetalheBonusPage extends StatefulWidget {
  final Bonus bonus;

  const DetalheBonusPage({super.key, required this.bonus});

  @override
  State<DetalheBonusPage> createState() => _DetalheBonusPageState();
}

class _DetalheBonusPageState extends State<DetalheBonusPage> {
  // Controla o loading de tela cheia ao abrir/trocar de bônus, evitando
  // mostrar por um instante os dados do bônus visitado anteriormente.
  bool _carregandoTelaCheia = true;

  @override
  void initState() {
    super.initState();
    // Usa microtask em vez de chamar direto: o provider pode notificar
    // listeners de forma síncrona (ex.: ao marcar carregando = true), e
    // fazer isso durante o build inicial do widget dispara
    // "setState() or markNeedsBuild() called during build".
    Future.microtask(_carregarTudo);
  }

  Future<void> _carregarTudo() async {
    if (mounted) setState(() => _carregandoTelaCheia = true);
    await _recarregar();
    if (mounted) setState(() => _carregandoTelaCheia = false);
  }

  Future<void> _recarregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context
        .read<BonusProvider>()
        .carregarDetalhe(token: token, id: widget.bonus.id);
  }

  String? get _token => context.read<UsuarioProvider>().token;
  BonusProvider get _provider => context.read<BonusProvider>();

  // ─── Bônus ──────────────────────────────────────────────────────────────

  Future<void> _editarNomeBonus() async {
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final ctrl = TextEditingController(text: bonus.nome);
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar nome',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nome do bônus'),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final erro = await _provider.editarNome(
        token: _token!, id: bonus.id, nome: ctrl.text.trim());
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _duplicarBonus() async {
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    await _abrirDialogoDuplicar(bonus);
  }

  Future<void> _abrirDialogoDuplicar(Bonus bonus) async {
    final ctrl = TextEditingController(text: '${bonus.nome} (cópia)');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
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
              child: const Icon(Icons.copy_all_rounded,
                  color: AppTheme.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Duplicar bônus',
                style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
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
              decoration: InputDecoration(
                labelText: 'Nome do novo bônus',
                helperText: 'Categorias e subcategorias de "${bonus.nome}" '
                    'serão copiadas.',
                helperMaxLines: 2,
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final erro = await _provider.duplicar(
      token: _token!,
      bonusId: bonus.id,
      nome: ctrl.text.trim(),
    );

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bônus duplicado com sucesso')),
      );
    }
  }

  Future<void> _excluirBonus() async {
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir bônus'),
        content: Text(
            'Deseja excluir "${bonus.nome}"?\n\nTodas as categorias e subcategorias serão removidos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final erro = await _provider.excluir(token: _token!, id: bonus.id);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      context.pop();
    }
  }

  // ─── Observação ─────────────────────────────────────────────────────────

  Future<void> _novaObservacao() async {
    final nomeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova observação',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: nomeCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da observação',
                hintText: 'Ex: Critérios de penalização',
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.criarObservacao(
        token: _token!, bonusId: bonus.id, nome: nomeCtrl.text.trim());
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _editarObservacao(ObservacaoBonus obs) async {
    final ctrl = TextEditingController(text: obs.nome);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar observação',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nome da observação'),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop('salvar');
                }
              },
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop('excluir'),
            child: const Text('Excluir'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop('salvar');
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || resultado == null) return;

    if (resultado == 'excluir') {
      await _excluirObservacao(obs);
      return;
    }

    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.editarObservacao(
      token: _token!,
      bonusId: bonus.id,
      observacaoId: obs.id,
      nome: ctrl.text.trim(),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _excluirObservacao(ObservacaoBonus obs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir observação'),
        content: Text(
            'Deseja excluir "${obs.nome}"?\n\nTodos os itens desta observação serão removidos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.excluirObservacao(
        token: _token!, bonusId: bonus.id, observacaoId: obs.id);
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  // ─── Item de observação ─────────────────────────────────────────────────

  Future<void> _novoItemObservacao(ObservacaoBonus obs) async {
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova descrição',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: descCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Atraso sem justificativa: -5%',
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              minLines: 2,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe a descrição'
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.criarItemObservacao(
      token: _token!,
      bonusId: bonus.id,
      observacaoId: obs.id,
      descricao: descCtrl.text.trim(),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _editarItemObservacao(
      ObservacaoBonus obs, ItemObservacaoBonus item) async {
    final descCtrl = TextEditingController(text: item.descricao);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar descrição',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: descCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Descrição'),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              minLines: 2,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe a descrição'
                  : null,
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop('excluir'),
            child: const Text('Excluir'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop('salvar');
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || resultado == null) return;

    if (resultado == 'excluir') {
      await _excluirItemObservacao(obs, item);
      return;
    }

    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.editarItemObservacao(
      token: _token!,
      bonusId: bonus.id,
      observacaoId: obs.id,
      itemId: item.id,
      descricao: descCtrl.text.trim(),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _excluirItemObservacao(
      ObservacaoBonus obs, ItemObservacaoBonus item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir item'),
        content: Text('Deseja excluir este item?\n"${item.descricao}"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.excluirItemObservacao(
      token: _token!,
      bonusId: bonus.id,
      observacaoId: obs.id,
      itemId: item.id,
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  // ─── Categoria ──────────────────────────────────────────────────────────

  Future<void> _novaCategoria() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova categoria',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nome da categoria'),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.criarCategoria(
        token: _token!, bonusId: bonus.id, nome: ctrl.text.trim());
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _editarCategoria(CategoriaBonus cat) async {
    final ctrl = TextEditingController(text: cat.nome);
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar categoria',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nome da categoria'),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop('salvar');
                }
              },
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop('excluir'),
            child: const Text('Excluir'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop('salvar');
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || resultado == null) return;

    if (resultado == 'excluir') {
      await _excluirCategoria(cat);
      return;
    }

    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.editarCategoria(
      token: _token!,
      bonusId: bonus.id,
      categoriaId: cat.id,
      nome: ctrl.text.trim(),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _excluirCategoria(CategoriaBonus cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text(
            'Deseja excluir "${cat.nome}"?\n\nTodos os subcategorias desta categoria serão removidos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.excluirCategoria(
        token: _token!, bonusId: bonus.id, categoriaId: cat.id);
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  // ─── Subcategoria ──────────────────────────────────────────────────────────

  Future<void> _novoSubcategoria(CategoriaBonus cat) async {
    final descCtrl = TextEditingController();
    final pontosCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova subcategoria',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descCtrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Descrição'),
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  minLines: 3,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a descrição'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pontosCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pontos',
                    prefixIcon:
                        Icon(Icons.star_outline_rounded, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLines: 1,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe os pontos';
                    if (int.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.criarSubcategoria(
      token: _token!,
      bonusId: bonus.id,
      categoriaId: cat.id,
      descricao: descCtrl.text.trim(),
      pontos: int.parse(pontosCtrl.text.trim()),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _editarSubcategoria(
      CategoriaBonus cat, SubcategoriaBonus sub) async {
    final descCtrl = TextEditingController(text: sub.descricao);
    final pontosCtrl = TextEditingController(text: sub.pontos.toString());
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar subcategoria',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descCtrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Descrição'),
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  minLines: 3,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a descrição'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pontosCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pontos',
                    prefixIcon:
                        Icon(Icons.star_outline_rounded, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLines: 1,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe os pontos';
                    if (int.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop('excluir'),
            child: const Text('Excluir'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop('salvar');
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || resultado == null) return;

    if (resultado == 'excluir') {
      await _excluirSubcategoria(cat, sub);
      return;
    }

    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.editarSubcategoria(
      token: _token!,
      bonusId: bonus.id,
      categoriaId: cat.id,
      subcategoriaId: sub.id,
      descricao: descCtrl.text.trim(),
      pontos: int.parse(pontosCtrl.text.trim()),
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _excluirSubcategoria(
      CategoriaBonus cat, SubcategoriaBonus sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir subcategoria'),
        content: Text('Deseja excluir esta subcategoria?\n"${sub.descricao}"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus =
        context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final erro = await _provider.excluirSubcategoria(
      token: _token!,
      bonusId: bonus.id,
      categoriaId: cat.id,
      subcategoriaId: sub.id,
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BonusProvider>();
    final scheme = Theme.of(context).colorScheme;

    // Enquanto carrega OU o dado do provider ainda não é deste bônus
    // (é do bônus visitado anteriormente), mostra loading de tela cheia
    // em vez de deixar o build antigo "vazar" por um instante.
    final dadoPertenceAoBonusAtual =
        provider.bonusAtual != null && provider.bonusAtual!.id == widget.bonus.id;

    if (_carregandoTelaCheia || !dadoPertenceAoBonusAtual) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.bonus.nome,
            style: GoogleFonts.raleway(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildConteudo(context, provider, provider.bonusAtual!, scheme);
  }

  Widget _buildConteudo(
    BuildContext context,
    BonusProvider provider,
    Bonus bonus,
    ColorScheme scheme,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          bonus.nome,
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Duplicar bônus',
            onPressed: _duplicarBonus,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar nome',
            onPressed: _editarNomeBonus,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: 'Excluir bônus',
            onPressed: _excluirBonus,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _recarregar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              slivers: [
                // ── Cabeçalho com total de pontos ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _TotalPontosCard(totalPontos: bonus.totalPontos),
                  ),
                ),

                // ── Observações ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ObservacoesSection(
                      observacoes: bonus.observacoes,
                      onNovaObservacao: _novaObservacao,
                      onEditarObservacao: _editarObservacao,
                      onNovoItem: _novoItemObservacao,
                      onEditarItem: _editarItemObservacao,
                    ),
                  ),
                ),

                // ── Botão nova categoria ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Categorias',
                          style: GoogleFonts.raleway(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _novaCategoria,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Nova categoria',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Lista de categorias ────────────────────────────────
                if (provider.carregando && bonus.categorias.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (bonus.categorias.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 32),
                      child: Center(
                        child: Text(
                          'Nenhuma categoria adicionada.\nToque em "Nova categoria" para começar.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CategoriaCard(
                            categoria: bonus.categorias[i],
                            onEditarCategoria: () =>
                                _editarCategoria(bonus.categorias[i]),
                            onNovaSubcategoria: () =>
                                _novoSubcategoria(bonus.categorias[i]),
                            onEditarSubcategoria: (sub) =>
                                _editarSubcategoria(bonus.categorias[i], sub),
                          ),
                        ),
                        childCount: bonus.categorias.length,
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

// ─── Widgets auxiliares ────────────────────────────────────────────────────

class _TotalPontosCard extends StatelessWidget {
  final int totalPontos;

  const _TotalPontosCard({required this.totalPontos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.orange, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total de pontos',
                style: GoogleFonts.nunito(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              Text(
                '$totalPontos pts',
                style: GoogleFonts.raleway(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final CategoriaBonus categoria;
  final VoidCallback onEditarCategoria;
  final VoidCallback onNovaSubcategoria;
  final void Function(SubcategoriaBonus) onEditarSubcategoria;

  const _CategoriaCard({
    required this.categoria,
    required this.onEditarCategoria,
    required this.onNovaSubcategoria,
    required this.onEditarSubcategoria,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da categoria (clicável para editar)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEditarCategoria,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.category_outlined,
                          color: AppTheme.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria.nome,
                            style: GoogleFonts.raleway(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ),

          if (categoria.subcategorias.isNotEmpty)
            Divider(
                height: 1,
                color: scheme.outline.withValues(alpha: 0.3)),

          // Lista de subcategorias
          ...categoria.subcategorias.map((sub) => _SubcategoriaTile(
                subcategoria: sub,
                onEditar: () => onEditarSubcategoria(sub),
              )),

          // Botão de nova subcategoria
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: TextButton.icon(
              onPressed: onNovaSubcategoria,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Adicionar subcategoria',
                style:
                    GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.orange,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoriaTile extends StatelessWidget {
  final SubcategoriaBonus subcategoria;
  final VoidCallback onEditar;

  const _SubcategoriaTile({
    required this.subcategoria,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEditar,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subcategoria.descricao,
                        style: GoogleFonts.nunito(
                            fontSize: 13, color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${subcategoria.pontos} pt${subcategoria.pontos != 1 ? 's' : ''}',
                    style: GoogleFonts.raleway(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObservacoesSection extends StatelessWidget {
  final List<ObservacaoBonus> observacoes;
  final VoidCallback onNovaObservacao;
  final void Function(ObservacaoBonus) onEditarObservacao;
  final void Function(ObservacaoBonus) onNovoItem;
  final void Function(ObservacaoBonus, ItemObservacaoBonus) onEditarItem;

  const _ObservacoesSection({
    required this.observacoes,
    required this.onNovaObservacao,
    required this.onEditarObservacao,
    required this.onNovoItem,
    required this.onEditarItem,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Observações',
              style: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onNovaObservacao,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Nova observação',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        if (observacoes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhuma observação adicionada.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          )
        else
          ...observacoes.map((obs) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ObservacaoCard(
                  observacao: obs,
                  onEditarObservacao: () => onEditarObservacao(obs),
                  onNovoItem: () => onNovoItem(obs),
                  onEditarItem: (item) => onEditarItem(obs, item),
                ),
              )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ObservacaoCard extends StatelessWidget {
  final ObservacaoBonus observacao;
  final VoidCallback onEditarObservacao;
  final VoidCallback onNovoItem;
  final void Function(ItemObservacaoBonus) onEditarItem;

  const _ObservacaoCard({
    required this.observacao,
    required this.onEditarObservacao,
    required this.onNovoItem,
    required this.onEditarItem,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEditarObservacao,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sticky_note_2_outlined,
                          color: AppTheme.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        observacao.nome,
                        style: GoogleFonts.raleway(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (observacao.itens.isNotEmpty)
            Divider(height: 1, color: scheme.outline.withValues(alpha: 0.3)),
          ...observacao.itens.map((item) => _ItemObservacaoTile(
                item: item,
                onEditar: () => onEditarItem(item),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: TextButton.icon(
              onPressed: onNovoItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Adicionar descrição',
                style:
                    GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.orange,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemObservacaoTile extends StatelessWidget {
  final ItemObservacaoBonus item;
  final VoidCallback onEditar;

  const _ItemObservacaoTile({
    required this.item,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEditar,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.descricao,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}