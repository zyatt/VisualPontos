import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bonus.dart';
import '../providers/bonus_provider.dart';
import '../providers/colaborador_provider.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../utils/relatorio_penalidades_pdf.dart';
import '../utils/seletor_mes_ano_relatorio.dart';

/// Abre um seletor de mês/ano (usando o mês/ano atuais) e, em seguida,
/// gera um único PDF com o relatório de penalidades de TODOS os
/// colaboradores carregados no [ColaboradorProvider].
///
/// Busca o histórico de lançamentos de cada colaborador no período
/// selecionado e, quando o colaborador tem um bônus vinculado, também
/// busca o DETALHE do [Bonus] correspondente (para exibir as
/// categorias/observações completas no PDF — o endpoint de listagem
/// não traz esses dados).
Future<void> abrirRelatorioGeralPenalidades(BuildContext context) async {
  final token = context.read<UsuarioProvider>().token;
  if (token == null) return;

  final colaboradorProvider = context.read<ColaboradorProvider>();
  final lancamentoProvider = context.read<LancamentoBonusProvider>();
  final bonusProvider = context.read<BonusProvider>();

  final colaboradores = colaboradorProvider.colaboradores;
  if (colaboradores.isEmpty) return;

  final escolha = await selecionarMesAnoRelatorio(
    context,
    titulo: 'Relatório geral',
    subtitulo: 'Selecione o mês do relatório de todos os colaboradores',
  );
  if (escolha == null || !context.mounted) return;

  final (mes, ano) = escolha;

  final navigator = Navigator.of(context, rootNavigator: true);

  // Mostra um indicador de progresso enquanto os dados de todos os
  // colaboradores são buscados e o PDF é montado.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Cache local dos DETALHES de bônus já buscados nesta geração de
    // relatório, para não buscar o mesmo bônus mais de uma vez quando
    // vários colaboradores compartilham o mesmo bônus.
    //
    // IMPORTANTE: não dá pra usar `bonusProvider.lista` (via
    // `bonusProvider.carregar`) aqui. O endpoint de listagem usado por
    // `carregar()` retorna os bônus "resumidos", sem `categorias` /
    // `observacoes` populadas — só o endpoint de detalhe (`buscar`,
    // usado por `carregarDetalhe`) retorna isso completo. É por isso
    // que o relatório individual (que usa `bonusProvider.bonusAtual`,
    // populado por `carregarDetalhe`) sempre mostrou as observações
    // corretamente, enquanto o geral não. Por isso aqui buscamos o
    // detalhe de cada bônus distinto, do mesmo jeito que a tela de
    // pontuação faz para o relatório individual.
    final detalhesBonus = <int, Bonus>{};

    final dadosPorColaborador = <DadosRelatorioColaborador>[];

    for (final colaborador in colaboradores) {
      await lancamentoProvider.carregarHistorico(
        token: token,
        colaboradorId: colaborador.id,
        mes: mes,
        ano: ano,
      );

      final lancamentos = List.of(lancamentoProvider.historico);

      Bonus? bonus;
      final bonusId = colaborador.bonusId;
      if (bonusId != null) {
        if (detalhesBonus.containsKey(bonusId)) {
          bonus = detalhesBonus[bonusId];
        } else {
          final erro = await bonusProvider.carregarDetalhe(
            token: token,
            id: bonusId,
          );
          if (erro == null && bonusProvider.bonusAtual?.id == bonusId) {
            bonus = bonusProvider.bonusAtual;
            detalhesBonus[bonusId] = bonus!;
          }
        }
      }

      dadosPorColaborador.add(
        DadosRelatorioColaborador(
          colaborador: colaborador,
          lancamentos: lancamentos,
          pontosIniciais: colaborador.pontosIniciais,
          bonus: bonus,
        ),
      );
    }

    final resumoMotivosGeral = await lancamentoProvider.buscarResumoMotivos(
      token: token,
      mes: mes,
      ano: ano,
      colaboradorIds: colaboradores.map((c) => c.id).toList(),
    );

    await gerarRelatorioGeralPenalidadesPdf(
      mes: mes,
      ano: ano,
      dadosPorColaborador: dadosPorColaborador,
      resumoMotivosGeral: resumoMotivosGeral,
    );
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}