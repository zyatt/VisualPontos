import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abre a [imagemUrl] em um visualizador de tela cheia, com zoom por
/// pinça/scroll (InteractiveViewer) e fundo escuro. Usado sempre que o
/// usuário toca em uma miniatura de imagem de um lançamento.
Future<void> abrirImagemEmTelaCheia(BuildContext context, String imagemUrl) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _VisualizadorImagem(imagemUrl: imagemUrl),
    ),
  );
}

class _VisualizadorImagem extends StatelessWidget {
  final String imagemUrl;

  const _VisualizadorImagem({required this.imagemUrl});

  @override
  Widget build(BuildContext context) {
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
      ),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            // Absorve o toque sobre a própria imagem, impedindo que ele
            // "vaze" para o GestureDetector de fundo e feche o visualizador
            // sem querer ao interagir com o zoom/pan.
            child: GestureDetector(
              onTap: () {},
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imagemUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (context, error, stack) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não foi possível carregar a imagem.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}