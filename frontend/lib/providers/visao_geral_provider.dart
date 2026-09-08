import 'package:flutter/material.dart';
import '../models/colaborador.dart';
import '../models/lancamento_bonus.dart';
import '../services/colaborador_service.dart';
import '../services/lancamento_bonus_service.dart';

/// Pontuação do mês de um colaborador específico, usada apenas
/// para compor a listagem da Visão Geral (tela Início).
class PontuacaoResumo {
  final Colaborador colaborador;
  final int? pontosAtual;
  final double? valorBonus;
  final bool comErro;

  /// Lançamentos (penalidades/bônus) do mês corrente para esse colaborador,
  /// usados na lista horizontal de chips da Visão Geral.
  final List<LancamentoBonus> penalidadesMes;

  PontuacaoResumo({
    required this.colaborador,
    this.pontosAtual,
    this.valorBonus,
    this.comErro = false,
    this.penalidadesMes = const [],
  });

  /// Percentual do saldo em relação à base do mês (0.0 a 1.0+).
  /// Retorna null se ainda não há pontuação carregada.
  double? get percentual {
    final pontos = pontosAtual;
    if (pontos == null || colaborador.pontosIniciais <= 0) return null;
    return pontos / colaborador.pontosIniciais;
  }
}

/// Provider dedicado ao card "Visão geral" da tela Início: carrega todos
/// os colaboradores e, para cada um, a pontuação do mês corrente — em
/// paralelo, já que não existe um endpoint único que devolva tudo de uma vez.
///
/// É intencionalmente independente do [ColaboradorProvider] e do
/// [LancamentoBonusProvider] para não interferir no estado "singular"
/// (colaborador aberto) que essas outras telas já usam.
class VisaoGeralProvider extends ChangeNotifier {
  final ColaboradorService _colaboradorService = ColaboradorService();
  final LancamentoBonusService _lancamentoService = LancamentoBonusService();

  bool _carregando = false;
  String? _erro;
  List<PontuacaoResumo> _resumos = [];
  DateTime? _ultimaAtualizacao;

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<PontuacaoResumo> get resumos => _resumos;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;

  Future<void> carregar({required String token}) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    final colaboradoresRes = await _colaboradorService.listar(token: token);

    if (!colaboradoresRes.success) {
      _carregando = false;
      _erro = colaboradoresRes.message ?? 'Não foi possível carregar os colaboradores';
      notifyListeners();
      return;
    }

    final colaboradores = colaboradoresRes.colaboradores ?? [];

    final agora = DateTime.now();

    // Busca a pontuação e o histórico de todos em paralelo. Cada chamada
    // tem seu próprio timeout/erro tratado dentro do service, então
    // nenhuma falha isolada derruba as demais.
    final resultados = await Future.wait(colaboradores.map((c) async {
      final pontuacaoRes = await _lancamentoService.buscarPontuacao(
        token: token,
        colaboradorId: c.id,
      );

      List<LancamentoBonus> penalidadesMes = [];
      try {
        final historicoRes = await _lancamentoService.buscarHistorico(
          token: token,
          colaboradorId: c.id,
          mes: agora.month,
          ano: agora.year,
        );
        if (historicoRes.success) {
          penalidadesMes = List<LancamentoBonus>.from(historicoRes.lista ?? [])
            ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
        }
      } catch (_) {
        // Se o histórico falhar, a Visão Geral continua funcionando sem
        // a lista de chips — não deve derrubar o card do colaborador.
      }

      return PontuacaoResumo(
        colaborador: c,
        pontosAtual: pontuacaoRes.success ? pontuacaoRes.pontosAtual : null,
        valorBonus: pontuacaoRes.success ? pontuacaoRes.valorBonus : null,
        comErro: !pontuacaoRes.success,
        penalidadesMes: penalidadesMes,
      );
    }));

    // Ordena: primeiro quem está mais crítico (menor percentual), depois
    // por nome. Quem ainda não tem pontuação carregada (erro) vai ao final.
    resultados.sort((a, b) {
      final pa = a.percentual;
      final pb = b.percentual;
      if (pa == null && pb == null) {
        return a.colaborador.nome.compareTo(b.colaborador.nome);
      }
      if (pa == null) return 1;
      if (pb == null) return -1;
      final cmp = pa.compareTo(pb);
      if (cmp != 0) return cmp;
      return a.colaborador.nome.compareTo(b.colaborador.nome);
    });

    _resumos = resultados;
    _carregando = false;
    _ultimaAtualizacao = DateTime.now();
    notifyListeners();
  }
}