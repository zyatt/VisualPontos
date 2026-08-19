import 'package:flutter/material.dart';
import '../services/update_service.dart';
import 'auto_update_dialog.dart';

/// Envolve a árvore do app e verifica, em segundo plano, se existe uma
/// nova versão publicada (via UPDATE_CHECK_URL no .env). Se existir,
/// mostra o diálogo de atualização.
class UpdateChecker extends StatefulWidget {
  final Widget child;

  /// Precisa ser a mesma GlobalKey passada em GoRouter(navigatorKey: ...),
  /// para que o diálogo consiga achar um BuildContext válido mesmo vindo
  /// de fora da árvore de rotas.
  final GlobalKey<NavigatorState> navigatorKey;

  const UpdateChecker({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _checkForUpdates();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isChecking && !_dialogVisible) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking || _dialogVisible) return;

    _isChecking = true;

    try {
      debugPrint('[UpdateChecker] Iniciando verificação...');

      final updateInfo = await UpdateService.checkForUpdates();

      if (updateInfo == null) {
        debugPrint('[UpdateChecker] Nenhuma atualização disponível');
        return;
      }

      debugPrint('[UpdateChecker] Atualização encontrada: ${updateInfo.latestVersion}');

      final navigatorState = widget.navigatorKey.currentState;
      if (navigatorState == null || !navigatorState.mounted) {
        debugPrint('[UpdateChecker] Navigator ainda não está pronto');
        return;
      }

      _dialogVisible = true;

      await AutoUpdateDialog.show(navigatorState.context, updateInfo);
    } catch (e, stack) {
      debugPrint('[UpdateChecker] ERRO ao verificar updates: $e');
      debugPrint('[UpdateChecker] Stack: $stack');
    } finally {
      _isChecking = false;
      _dialogVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}