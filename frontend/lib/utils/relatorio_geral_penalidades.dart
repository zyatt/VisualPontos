import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/bonus.dart';
import '../models/colaborador.dart';
import '../providers/bonus_provider.dart';
import '../providers/checklist_comercial_provider.dart';
import '../providers/colaborador_provider.dart';
import '../providers/lancamento_bonus_provider.dart';
import '../providers/usuario_provider.dart';
import '../utils/relatorio_checklist_comercial_pdf.dart';
import '../utils/relatorio_penalidades_pdf.dart';
import '../utils/seletor_mes_ano_relatorio.dart';

/// Nome do setor que ativa a lógica de requisitos/checklist (em vez de
/// pontos/bônus). Mesmo valor usado no seletor de setor do cadastro de
/// colaborador — ver cadastro_colaborador_page.dart.
const String setorComercial = 'Comercial';

/// Abre um seletor de mês/ano (usando o mês/ano atuais) e, em seguida,
/// gera um único PDF com o relatório de TODOS os colaboradores
/// carregados no [ColaboradorProvider] — colaboradores de bônus e do
/// setor Comercial entram juntos, cada um com a seção correspondente
/// ao seu tipo (bônus/pontos ou requisitos/checklist).
///
/// Por padrão gera o relatório de TODOS os colaboradores carregados no
/// [ColaboradorProvider]. Passando [colaboradoresFiltrados] (ex.: apenas
/// os colaboradores de um setor específico), o relatório é restrito a
/// esse subconjunto — usado quando o relatório é aberto de dentro da
/// página de um setor específico.
Future<void> abrirRelatorioGeralPenalidades(
  BuildContext context, {
  List<Colaborador>? colaboradoresFiltrados,
  String? setor,
}) async {
  final token = context.read<UsuarioProvider>().token;
  if (token == null) return;

  final colaboradorProvider = context.read<ColaboradorProvider>();
  final lancamentoProvider = context.read<LancamentoBonusProvider>();
  final bonusProvider = context.read<BonusProvider>();
  final checklistProvider = context.read<ChecklistComercialProvider>();

  final colaboradores =
      colaboradoresFiltrados ?? colaboradorProvider.colaboradores;
  if (colaboradores.isEmpty) return;

  final tituloSelecao = setor == null ? 'Relatório geral' : 'Relatório · $setor';
  final subtituloSelecao = setor == null
      ? 'Selecione o mês do relatório de todos os colaboradores'
      : 'Selecione o mês do relatório dos colaboradores de $setor';

  final escolha = await selecionarMesAnoRelatorio(
    context,
    titulo: tituloSelecao,
    subtitulo: subtituloSelecao,
  );
  if (escolha == null || !context.mounted) return;

  final (mes, ano) = escolha;

  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Separa os colaboradores pelo setor: os do Comercial seguem a
    // lógica de requisitos/checklist, os demais seguem a lógica de
    // bônus/pontos já existente.
    final colaboradoresBonus =
        colaboradores.where((c) => c.setor != setorComercial).toList();
    final colaboradoresComercial =
        colaboradores.where((c) => c.setor == setorComercial).toList();

    // ── Seção de bônus/pontos ──────────────────────────────────────
    final detalhesBonus = <int, Bonus>{};
    final dadosPorColaborador = <DadosRelatorioColaborador>[];

    for (final colaborador in colaboradoresBonus) {
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
          final erro = await bonusProvider.carregarDetalhe(token: token, id: bonusId);
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

    final resumoMotivosGeral = colaboradoresBonus.isEmpty
        ? const <dynamic>[]
        : await lancamentoProvider.buscarResumoMotivos(
            token: token,
            mes: mes,
            ano: ano,
            colaboradorIds: colaboradoresBonus.map((c) => c.id).toList(),
          );

    // ── Seção comercial (requisitos/checklist) ─────────────────────
    final dadosPorColaboradorComercial = <DadosRelatorioComercial>[];

    for (final colaborador in colaboradoresComercial) {
      await checklistProvider.carregarHistorico(
        token: token,
        colaboradorId: colaborador.id,
        mes: mes,
        ano: ano,
      );

      dadosPorColaboradorComercial.add(
        DadosRelatorioComercial(
          colaborador: colaborador,
          checklists: List.of(checklistProvider.historico),
        ),
      );
    }

    // ── Monta o PDF geral: bônus primeiro, comercial depois ────────
    final subtituloFinal = setor ?? 'Todos os colaboradores';
    final nomeArquivo = setor == null
        ? null
        : 'relatorio_${gerarNomeArquivoSeguro(setor)}_${ano}_${mes.toString().padLeft(2, '0')}';

    await _gerarRelatorioGeralMisto(
      mes: mes,
      ano: ano,
      dadosPorColaborador: dadosPorColaborador,
      resumoMotivosGeral: resumoMotivosGeral.cast(),
      dadosPorColaboradorComercial: dadosPorColaboradorComercial,
      subtitulo: subtituloFinal,
      nomeArquivo: nomeArquivo,
    );
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// Monta um único documento PDF com a seção de bônus (resumo de
/// motivos + estatísticas + página por colaborador) seguida da seção
/// comercial (resumo de requisitos + página por colaborador), quando
/// houver colaboradores de cada tipo. Quando só há um dos dois tipos,
/// a seção do outro simplesmente não aparece no PDF.
Future<void> _gerarRelatorioGeralMisto({
  required int mes,
  required int ano,
  required List<DadosRelatorioColaborador> dadosPorColaborador,
  required List<dynamic> resumoMotivosGeral,
  required List<DadosRelatorioComercial> dadosPorColaboradorComercial,
  required String subtitulo,
  String? nomeArquivo,
}) async {
  // Gera cada seção usando os geradores já existentes (que produzem
  // documentos PDF completos e independentes) e depois junta as
  // páginas de todos em um único arquivo final — evita duplicar aqui
  // a lógica interna de cada relatório.
  if (dadosPorColaborador.isNotEmpty && dadosPorColaboradorComercial.isEmpty) {
    // Só bônus: comportamento idêntico ao que já existia.
    await gerarRelatorioGeralPenalidadesPdf(
      mes: mes,
      ano: ano,
      dadosPorColaborador: dadosPorColaborador,
      resumoMotivosGeral: resumoMotivosGeral.cast(),
      subtitulo: subtitulo,
      nomeArquivo: nomeArquivo,
    );
    return;
  }

  if (dadosPorColaboradorComercial.isNotEmpty && dadosPorColaborador.isEmpty) {
    // Só comercial: monta um documento próprio com a seção comercial.
    final doc = pw.Document();
    final logoImage = await carregarLogoRelatorio();
    await gerarSecaoComercialRelatorioGeral(
      doc: doc,
      mes: mes,
      ano: ano,
      dadosPorColaborador: dadosPorColaboradorComercial,
      logoImage: logoImage,
      subtitulo: subtitulo,
    );
    final nomeFinal = nomeArquivo != null
        ? '$nomeArquivo.pdf'
        : 'relatorio_geral_${ano}_${mes.toString().padLeft(2, '0')}.pdf';
    await salvarEAbrirPdfCompartilhado(doc, nomeFinal);
    return;
  }

  // Mistura os dois: gera as páginas de bônus e as páginas comerciais
  // no mesmo pw.Document.
  final doc = pw.Document();
  final logoImage = await carregarLogoRelatorio();

  await adicionarPaginasBonusAoDocumento(
    doc: doc,
    mes: mes,
    ano: ano,
    dadosPorColaborador: dadosPorColaborador,
    resumoMotivosGeral: resumoMotivosGeral.cast(),
    logoImage: logoImage,
    subtitulo: subtitulo,
  );

  await gerarSecaoComercialRelatorioGeral(
    doc: doc,
    mes: mes,
    ano: ano,
    dadosPorColaborador: dadosPorColaboradorComercial,
    logoImage: logoImage,
    subtitulo: subtitulo,
  );

  final nomeFinal = nomeArquivo != null
      ? '$nomeArquivo.pdf'
      : 'relatorio_geral_${ano}_${mes.toString().padLeft(2, '0')}.pdf';
  await salvarEAbrirPdfCompartilhado(doc, nomeFinal);
}