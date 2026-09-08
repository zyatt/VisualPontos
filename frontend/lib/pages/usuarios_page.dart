import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/usuario.dart';
import '../providers/usuario_admin_provider.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final token = context.read<UsuarioProvider>().token;
    if (token == null) return;
    await context.read<UsuarioAdminProvider>().carregarUsuarios(token: token);
  }

  Future<void> _abrirEdicao(Usuario usuario) async {
    final resultado = await context.push<String>(
      '/usuarios/editar',
      extra: usuario,
    );

    if (!mounted) return;

    if (resultado == 'editado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário atualizado com sucesso')),
      );
    } else if (resultado == 'excluido') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário excluído com sucesso')),
      );
    }
  }

  Future<void> _abrirCadastro() async {
    final cadastrou = await context.push<bool>('/usuarios/novo');
    if (cadastrou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário cadastrado com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuarioAdminProvider>();
    final meuId = context.watch<UsuarioProvider>().usuario?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Usuários',
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: Tooltip(
          message: 'Voltar',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Novo usuário',
              child: FilledButton.icon(
                onPressed: _abrirCadastro,
                style: ButtonStyle(
                  mouseCursor:
                      WidgetStateProperty.all(SystemMouseCursors.click),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Novo usuário'),
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
        child: Builder(
          builder: (context) {
            if (provider.carregando) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.erro != null && provider.usuarios.isEmpty) {
              return _EstadoVazio(
                icon: Icons.error_outline_rounded,
                mensagem: provider.erro!,
                corIcone: AppTheme.error,
              );
            }

            if (provider.usuarios.isEmpty) {
              return const _EstadoVazio(
                icon: Icons.person_outline_rounded,
                mensagem: 'Nenhum usuário cadastrado ainda.',
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: provider.usuarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final usuario = provider.usuarios[index];
                    return _UsuarioTile(
                      usuario: usuario,
                      ehVoceMesmo: usuario.id == meuId,
                      onEditar: () => _abrirEdicao(usuario),
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

class _UsuarioTile extends StatelessWidget {
  final Usuario usuario;
  final bool ehVoceMesmo;
  final VoidCallback onEditar;

  const _UsuarioTile({
    required this.usuario,
    required this.ehVoceMesmo,
    required this.onEditar,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            usuario.nome,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.raleway(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (ehVoceMesmo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Você',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${usuario.usuario} · ${usuario.role}',
                      overflow: TextOverflow.ellipsis,
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