import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bonus.dart';
import '../providers/bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

class BonusPage extends StatefulWidget {
  const BonusPage({super.key});

  @override
  State<BonusPage> createState() => _BonusPageState();
}

class _BonusPageState extends State<BonusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<BonusProvider>().carregar(token: token);
  }

  Future<void> _abrirDetalhe(Bonus bonus) async {
    await context.push('/bonus/detalhe', extra: bonus);
    // Recarrega a lista ao voltar (o detalhe pode ter alterado dados)
    if (mounted) _carregar();
  }

  Future<void> _duplicarBonus(Bonus bonus) async {
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

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro = await context.read<BonusProvider>().duplicar(
          token: token,
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

  Future<void> _mostrarMenuBonus(Bonus bonus, Offset posicaoGlobal) async {
    final selecionado = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        posicaoGlobal.dx,
        posicaoGlobal.dy,
        posicaoGlobal.dx,
        posicaoGlobal.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'duplicar',
          child: Row(
            children: [
              Icon(Icons.copy_all_outlined, size: 18),
              SizedBox(width: 10),
              Text('Duplicar'),
            ],
          ),
        ),
      ],
    );

    if (selecionado == 'duplicar' && mounted) {
      await _duplicarBonus(bonus);
    }
  }

  Future<void> _novoBonus() async {
    final nomeCtrl = TextEditingController();
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
              child: const Icon(Icons.add_rounded,
                  color: AppTheme.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Novo bônus',
              style: GoogleFonts.raleway(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: nomeCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do bônus',
                prefixIcon: Icon(Icons.workspace_premium_outlined, size: 18),
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              maxLines: 1,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              onFieldSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.raleway(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text('Criar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final erro = await context
        .read<BonusProvider>()
        .criar(token: token, nome: nomeCtrl.text.trim());

    if (!mounted) return;

    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bônus criado com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BonusProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bônus',
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _novoBonus,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Novo bônus'),
            ),
          ),
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
              icon: Icons.workspace_premium_outlined,
              mensagem: 'Nenhum bônus cadastrado ainda.',
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
                  final bonus = provider.lista[i];
                  return _BonusTile(
                    bonus: bonus,
                    onTap: () => _abrirDetalhe(bonus),
                    onLongPressAt: (posicao) =>
                        _mostrarMenuBonus(bonus, posicao),
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

class _BonusTile extends StatelessWidget {
  final Bonus bonus;
  final VoidCallback onTap;
  final void Function(Offset posicaoGlobal) onLongPressAt;

  const _BonusTile({
    required this.bonus,
    required this.onTap,
    required this.onLongPressAt,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPressStart: (details) => onLongPressAt(details.globalPosition),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: scheme.outline.withValues(alpha: 0.5)),
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
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppTheme.orange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bonus.nome,
                        style: GoogleFonts.raleway(
                          fontSize: 15,
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