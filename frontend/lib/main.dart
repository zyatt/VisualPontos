import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/theme_provider.dart';
import 'providers/usuario_provider.dart';
import 'providers/usuario_admin_provider.dart';
import 'providers/colaborador_provider.dart';
import 'providers/bonus_provider.dart';
import 'providers/lancamento_bonus_provider.dart';
import 'providers/motivo_bonus_provider.dart';
import 'providers/visao_geral_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/theme_transition.dart';
import 'widgets/update_checker_widget.dart';
import 'pages/login_page.dart';
import 'pages/inicio_page.dart';
import 'pages/visao_geral_page.dart';
import 'pages/cadastro_usuario_page.dart';
import 'pages/cadastro_colaborador_page.dart';
import 'pages/colaboradores_page.dart';
import 'pages/pontuacao_colaborador_page.dart';
import 'pages/historico_penalidades_page.dart';
import 'pages/usuarios_page.dart';
import 'pages/bonus_page.dart';
import 'pages/detalhe_bonus_page.dart';
import 'pages/motivos_bonus_page.dart';
import 'models/colaborador.dart';
import 'models/usuario.dart';
import 'models/bonus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // ── Trava a janela em resolução de celular no desktop ─────────────────
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Resolução lógica tipo "celular" (ex.: iPhone 12/13/14)
    const windowSize = Size(440, 700);

    const windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: windowSize,
      maximumSize: windowSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const VisualPremiumApp());
}

class VisualPremiumApp extends StatelessWidget {
  const VisualPremiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UsuarioProvider()),
        ChangeNotifierProvider(create: (_) => UsuarioAdminProvider()),
        ChangeNotifierProvider(create: (_) => ColaboradorProvider()),
        ChangeNotifierProvider(create: (_) => BonusProvider()),
        ChangeNotifierProvider(create: (_) => LancamentoBonusProvider()),
        ChangeNotifierProvider(create: (_) => MotivoBonusProvider()),
        ChangeNotifierProvider(create: (_) => VisaoGeralProvider()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final GoRouter _router;

  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  bool _sessaoRestaurada = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final usuarioProvider = context.read<UsuarioProvider>();
      await usuarioProvider.restaurarSessao();
      if (!mounted) return;
      setState(() => _sessaoRestaurada = true);
      _router.refresh();
    });

    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/login',
      redirect: (context, state) {
        if (!_sessaoRestaurada) return null;

        final autenticado = context.read<UsuarioProvider>().autenticado;
        final indoParaLogin = state.matchedLocation == '/login';

        if (!autenticado && !indoParaLogin) return '/login';
        if (autenticado && indoParaLogin) return '/inicio';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/inicio',
          builder: (context, state) => const InicioPage(),
        ),
        GoRoute(
          path: '/visao-geral',
          builder: (context, state) => const VisaoGeralPage(),
        ),

        // ── Usuários ────────────────────────────────────────────────────
        GoRoute(
          path: '/usuarios',
          builder: (context, state) => const UsuariosPage(),
        ),
        GoRoute(
          path: '/usuarios/novo',
          builder: (context, state) => const CadastroUsuarioPage(),
        ),
        GoRoute(
          path: '/usuarios/editar',
          builder: (context, state) => CadastroUsuarioPage(
            usuarioParaEditar: state.extra as Usuario?,
          ),
        ),

        // ── Colaboradores ───────────────────────────────────────────────
        GoRoute(
          path: '/colaboradores',
          builder: (context, state) => const ColaboradoresPage(),
        ),
        GoRoute(
          path: '/colaboradores/novo',
          builder: (context, state) => const CadastroColaboradorPage(),
        ),
        GoRoute(
          path: '/colaboradores/editar',
          builder: (context, state) => CadastroColaboradorPage(
            colaboradorParaEditar: state.extra as Colaborador?,
          ),
        ),
        GoRoute(
          path: '/colaboradores/pontuacao',
          builder: (context, state) => PontuacaoColaboradorPage(
            colaborador: state.extra as Colaborador,
          ),
        ),
        GoRoute(
          path: '/colaboradores/historico',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is HistoricoPenalidadesArgs) {
              return HistoricoPenalidadesPage(
                colaborador: extra.colaborador,
                anoInicial: extra.ano,
                mesInicial: extra.mes,
                lancamentoDestacadoId: extra.lancamentoId,
              );
            }
            return HistoricoPenalidadesPage(
              colaborador: extra as Colaborador,
            );
          },
        ),

        // ── Bônus ───────────────────────────────────────────────────────
        GoRoute(
          path: '/bonus',
          builder: (context, state) => const BonusPage(),
        ),
        GoRoute(
          path: '/bonus/detalhe',
          builder: (context, state) => DetalheBonusPage(
            bonus: state.extra as Bonus,
          ),
        ),

        // ── Motivos ─────────────────────────────────────────────────────
        GoRoute(
          path: '/motivos',
          builder: (context, state) => const MotivosBonusPage(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    if (!_sessaoRestaurada) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeProvider.themeMode,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ThemeTransitionOverlay(
      child: UpdateChecker(
        navigatorKey: _rootNavigatorKey,
        child: MaterialApp.router(
          title: 'Visual Premium',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}