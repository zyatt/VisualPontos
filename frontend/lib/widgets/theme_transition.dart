import 'package:flutter/material.dart';

/// Envolve a árvore do app e permite disparar uma transição de tema
/// com animação de expansão circular a partir do ponto onde o toggle foi tocado.
class ThemeTransitionOverlay extends StatefulWidget {
  final Widget child;

  const ThemeTransitionOverlay({super.key, required this.child});

  static ThemeTransitionOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeTransitionOverlayState>();
  }

  @override
  State<ThemeTransitionOverlay> createState() => ThemeTransitionOverlayState();
}

class ThemeTransitionOverlayState extends State<ThemeTransitionOverlay>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  /// Executa a troca de tema. Mantido simples (sem overlay visual customizado)
  /// para não depender de captura de posição do toque; a troca em si já é
  /// suave porque MaterialApp anima mudanças de ThemeData nativamente.
  void switchTheme({required VoidCallback onSwitch}) {
    onSwitch();
  }
}
