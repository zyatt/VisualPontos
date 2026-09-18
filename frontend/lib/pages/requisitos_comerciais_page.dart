import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/requisito_comercial.dart';
import '../providers/requisito_comercial_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

/// Tela de gerenciamento (criar/editar/desativar) dos requisitos do
/// setor Comercial — mesmo papel que a tela de Motivos/Categorias tem
/// para o lado de bônus, mas para a lista global de requisitos usada
/// no checklist.
class RequisitosComerciaisPage extends StatefulWidget {
  const RequisitosComerciaisPage({super.key});

  @override
  State<RequisitosComerciaisPage> createState() => _RequisitosComerciaisPageState();
}

class _RequisitosComerciaisPageState extends State<RequisitosComerciaisPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<RequisitoComercialProvider>().carregar(token: token);
  }

  Future<void> _abrirFormulario({RequisitoComercial? requisito}) async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final nomeCtrl = TextEditingController(text: requisito?.nome ?? '');
    final descricaoCtrl = TextEditingController(text: requisito?.descricao ?? '');
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(requisito == null ? 'Novo requisito' : 'Editar requisito'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nomeCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(150)],
                    decoration: const InputDecoration(
                      labelText: 'Nome do requisito',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descricaoCtrl,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Critério de conformidade',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Tooltip(
              message: 'Cancelar',
              child: TextButton(
                onPressed: salvando ? null : () => Navigator.of(ctx).pop(false),
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
                onPressed: salvando
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setStateDialog(() => salvando = true);

                        final provider = context.read<RequisitoComercialProvider>();
                        final erro = requisito == null
                            ? await provider.cadastrar(
                                token: token,
                                nome: nomeCtrl.text.trim(),
                                descricao: descricaoCtrl.text.trim(),
                              )
                            : await provider.editar(
                                token: token,
                                id: requisito.id,
                                nome: nomeCtrl.text.trim(),
                                descricao: descricaoCtrl.text.trim(),
                              );

                        if (!ctx.mounted) return;

                        if (erro != null) {
                          setStateDialog(() => salvando = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(erro)),
                          );
                          return;
                        }

                        Navigator.of(ctx).pop(true);
                      },
                child: salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requisito == null
                ? 'Requisito cadastrado com sucesso'
                : 'Requisito atualizado com sucesso',
          ),
        ),
      );
    }
  }

  Future<void> _confirmarExclusao(RequisitoComercial requisito) async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir requisito'),
        content: Text(
          'Tem certeza que deseja excluir "${requisito.nome}"? '
          'Checklists já lançados com esse requisito continuam no histórico, '
          'mas ele deixa de aparecer em novos checklists.',
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

    if (confirmado != true || !mounted) return;

    final erro = await context
        .read<RequisitoComercialProvider>()
        .excluir(token: token, id: requisito.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(erro ?? 'Requisito excluído com sucesso'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<RequisitoComercialProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Requisitos · Comercial',
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Novo requisito',
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(),
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo requisito'),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: Builder(
          builder: (context) {
            if (provider.carregando && provider.lista.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.erro != null && provider.lista.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    provider.erro!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            }

            if (provider.lista.isEmpty) {
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
                            Icon(Icons.checklist_rtl_rounded,
                                size: 48, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum requisito cadastrado ainda.',
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

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: provider.lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final requisito = provider.lista[index];
                    return _RequisitoTile(
                      requisito: requisito,
                      onTap: () => _abrirFormulario(requisito: requisito),
                      onExcluir: () => _confirmarExclusao(requisito),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequisitoTile extends StatelessWidget {
  final RequisitoComercial requisito;
  final VoidCallback onTap;
  final VoidCallback onExcluir;

  const _RequisitoTile({
    required this.requisito,
    required this.onTap,
    required this.onExcluir,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: const Icon(
                  Icons.checklist_rtl_rounded,
                  color: AppTheme.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requisito.nome,
                      style: GoogleFonts.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requisito.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Excluir',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: scheme.onSurfaceVariant,
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