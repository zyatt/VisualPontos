import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'visualizador_imagem_lancamento.dart';

/// Faixa horizontal de miniaturas das imagens de um lançamento, usada
/// tanto no modal de detalhe quanto no card do histórico.
///
/// Sempre mostra uma barra de scroll horizontal visível (arrastável) e
/// permite navegar arrastando com o mouse (desktop) ou o dedo (mobile),
/// já que [PageView]/[ListView] por padrão só aceita arraste por touch.
class FaixaImagensLancamento extends StatefulWidget {
  final List<String> imagensUrl;
  final double altura;

  const FaixaImagensLancamento({
    super.key,
    required this.imagensUrl,
    this.altura = 120,
  });

  @override
  State<FaixaImagensLancamento> createState() =>
      _FaixaImagensLancamentoState();
}

class _FaixaImagensLancamentoState extends State<FaixaImagensLancamento> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unica = widget.imagensUrl.length == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // `double.infinity` aqui quebrava o layout: dentro de um ListView
        // horizontal (eixo principal já é ilimitado por natureza), pedir
        // width infinito para a imagem gerava "infinite size during
        // layout" e, em cascata, Rects com NaN. Em vez disso, usamos a
        // largura real disponível para o widget (herdada do pai — ex.: o
        // ConstrainedBox do dialog) e, só se por algum motivo ela também
        // vier ilimitada, caímos num múltiplo fixo da altura como
        // fallback seguro.
        final larguraUnica = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.altura * 2.4;

        return SizedBox(
          height: widget.altura + 14, // espaço extra p/ a scrollbar não cobrir a imagem
          child: ScrollConfiguration(
            // Habilita arraste com o mouse (botão esquerdo) para rolar a
            // lista horizontal também no desktop, além de touch/trackpad.
            behavior: _ArrastarComMouseBehavior(),
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.only(bottom: 14),
                scrollDirection: Axis.horizontal,
                itemCount: widget.imagensUrl.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = widget.imagensUrl[index];
                  return GestureDetector(
                    onTap: () => abrirImagensEmTelaCheia(
                      context,
                      widget.imagensUrl,
                      indiceInicial: index,
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          height: widget.altura,
                          width: unica ? larguraUnica : widget.altura,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: widget.altura,
                              width: unica ? larguraUnica : widget.altura,
                              alignment: Alignment.center,
                              color: scheme.surfaceContainerHighest,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Container(
                            height: widget.altura,
                            width: unica ? larguraUnica : widget.altura,
                            alignment: Alignment.center,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Permite que o gesto de arraste (drag) com o botão esquerdo do mouse
/// role listas horizontais/verticais, igual ao comportamento padrão em
/// touch. Sem isso, no desktop só dá pra rolar com a rodinha do mouse.
class _ArrastarComMouseBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}