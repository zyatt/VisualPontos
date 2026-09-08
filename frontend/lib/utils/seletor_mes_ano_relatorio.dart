import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

const List<String> _kMeses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Mostra um diálogo para o usuário escolher o mês/ano do relatório em PDF.
///
/// Por padrão sugere o mês corrente, mas permite navegar para meses/anos
/// anteriores — útil quando o usuário já está em um mês novo e quer
/// consultar o relatório do mês passado.
///
/// Retorna o (mes, ano) escolhido, ou `null` se o usuário cancelou.
Future<(int mes, int ano)?> selecionarMesAnoRelatorio(
  BuildContext context, {
  String titulo = 'Gerar relatório',
  String subtitulo = 'Selecione o mês do relatório',
  int? anoMinimo,
}) {
  final agora = DateTime.now();

  return showDialog<(int, int)>(
    context: context,
    builder: (ctx) => _SeletorMesAnoDialog(
      mesInicial: agora.month,
      anoInicial: agora.year,
      titulo: titulo,
      subtitulo: subtitulo,
      anoMinimo: anoMinimo ?? (agora.year - 5),
      anoMaximo: agora.year,
    ),
  );
}

class _SeletorMesAnoDialog extends StatefulWidget {
  final int mesInicial;
  final int anoInicial;
  final String titulo;
  final String subtitulo;
  final int anoMinimo;
  final int anoMaximo;

  const _SeletorMesAnoDialog({
    required this.mesInicial,
    required this.anoInicial,
    required this.titulo,
    required this.subtitulo,
    required this.anoMinimo,
    required this.anoMaximo,
  });

  @override
  State<_SeletorMesAnoDialog> createState() => _SeletorMesAnoDialogState();
}

class _SeletorMesAnoDialogState extends State<_SeletorMesAnoDialog> {
  late int _mes = widget.mesInicial;
  late int _ano = widget.anoInicial;

  bool get _podeAvancarAno => _ano < widget.anoMaximo;
  bool get _podeVoltarAno => _ano > widget.anoMinimo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: AppTheme.orange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.titulo,
              style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitulo,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // ── Seletor de ano ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BotaoSeta(
                  icon: Icons.chevron_left_rounded,
                  habilitado: _podeVoltarAno,
                  onTap: () => setState(() => _ano--),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '$_ano',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                _BotaoSeta(
                  icon: Icons.chevron_right_rounded,
                  habilitado: _podeAvancarAno,
                  onTap: () => setState(() => _ano++),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Grade de meses ────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final mes = index + 1;
                final desabilitado = _ano == widget.anoMaximo &&
                    mes > DateTime.now().month;
                final selecionado = mes == _mes;

                return MouseRegion(
                  cursor: desabilitado
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  child: Material(
                    color: selecionado
                        ? AppTheme.orange.withValues(alpha: 0.12)
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: desabilitado
                          ? null
                          : () => setState(() => _mes = mes),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selecionado
                                ? AppTheme.orange
                                : scheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _kMeses[index].substring(0, 3),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: selecionado
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: desabilitado
                                ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                : selecionado
                                    ? AppTheme.orange
                                    : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        Tooltip(
          message: 'Cancelar',
          child: TextButton(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ),
        Tooltip(
          message: 'Gerar PDF',
          child: FilledButton.icon(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            onPressed: () => Navigator.of(context).pop((_mes, _ano)),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Gerar PDF'),
          ),
        ),
      ],
    );
  }
}

class _BotaoSeta extends StatelessWidget {
  final IconData icon;
  final bool habilitado;
  final VoidCallback onTap;

  const _BotaoSeta({
    required this.icon,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: habilitado
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: habilitado ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 22,
              color: habilitado
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}