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
import '../models/faixa_bonus.dart';
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

  // Busca de categorias/subcategorias.
  final TextEditingController _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    // Usa microtask em vez de chamar direto: o provider pode notificar
    // listeners de forma síncrona (ex.: ao marcar carregando = true), e
    // fazer isso durante o build inicial do widget dispara
    // "setState() or markNeedsBuild() called during build".
    Future.microtask(_carregarTudo);
    _buscaCtrl.addListener(() {
      setState(() => _busca = _buscaCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  /// Filtra as categorias pela busca: mantém a categoria se o nome dela
  /// contém o termo, OU se alguma subcategoria contém o termo (nesse caso,
  /// mostra só as subcategorias que baterem).
  List<CategoriaBonus> _categoriasFiltradas(List<CategoriaBonus> categorias) {
    if (_busca.isEmpty) return categorias;

    final resultado = <CategoriaBonus>[];
    for (final cat in categorias) {
      final nomeCatBate = cat.nome.toLowerCase().contains(_busca);
      final subsQueBatem = cat.subcategorias
          .where((s) => s.descricao.toLowerCase().contains(_busca))
          .toList();

      if (nomeCatBate) {
        // Nome da categoria bateu: mantém a categoria com todas as subs.
        resultado.add(cat);
      } else if (subsQueBatem.isNotEmpty) {
        // Só algumas subcategorias bateram: mostra a categoria só com elas.
        resultado.add(cat.copyWith(subcategorias: subsQueBatem));
      }
    }
    return resultado;
  }

  Future<void> _carregarTudo() async {
    await _recarregar();
  }

  Future<void> _recarregar() async {
    if (mounted) setState(() => _carregandoTelaCheia = true);
    final token = context.read<UsuarioProvider>().token;
    if (token == null) {
      if (mounted) setState(() => _carregandoTelaCheia = false);
      return;
    }
    await context
        .read<BonusProvider>()
        .carregarDetalhe(token: token, id: widget.bonus.id);
    if (mounted) setState(() => _carregandoTelaCheia = false);
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
            message: 'Salvar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('Salvar'),
            ),
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
            message: 'Duplicar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Duplicar'),
            ),
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
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

  // ─── FAIXA DE BÔNUS ─────────────────────────────────────────────────────

  Future<void> _novaFaixa() async {
    final pontosCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nova faixa de bônus',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pontosCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Pontos',
                    hintText: 'Ex: 90',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe os pontos';
                    }
                    final n = int.tryParse(v);
                    if (n == null || n < 0) {
                      return 'Pontos inválidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    hintText: 'Ex: 800',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o valor';
                    }
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                ),
              ],
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
            message: 'Adicionar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Adicionar'),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;
    final pontos = int.parse(pontosCtrl.text);
    final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));

    final erro = await _provider.criarFaixa(
      token: _token!,
      bonusId: bonus.id,
      pontos: pontos,
      valor: valor,
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _editarFaixa(FaixaBonus faixa) async {
    final pontosCtrl = TextEditingController(text: '${faixa.pontos}');
    final valorCtrl = TextEditingController(text: _formatarNumero(faixa.valor));
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar faixa',
            style: GoogleFonts.raleway(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pontosCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Pontos',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe os pontos';
                    }
                    final n = int.tryParse(v);
                    if (n == null || n < 0) {
                      return 'Pontos inválidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o valor';
                    }
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Tooltip(
            message: 'Excluir',
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop('excluir'),
              child: const Text('Excluir'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cancelar',
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  style: ButtonStyle(
                    mouseCursor:
                        WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              Tooltip(
                message: 'Salvar',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor:
                        WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (resultado == null || !mounted) return;
    final bonus = context.read<BonusProvider>().bonusAtual ?? widget.bonus;

    if (resultado == 'excluir') {
      final erro = await _provider.excluirFaixa(
        token: _token!,
        bonusId: bonus.id,
        faixaId: faixa.id,
      );
      if (mounted && erro != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(erro)));
      }
      return;
    }

    if (formKey.currentState?.validate() != true) return;
    final pontos = int.parse(pontosCtrl.text);
    final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));

    final erro = await _provider.editarFaixa(
      token: _token!,
      bonusId: bonus.id,
      faixaId: faixa.id,
      pontos: pontos,
      valor: valor,
    );
    if (mounted && erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  String _formatarNumero(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }

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
            message: 'Adicionar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('Adicionar'),
            ),
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
          Tooltip(
            message: 'Excluir',
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop('excluir'),
              child: const Text('Excluir'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cancelar',
                child: TextButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              Tooltip(
                message: 'Salvar',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                  child: const Text('Salvar'),
                ),
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
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
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
              minLines: 2,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe a descrição'
                  : null,
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
            message: 'Adicionar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('Adicionar'),
            ),
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
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
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
          Tooltip(
            message: 'Excluir',
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop('excluir'),
              child: const Text('Excluir'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cancelar',
                child: TextButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              Tooltip(
                message: 'Salvar',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                  child: const Text('Salvar'),
                ),
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
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
            message: 'Adicionar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('Adicionar'),
            ),
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
          Tooltip(
            message: 'Excluir',
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop('excluir'),
              child: const Text('Excluir'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cancelar',
                child: TextButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              Tooltip(
                message: 'Salvar',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                  child: const Text('Salvar'),
                ),
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
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
                  inputFormatters: [LengthLimitingTextInputFormatter(1000)],
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
            message: 'Adicionar',
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
              child: const Text('Adicionar'),
            ),
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
                  inputFormatters: [LengthLimitingTextInputFormatter(1000)],
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
          Tooltip(
            message: 'Excluir',
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop('excluir'),
              child: const Text('Excluir'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Cancelar',
                child: TextButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              Tooltip(
                message: 'Salvar',
                child: FilledButton(
                  style: ButtonStyle(
                    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(ctx).pop('salvar');
                    }
                  },
                  child: const Text('Salvar'),
                ),
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
            message: 'Excluir',
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(AppTheme.error),
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
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
              onPressed: null,
            ),
            const SizedBox(width: 4),
          ],
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
          tooltip: 'Voltar',
          style: ButtonStyle(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Duplicar bônus',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _duplicarBonus,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar nome',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _editarNomeBonus,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: 'Excluir bônus',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _excluirBonus,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: _recarregar,
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

                // ── Faixas de bônus ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _FaixasSection(
                      faixas: bonus.faixas,
                      onNovaFaixa: _novaFaixa,
                      onEditarFaixa: _editarFaixa,
                    ),
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
                        Tooltip(
                          message: 'Nova categoria',
                          child: TextButton.icon(
                            onPressed: _novaCategoria,
                            style: ButtonStyle(
                              mouseCursor: WidgetStateProperty.all(
                                  SystemMouseCursors.click),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text('Nova categoria',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Campo de busca de categoria/subcategoria ───────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _buscaCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar categoria ou subcategoria',
                        hintStyle: GoogleFonts.nunito(fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _busca.isEmpty
                            ? null
                            : Tooltip(
                                message: 'Limpar busca',
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18),
                                  style: ButtonStyle(
                                    mouseCursor: WidgetStateProperty.all(
                                        SystemMouseCursors.click),
                                  ),
                                  onPressed: () => _buscaCtrl.clear(),
                                ),
                              ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                  ),
                ),

                // ── Lista de categorias ────────────────────────────────
                Builder(builder: (context) {
                  final categoriasFiltradas =
                      _categoriasFiltradas(bonus.categorias);

                  if (provider.carregando && bonus.categorias.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (bonus.categorias.isEmpty) {
                    return SliverToBoxAdapter(
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
                    );
                  }

                  if (categoriasFiltradas.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 32),
                        child: Center(
                          child: Text(
                            'Nenhum resultado para "${_buscaCtrl.text.trim()}".',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final cat = categoriasFiltradas[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CategoriaCard(
                              categoria: cat,
                              onEditarCategoria: () => _editarCategoria(cat),
                              onNovaSubcategoria: () =>
                                  _novoSubcategoria(cat),
                              onEditarSubcategoria: (sub) =>
                                  _editarSubcategoria(cat, sub),
                            ),
                          );
                        },
                        childCount: categoriasFiltradas.length,
                      ),
                    ),
                  );
                }),
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
            child: Tooltip(
              message: 'Adicionar subcategoria',
              child: TextButton.icon(
                onPressed: onNovaSubcategoria,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(AppTheme.orange),
                  visualDensity: VisualDensity.compact,
                  mouseCursor:
                      WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Adicionar subcategoria',
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
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

class _FaixasSection extends StatelessWidget {
  final List<FaixaBonus> faixas;
  final VoidCallback onNovaFaixa;
  final void Function(FaixaBonus) onEditarFaixa;

  const _FaixasSection({
    required this.faixas,
    required this.onNovaFaixa,
    required this.onEditarFaixa,
  });

  String _formatarValor(double v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ordenadas = [...faixas]
      ..sort((a, b) => b.pontos.compareTo(a.pontos));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bônus',
              style: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: 'Nova faixa',
              child: TextButton.icon(
                onPressed: onNovaFaixa,
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Nova faixa',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ordenadas.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Nenhuma faixa cadastrada. Adicione faixas de pontos com o\n'
              'valor correspondente (ex: 90 pontos = R\$ 800).',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < ordenadas.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: scheme.outline.withValues(alpha: 0.3),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onEditarFaixa(ordenadas[i]),
                      mouseCursor: SystemMouseCursors.click,
                      borderRadius: BorderRadius.vertical(
                        top: i == 0 ? const Radius.circular(14) : Radius.zero,
                        bottom: i == ordenadas.length - 1
                            ? const Radius.circular(14)
                            : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${ordenadas[i].pontos} pts',
                                style: GoogleFonts.raleway(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatarValor(ordenadas[i].valor),
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
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
            Tooltip(
              message: 'Nova observação',
              child: TextButton.icon(
                onPressed: onNovaObservacao,
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Nova observação',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              ),
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
            child: Tooltip(
              message: 'Adicionar descrição',
              child: TextButton.icon(
                onPressed: onNovoItem,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(AppTheme.orange),
                  visualDensity: VisualDensity.compact,
                  mouseCursor:
                      WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Adicionar descrição',
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
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