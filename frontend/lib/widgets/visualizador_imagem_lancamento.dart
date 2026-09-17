import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abre a [imagemUrl] em um visualizador de tela cheia, com zoom por
/// pinça/scroll (InteractiveViewer) e fundo escuro. Usado sempre que o
/// usuário toca em uma miniatura de imagem de um lançamento.
///
/// Mantido por compatibilidade — para lançamentos com mais de uma imagem,
/// prefira [abrirImagensEmTelaCheia], que permite deslizar entre elas.
Future<void> abrirImagemEmTelaCheia(BuildContext context, String imagemUrl) {
  return abrirImagensEmTelaCheia(context, [imagemUrl]);
}

/// Abre a galeria de [imagens] em tela cheia, a partir de [indiceInicial]
/// (ex.: a miniatura em que o usuário tocou). Permite deslizar entre as
/// imagens quando houver mais de uma, com zoom por pinça/scroll em cada
/// uma (InteractiveViewer) e fundo escuro.
Future<void> abrirImagensEmTelaCheia(
  BuildContext context,
  List<String> imagens, {
  int indiceInicial = 0,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _VisualizadorImagem(
        imagens: imagens,
        indiceInicial: indiceInicial,
      ),
    ),
  );
}

class _VisualizadorImagem extends StatefulWidget {
  final List<String> imagens;
  final int indiceInicial;

  const _VisualizadorImagem({
    required this.imagens,
    this.indiceInicial = 0,
  });

  @override
  State<_VisualizadorImagem> createState() => _VisualizadorImagemState();
}

class _VisualizadorImagemState extends State<_VisualizadorImagem> {
  late final PageController _controller;
  late int _indiceAtual;

  @override
  void initState() {
    super.initState();
    _indiceAtual = widget.indiceInicial.clamp(0, widget.imagens.length - 1);
    _controller = PageController(initialPage: _indiceAtual);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temVarias = widget.imagens.length > 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Tooltip(
          message: 'Voltar',
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
          ),
        ),
        title: temVarias
            ? Text(
                '${_indiceAtual + 1} de ${widget.imagens.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : null,
        centerTitle: true,
      ),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
            } else if (temVarias &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _controller.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            } else if (temVarias &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _controller.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        },
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.imagens.length,
                onPageChanged: (i) => setState(() => _indiceAtual = i),
                itemBuilder: (context, index) {
                  return Center(
                    // Absorve o toque sobre a própria imagem, impedindo que
                    // ele "vaze" para o GestureDetector de fundo e feche o
                    // visualizador sem querer ao interagir com o zoom/pan.
                    child: GestureDetector(
                      onTap: () {},
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.network(
                          widget.imagens[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const CircularProgressIndicator(
                                color: Colors.white);
                          },
                          errorBuilder: (context, error, stack) =>
                              const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Não foi possível carregar a imagem.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Setas de navegação (apenas quando há mais de uma imagem),
            // para trocar de imagem sem depender de swipe/teclado.
            if (temVarias) ...[
              if (_indiceAtual > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _BotaoSeta(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Imagem anterior',
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
              if (_indiceAtual < widget.imagens.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _BotaoSeta(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Próxima imagem',
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotaoSeta extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _BotaoSeta({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}