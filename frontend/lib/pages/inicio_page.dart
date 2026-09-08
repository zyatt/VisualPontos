import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:visual_premium/widgets/theme_transition.dart';
import '../providers/usuario_provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final scheme = Theme.of(context).colorScheme;

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.settings_rounded, color: AppTheme.orange),
                  const SizedBox(width: 10),
                  Text(
                    'Configurações',
                    style: GoogleFonts.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Trocar tema ───────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    mouseCursor: SystemMouseCursors.click,
                    leading: Icon(
                      themeProvider.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: themeProvider.isDark
                          ? const Color(0xFFFBBF24)
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      themeProvider.isDark ? 'Modo claro' : 'Modo escuro',
                      style: GoogleFonts.raleway(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      themeProvider.isDark
                          ? 'Mudar para o tema claro'
                          : 'Mudar para o tema escuro',
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      ThemeTransitionOverlay.of(context)?.switchTheme(
                        onSwitch: () => themeProvider.toggle(),
                      );
                      Navigator.of(dialogContext).pop();
                    },
                  ),

                  const SizedBox(height: 4),

                  // ── Sair ──────────────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    mouseCursor: SystemMouseCursors.click,
                    leading: Icon(Icons.logout_rounded, color: scheme.error),
                    title: Text(
                      'Sair',
                      style: GoogleFonts.raleway(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Encerrar sua sessão',
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      await context.read<UsuarioProvider>().logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
              actions: [
                Tooltip(
                  message: 'Fechar',
                  child: TextButton(
                    style: ButtonStyle(
                      mouseCursor: WidgetStateProperty.all(
                        SystemMouseCursors.click,
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Fechar',
                      style: GoogleFonts.raleway(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.orange,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'Controle de Pontos para Premiação',
              style: GoogleFonts.raleway(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configurações',
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(
                SystemMouseCursors.click,
              ),
            ),
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 480;

                  final cards = [
                    _InicioCard(
                      icon: Icons.dashboard_rounded,
                      title: 'Visão geral',
                      onTap: () => context.push('/visao-geral'),
                    ),
                    _InicioCard(
                      icon: Icons.groups_2_rounded,
                      title: 'Colaboradores',
                      onTap: () => context.push('/colaboradores'),
                    ),
                    _InicioCard(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Bônus',
                      onTap: () => context.push('/bonus'),
                    ),
                    _InicioCard(
                      icon: Icons.label_rounded,
                      title: 'Motivos',
                      onTap: () => context.push('/motivos'),
                    ),
                    _InicioCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Usuários',
                      onTap: () => context.push('/usuarios'),
                    ),
                  ];
                  if (!isWide) {
                    return Column(
                      children: [
                        for (final c in cards) ...[
                          c,
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final c in cards)
                        SizedBox(
                          width: (constraints.maxWidth - 16) / 2,
                          child: c,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InicioCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _InicioCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.raleway(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}