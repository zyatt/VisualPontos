import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/colaborador.dart';
import '../providers/colaborador_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

class ColaboradoresPage extends StatefulWidget {
  const ColaboradoresPage({super.key});

  @override
  State<ColaboradoresPage> createState() => _ColaboradoresPageState();
}

class _ColaboradoresPageState extends State<ColaboradoresPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<ColaboradorProvider>().carregarColaboradores(token: token);
  }

  Future<void> _abrirPontuacao(Colaborador colaborador) async {
    final resultado = await context.push<String>(
      '/colaboradores/pontuacao',
      extra: colaborador,
    );

    if (!mounted) return;

    if (resultado == 'editado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador atualizado com sucesso')),
      );
    } else if (resultado == 'excluido') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador excluído com sucesso')),
      );
    }
  }

  Future<void> _abrirCadastro() async {
    final cadastrou = await context.push<bool>('/colaboradores/novo');
    if (cadastrou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador cadastrado com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ColaboradorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Colaboradores',
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
              onPressed: _abrirCadastro,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Novo colaborador'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: Builder(
          builder: (context) {
            if (provider.carregando && provider.colaboradores.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.erro != null && provider.colaboradores.isEmpty) {
              return _EstadoVazio(
                icon: Icons.error_outline_rounded,
                mensagem: provider.erro!,
                corIcone: AppTheme.error,
              );
            }

            if (provider.colaboradores.isEmpty) {
              return const _EstadoVazio(
                icon: Icons.groups_2_outlined,
                mensagem: 'Nenhum colaborador cadastrado ainda.',
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: provider.colaboradores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final colaborador = provider.colaboradores[index];
                    return _ColaboradorTile(
                      colaborador: colaborador,
                      onTap: () => _abrirPontuacao(colaborador),
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

class _ColaboradorTile extends StatelessWidget {
  final Colaborador colaborador;
  final VoidCallback onTap;

  const _ColaboradorTile({
    required this.colaborador,
    required this.onTap,
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
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.5),
            ),
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
                  Icons.person_rounded,
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
                      colaborador.nome,
                      style: GoogleFonts.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      colaborador.setor,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
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