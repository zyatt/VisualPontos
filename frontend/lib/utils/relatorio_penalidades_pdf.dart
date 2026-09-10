import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/colaborador.dart';
import '../models/lancamento_bonus.dart';
import '../models/bonus.dart';
import '../models/faixa_bonus.dart';
import '../services/lancamento_bonus_service.dart' show ResumoMotivo;

const List<String> _mesesRelatorio = [
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

const PdfColor _laranja = PdfColor.fromInt(0xFFF2711C);
const PdfColor _cinzaTexto = PdfColor.fromInt(0xFF4A4A4A);
const PdfColor _cinzaClaro = PdfColor.fromInt(0xFFF0F0F0);
const PdfColor _cinzaBorda = PdfColor.fromInt(0xFFE5E7EB);
const PdfColor _bgCabecalho = PdfColor.fromInt(0xFFF3F4F6);

/// Gera (e abre a folha de compartilhar/imprimir) um PDF com o relatório
/// de penalidades de um colaborador em um mês/ano específico. O resumo de
/// quantas penalidades foram lançadas por motivo (apenas deste
/// colaborador, no período) aparece como um bloco logo abaixo da linha de
/// totais, na mesma página do detalhe.
Future<void> gerarRelatorioPenalidadesPdf({
  required Colaborador colaborador,
  required int mes,
  required int ano,
  required List<LancamentoBonus> lancamentos,
  int pontosIniciais = 100,
  Bonus? bonus,
  List<ResumoMotivo> resumoMotivos = const [],
}) async {
  final doc = pw.Document();
  final logoImage = await _carregarLogo();

  doc.addPage(
    _paginaColaborador(
      colaborador: colaborador,
      mes: mes,
      ano: ano,
      lancamentos: lancamentos,
      pontosIniciais: pontosIniciais,
      bonus: bonus,
      logoImage: logoImage,
      resumoMotivos: resumoMotivos,
    ),
  );

  doc.addPage(
    _paginaEstatisticas(
      mes: mes,
      ano: ano,
      resumoMotivos: resumoMotivos,
      lancamentos: lancamentos,
      logoImage: logoImage,
      subtitulo: colaborador.nome,
    ),
  );

  final nomeArquivo =
      'relatorio_${colaborador.nome.replaceAll(RegExp(r'[^\w]+'), '_')}_'
      '${ano}_${mes.toString().padLeft(2, '0')}.pdf';

  await _salvarEAbrir(doc, nomeArquivo);
}

/// Total de penalidades de um colaborador, usado no ranking exibido na
/// página de estatísticas do relatório geral.
class _RankingColaborador {
  final String nome;
  final int total;
  final int quantidade;

  const _RankingColaborador({
    required this.nome,
    required this.total,
    required this.quantidade,
  });
}

/// Agrupa os dados necessários para gerar a seção de um colaborador
/// dentro do relatório geral.
class DadosRelatorioColaborador {
  final Colaborador colaborador;
  final List<LancamentoBonus> lancamentos;
  final int pontosIniciais;
  final Bonus? bonus;

  DadosRelatorioColaborador({
    required this.colaborador,
    required this.lancamentos,
    required this.pontosIniciais,
    this.bonus,
  });
}

/// Gera um único PDF contendo o relatório de penalidades de vários
/// colaboradores no mesmo mês/ano, cada um em sua própria sequência de
/// página(s) (via [pw.MultiPage] independente), sem misturar dados entre
/// colaboradores. A primeira página do PDF é um resumo de motivos que
/// junta as penalidades de TODOS os colaboradores informados.
Future<void> gerarRelatorioGeralPenalidadesPdf({
  required int mes,
  required int ano,
  required List<DadosRelatorioColaborador> dadosPorColaborador,
  List<ResumoMotivo> resumoMotivosGeral = const [],
}) async {
  final doc = pw.Document();
  final logoImage = await _carregarLogo();

  doc.addPage(
    _paginaResumoMotivos(
      mes: mes,
      ano: ano,
      resumoMotivos: resumoMotivosGeral,
      logoImage: logoImage,
      subtitulo: 'Todos os colaboradores',
    ),
  );

  doc.addPage(
    _paginaEstatisticas(
      mes: mes,
      ano: ano,
      resumoMotivos: resumoMotivosGeral,
      // Concatena os lançamentos de TODOS os colaboradores para o
      // gráfico de penalidades por dia do mês (agregado geral).
      lancamentos: [
        for (final dados in dadosPorColaborador) ...dados.lancamentos,
      ],
      logoImage: logoImage,
      subtitulo: 'Todos os colaboradores',
      // Ranking de colaboradores com mais penalidades no período,
      // ordenado pelo total de pontos descontados (em módulo) — mas
      // exibindo também a quantidade de lançamentos de cada um, já que
      // um colaborador pode ter poucos lançamentos com pontuação alta ou
      // vice-versa. Só faz sentido no relatório geral (múltiplos
      // colaboradores).
      rankingColaboradores: [
        for (final dados in dadosPorColaborador)
          _RankingColaborador(
            nome: dados.colaborador.nome,
            total: dados.lancamentos.fold<int>(
              0,
              (soma, l) => soma + l.pontos.abs(),
            ),
            quantidade: dados.lancamentos.length,
          ),
      ]..sort((a, b) => b.total.compareTo(a.total)),
    ),
  );

  for (final dados in dadosPorColaborador) {
    doc.addPage(
      _paginaColaborador(
        colaborador: dados.colaborador,
        mes: mes,
        ano: ano,
        lancamentos: dados.lancamentos,
        pontosIniciais: dados.pontosIniciais,
        bonus: dados.bonus,
        logoImage: logoImage,
      ),
    );
  }

  final nomeArquivo =
      'relatorio_geral_${ano}_${mes.toString().padLeft(2, '0')}.pdf';

  await _salvarEAbrir(doc, nomeArquivo);
}

/// Gera um PDF contendo APENAS a página de resumo por motivo (a mesma
/// primeira página do relatório geral), sem as páginas de detalhe por
/// colaborador. Usado na tela de Motivos, onde não faz sentido montar o
/// relatório completo — só o resumo de quantas penalidades foram
/// lançadas por motivo no período, somando todos os colaboradores.
Future<void> gerarRelatorioMotivosPdf({
  required int mes,
  required int ano,
  List<ResumoMotivo> resumoMotivos = const [],
}) async {
  final doc = pw.Document();
  final logoImage = await _carregarLogo();

  doc.addPage(
    _paginaResumoMotivos(
      mes: mes,
      ano: ano,
      resumoMotivos: resumoMotivos,
      logoImage: logoImage,
      subtitulo: 'Todos os colaboradores',
    ),
  );

  final nomeArquivo =
      'relatorio_motivos_${ano}_${mes.toString().padLeft(2, '0')}.pdf';

  await _salvarEAbrir(doc, nomeArquivo);
}

Future<pw.MemoryImage> _carregarLogo() async {
  // Logo da empresa (assets/images/logoPreta.png)
  final logoBytes = await rootBundle.load('assets/images/logoPreta.png');
  return pw.MemoryImage(logoBytes.buffer.asUint8List());
}

Future<void> _salvarEAbrir(pw.Document doc, String nomeArquivo) async {
  final bytes = await doc.save();

  // Salva o arquivo e abre com o visualizador de PDF padrão do sistema
  // (tanto em mobile quanto em desktop), em vez de abrir a folha de
  // compartilhar/enviar.
  final dir = await getApplicationDocumentsDirectory();
  final arquivo = File('${dir.path}${Platform.pathSeparator}$nomeArquivo');
  await arquivo.writeAsBytes(bytes);
  await OpenFilex.open(arquivo.path);
}

/// Cabeçalho institucional (logo + dados da empresa) compartilhado entre a
/// página de resumo de motivos e a página de detalhe do colaborador.
pw.Widget _cabecalhoInstitucional({
  required pw.MemoryImage logoImage,
  required String rotulo,
  required int mes,
  required int ano,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _laranja, width: 4)),
    ),
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(logoImage, height: 42),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'VISUAL PREMIUM',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'CNPJ: 20.000.300/0001-88   IE: 9066233666',
                  style: const pw.TextStyle(fontSize: 7, color: _cinzaTexto),
                ),
                pw.Text(
                  'RUA GENERAL RONDON, 745 - NOVA RUSSIA - PONTA GROSSA - PR',
                  style: const pw.TextStyle(fontSize: 7, color: _cinzaTexto),
                ),
                pw.Text(
                  'Telefone: +55 (42) 3086-8600',
                  style: const pw.TextStyle(fontSize: 7, color: _cinzaTexto),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                rotulo,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _cinzaTexto,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${_mesesRelatorio[mes - 1]} de $ano',
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _laranja,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Monta a primeira página do relatório: um resumo de quantas
/// penalidades foram lançadas por motivo no período. No relatório
/// individual, [resumoMotivos] já vem restrito ao colaborador; no
/// relatório geral, já vem agregado de todos os colaboradores.
pw.MultiPage _paginaResumoMotivos({
  required int mes,
  required int ano,
  required List<ResumoMotivo> resumoMotivos,
  required pw.MemoryImage logoImage,
  required String subtitulo,
}) {
  final ordenado = [...resumoMotivos]
    ..sort((a, b) => b.total.compareTo(a.total));
  final totalGeral = ordenado.fold<int>(0, (soma, r) => soma + r.total);
  final geradoEm = DateFormat('dd/MM/yyyy \'às\' HH:mm').format(DateTime.now());

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
    footer: (context) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    ),
    build: (context) => [
        _cabecalhoInstitucional(
          logoImage: logoImage,
          rotulo: 'RESUMO POR MOTIVO',
          mes: mes,
          ano: ano,
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          decoration: const pw.BoxDecoration(color: _bgCabecalho),
          child: pw.Row(
            children: [
              pw.Container(width: 4, height: 40, color: _laranja),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ESCOPO',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: _cinzaTexto)),
                          pw.SizedBox(height: 2),
                          pw.Text(subtitulo,
                              style: const pw.TextStyle(
                                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('TOTAL DE PENALIDADES',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: _cinzaTexto)),
                          pw.SizedBox(height: 2),
                          pw.Text('$totalGeral',
                              style: const pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _laranja)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        if (ordenado.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Nenhuma penalidade com motivo lançada neste mês.',
              style: const pw.TextStyle(fontSize: 11, color: _cinzaTexto),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _laranja),
                children: [
                  _celulaCabecalho('Motivo', textAlign: pw.TextAlign.left),
                  _celulaCabecalho('Penalidades',
                      textAlign: pw.TextAlign.center),
                ],
              ),
              for (int i = 0; i < ordenado.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : _cinzaClaro,
                  ),
                  children: [
                    _celula(ordenado[i].motivoNome,
                        negrito: true, textAlign: pw.TextAlign.left),
                    _celula('${ordenado[i].total}',
                        textAlign: pw.TextAlign.center),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Relatório gerado em $geradoEm',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
  );
}

/// Paleta cíclica usada para colorir as fatias da pizza e as barras dos
/// motivos — cores distintas o bastante para leitura em impressão P&B
/// (variam também em luminosidade, não só em matiz).
const List<PdfColor> _paletaGrafico = [
  _laranja,
  PdfColor.fromInt(0xFF2D9CDB),
  PdfColor.fromInt(0xFF27AE60),
  PdfColor.fromInt(0xFFBB6BD9),
  PdfColor.fromInt(0xFFE05252),
  PdfColor.fromInt(0xFFF2C94C),
  PdfColor.fromInt(0xFF56CCF2),
  PdfColor.fromInt(0xFF828282),
  PdfColor.fromInt(0xFF9B51E0),
  PdfColor.fromInt(0xFF219653),
];

/// Monta a segunda página do relatório: estatísticas visuais do período —
/// um gráfico de pizza com a distribuição percentual de penalidades por
/// motivo, e um gráfico de barras com a quantidade de penalidades lançadas
/// em cada dia do mês selecionado. Usada tanto no relatório individual
/// (penalidades de 1 colaborador) quanto no geral (todos agregados).
pw.MultiPage _paginaEstatisticas({
  required int mes,
  required int ano,
  required List<ResumoMotivo> resumoMotivos,
  required List<LancamentoBonus> lancamentos,
  required pw.MemoryImage logoImage,
  required String subtitulo,
  List<_RankingColaborador> rankingColaboradores = const [],
}) {
  final geradoEm = DateFormat('dd/MM/yyyy \'às\' HH:mm').format(DateTime.now());

  final ordenado = [...resumoMotivos]
    ..sort((a, b) => b.total.compareTo(a.total));
  final totalGeral = ordenado.fold<int>(0, (soma, r) => soma + r.total);

  // Quantidade de dias do mês selecionado (considera anos bissextos via
  // DateTime, que já resolve isso corretamente ao pedir o "dia 0" do mês
  // seguinte).
  final diasNoMes = DateTime(ano, mes + 1, 0).day;

  // Agrupa as penalidades (apenas as com pontos negativos, isto é, todas
  // — pontos de penalidade são sempre negativos) por dia do mês.
  final porDia = List<int>.filled(diasNoMes, 0);
  for (final l in lancamentos) {
    if (l.criadoEm.month == mes && l.criadoEm.year == ano) {
      final dia = l.criadoEm.day;
      if (dia >= 1 && dia <= diasNoMes) {
        porDia[dia - 1]++;
      }
    }
  }
  final maxPorDia =
      porDia.isEmpty ? 0 : porDia.reduce((a, b) => a > b ? a : b);

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
    footer: (context) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    ),
    build: (context) => [
      _cabecalhoInstitucional(
        logoImage: logoImage,
        rotulo: 'ESTATÍSTICAS',
        mes: mes,
        ano: ano,
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        decoration: const pw.BoxDecoration(color: _bgCabecalho),
        child: pw.Row(
          children: [
            pw.Container(width: 4, height: 40, color: _laranja),
            pw.Expanded(
              child: pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: pw.Text(subtitulo,
                    style: const pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),

      // ── Gráfico de pizza: % de penalidades por motivo ─────────────────
      pw.Text(
        'Distribuição de penalidades por motivo',
        style: const pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: _cinzaTexto,
        ),
      ),
      pw.SizedBox(height: 6),
      if (ordenado.isEmpty || totalGeral == 0)
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Nenhuma penalidade com motivo lançada neste mês.',
            style: const pw.TextStyle(fontSize: 9.5, color: _cinzaTexto),
          ),
        )
      else
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 100,
              height: 100,
              child: pw.CustomPaint(
                size: const PdfPoint(100, 100),
                painter: (canvas, size) => _desenharPizza(
                  canvas,
                  size,
                  ordenado,
                  totalGeral,
                  font: pw.Font.helveticaBold().getFont(context),
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            // Legenda ao lado da pizza (em vez de abaixo), economizando
            // altura vertical na página.
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < ordenado.length; i++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color:
                                  _paletaGrafico[i % _paletaGrafico.length],
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(2)),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(
                              ordenado[i].motivoNome,
                              style: const pw.TextStyle(
                                  fontSize: 8.5, color: _cinzaTexto),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            '${(ordenado[i].total / totalGeral * 100).toStringAsFixed(1)}% '
                            '(${ordenado[i].total})',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _cinzaTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

      pw.SizedBox(height: 16),

      // ── Ranking: colaboradores com mais penalidades ────────────────────
      // Só é exibido quando a lista é informada (relatório geral, que
      // agrega vários colaboradores — no relatório individual não faz
      // sentido, já que há apenas um).
      if (rankingColaboradores.isNotEmpty) ...[
        pw.Text(
          'Colaboradores com mais penalidades',
          style: const pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _cinzaTexto,
          ),
        ),
        pw.SizedBox(height: 6),
        _blocoRankingColaboradores(rankingColaboradores),
        pw.SizedBox(height: 16),
      ],

      // ── Gráfico de barras: penalidades por dia do mês ─────────────────
      pw.Text(
        'Penalidades por dia do mês',
        style: const pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: _cinzaTexto,
        ),
      ),
      pw.SizedBox(height: 6),
      if (maxPorDia == 0)
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Nenhuma penalidade lançada neste mês.',
            style: const pw.TextStyle(fontSize: 9.5, color: _cinzaTexto),
          ),
        )
      else ...[
        // Rótulo do eixo Y, alinhado à esquerda acima do gráfico (o
        // pacote `pdf` não tem um parâmetro nativo de "título do eixo",
        // então é desenhado como texto normal ao redor do gráfico).
        pw.Text(
          'Quantidade de penalidades',
          style: const pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: _cinzaTexto,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(
          height: 130,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis(
                List<int>.generate(diasNoMes, (i) => i + 1),
                // Sem linhas de grade internas — só o traço do eixo com
                // as marcações (ticks) de cada dia.
                divisions: false,
                ticks: true,
                marginStart: 8,
                marginEnd: 8,
                textStyle: const pw.TextStyle(fontSize: 6, color: _cinzaTexto),
              ),
              yAxis: pw.FixedAxis(
                _gerarEscalaEixoY(maxPorDia),
                divisions: false,
                ticks: true,
                format: (v) => v.toInt().toString(),
                textStyle: const pw.TextStyle(fontSize: 6.5, color: _cinzaTexto),
              ),
            ),
            datasets: [
              pw.BarDataSet(
                color: _laranja,
                width: 5,
                data: [
                  for (int dia = 1; dia <= diasNoMes; dia++)
                    pw.PointChartValue(
                        dia.toDouble(), porDia[dia - 1].toDouble()),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        // Rótulo do eixo X, centralizado abaixo do gráfico.
        pw.Center(
          child: pw.Text(
            'Dia do mês',
            style: const pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _cinzaTexto,
            ),
          ),
        ),
      ],

      pw.SizedBox(height: 16),
      pw.Text(
        'Relatório gerado em $geradoEm',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    ],
  );
}

/// Bloco com o ranking de colaboradores que mais receberam penalidades
/// no período (já ordenado por total de pontos decrescente), exibido
/// como barras horizontais compactas — uma por colaborador, com o nome,
/// a barra proporcional ao maior total de pontos do ranking, e a
/// quantidade de penalidades junto com o total de pontos descontados
/// (ex.: "4 penalidades · 43 pts"). Limitado aos 10 primeiros para não
/// estourar a página quando há muitos colaboradores.
pw.Widget _blocoRankingColaboradores(List<_RankingColaborador> ranking) {
  final top = ranking.take(10).toList();
  final maiorTotal = top.first.total == 0 ? 1 : top.first.total;

  // Largura total (em pontos) disponível para a barra em si — a coluna
  // de barra tem largura fixa (ver `pw.SizedBox(width: _larguraBarraMax)`
  // abaixo), então o comprimento de cada barra é calculado aqui como
  // fração dessa largura, em vez de usar um widget tipo
  // `FractionallySizedBox` (que não existe no pacote `pdf`, só no
  // Flutter/Material).
  const larguraBarraMax = 160.0;

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: _bgCabecalho,
      border: pw.Border.all(color: _cinzaBorda, width: 0.7),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < top.length; i++)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 14,
                  child: pw.Text(
                    '${i + 1}º',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _cinzaTexto,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 100,
                  child: pw.Text(
                    top[i].nome,
                    style: const pw.TextStyle(fontSize: 8.5, color: _cinzaTexto),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
                pw.SizedBox(width: 6),
                // Barra de fundo (trilho cinza) com a barra colorida
                // desenhada por cima, à esquerda, com largura
                // proporcional ao total deste colaborador em relação ao
                // maior total do ranking.
                pw.Stack(
                  children: [
                    pw.Container(
                      width: larguraBarraMax,
                      height: 8,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.Container(
                      width: larguraBarraMax * (top[i].total / maiorTotal),
                      height: 8,
                      decoration: const pw.BoxDecoration(
                        color: _laranja,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(width: 8),
                // Quantidade de lançamentos + total de pontos, lado a
                // lado — antes só o total de pontos aparecia, o que
                // escondia se o resultado veio de muitas penalidades
                // pequenas ou de poucas penalidades pesadas.
                pw.Expanded(
                  child: pw.Text(
                    '${top[i].quantidade} '
                    '${top[i].quantidade == 1 ? 'penalidade' : 'penalidades'}'
                    ' · ${top[i].total} pts',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _cinzaTexto,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Gera uma escala "redonda" para o eixo Y do gráfico de barras (ex.:
/// máximo 7 → [0, 2, 4, 6, 8]), evitando rótulos fracionários.
List<int> _gerarEscalaEixoY(int maxValor) {
  if (maxValor <= 0) return [0, 1];
  final passo = (maxValor / 4).ceil().clamp(1, 1000000);
  final topo = passo * 5;
  return [for (int v = 0; v <= topo; v += passo) v];
}

/// Desenha manualmente um gráfico de pizza no canvas do PDF (o pacote
/// `pdf` não tem um widget de pizza pronto — ver
/// https://github.com/DavBfr/dart_pdf/issues/596). Cada fatia é um setor
/// circular desenhado com `moveTo` + `bezierArc` + `lineTo` + `fillPath`,
/// com ângulo proporcional ao percentual do motivo no total.
///
/// Quando [font] é informada, também escreve o percentual (e a
/// quantidade) de cada fatia centralizado dentro dela — só quando a
/// fatia é grande o bastante para o texto caber sem transbordar
/// (ver [_labelMinFatia]).
void _desenharPizza(
  PdfGraphics canvas,
  PdfPoint size,
  List<ResumoMotivo> ordenado,
  int totalGeral, {
  PdfFont? font,
}) {
  final cx = size.x / 2;
  final cy = size.y / 2;
  final raio = math.min(size.x, size.y) / 2;

  // Fração mínima de fatia (em relação ao total) para ainda desenharmos
  // o rótulo dentro dela — fatias muito finas não têm espaço para o
  // texto sem que ele vaze para fora do círculo.
  const labelMinFatia = 0.06;
  const labelFontSize = 8.0;

  void desenharRotulo(double anguloMeio, double fatia, int total) {
    if (font == null || fatia < labelMinFatia) return;

    final texto = '${(fatia * 100).toStringAsFixed(0)}%';

    // Posiciona o texto a ~60% do raio, no ângulo médio da fatia — fica
    // centralizado dentro da fatia tanto radial quanto angularmente.
    final rTexto = raio * 0.6;
    final tx = cx + rTexto * math.cos(anguloMeio);
    final ty = cy + rTexto * math.sin(anguloMeio);

    // Largura/altura aproximadas do texto para centralizá-lo no ponto
    // (tx, ty). `drawString` posiciona pela baseline no canto inferior
    // esquerdo, então precisamos deslocar manualmente. Usamos uma
    // estimativa por caractere (fonte bold, ~0.6 * fontSize de largura
    // média) em vez de depender de APIs de métrica de fonte, já que o
    // texto aqui é sempre curto e previsível ("NN%").
    final largura = texto.length * labelFontSize * 0.62;
    const altura = labelFontSize * 0.7;

    canvas
      ..setFillColor(PdfColors.white)
      ..drawString(
        font,
        labelFontSize,
        texto,
        tx - largura / 2,
        ty - altura / 2,
      );
  }

  // Caso especial: um único motivo concentra 100% das penalidades. O
  // arco degenera (ponto inicial == ponto final), então desenha um
  // círculo cheio diretamente em vez de tentar um `bezierArc` de volta
  // completa.
  if (ordenado.length == 1) {
    canvas
      ..setFillColor(_paletaGrafico[0])
      ..drawEllipse(cx, cy, raio, raio)
      ..fillPath();
    desenharRotulo(math.pi / 2, 1, ordenado[0].total);
    return;
  }

  // Ângulo inicial no topo do círculo (12h), sentido horário.
  double anguloAtual = math.pi / 2;

  for (int i = 0; i < ordenado.length; i++) {
    final fatia = ordenado[i].total / totalGeral;
    final anguloFatia = fatia * 2 * math.pi;
    final anguloFim = anguloAtual - anguloFatia;

    final x1 = cx + raio * math.cos(anguloAtual);
    final y1 = cy + raio * math.sin(anguloAtual);
    final x2 = cx + raio * math.cos(anguloFim);
    final y2 = cy + raio * math.sin(anguloFim);

    // Fatias muito próximas de 100% (uma única categoria) usam duas
    // meias-voltas para evitar ambiguidade no `bezierArc` (que precisa
    // saber se o arco é "grande" ou "pequeno").
    final grande = anguloFatia > math.pi;

    canvas
      ..setFillColor(_paletaGrafico[i % _paletaGrafico.length])
      ..moveTo(cx, cy)
      ..lineTo(x1, y1)
      ..bezierArc(x1, y1, raio, raio, x2, y2, large: grande, sweep: false)
      ..lineTo(cx, cy)
      ..fillPath();

    desenharRotulo(anguloAtual - anguloFatia / 2, fatia, ordenado[i].total);

    anguloAtual = anguloFim;
  }
}

/// Bloco compacto com a contagem de penalidades por motivo, inserido
/// logo abaixo da linha de totais na página de detalhe do colaborador.
pw.Widget _blocoResumoMotivos(List<ResumoMotivo> resumoMotivos) {
  final ordenado = [...resumoMotivos]
    ..sort((a, b) => b.total.compareTo(a.total));

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _bgCabecalho,
      border: pw.Border.all(color: _cinzaBorda, width: 0.7),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PENALIDADES POR MOTIVO',
          style: const pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _laranja,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final r in ordenado)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: _cinzaTexto,
                    ),
                    children: [
                      const pw.TextSpan(text: 'Motivo: '),
                      pw.TextSpan(
                        text: r.motivoNome,
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _cinzaTexto,
                        ),
                      ),
                      const pw.TextSpan(text: ' - Total: '),
                      pw.TextSpan(
                        text: '${r.total}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _cinzaTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Monta a página (ou sequência de páginas, via [pw.MultiPage]) referente
/// a UM colaborador. Usada tanto pelo relatório individual quanto por cada
/// seção do relatório geral, garantindo layout idêntico e que as páginas
/// de um colaborador nunca contenham dados de outro — cada chamada monta
/// um [pw.MultiPage] independente, fechado sobre os dados passados.
pw.Page _paginaColaborador({
  required Colaborador colaborador,
  required int mes,
  required int ano,
  required List<LancamentoBonus> lancamentos,
  required int pontosIniciais,
  required Bonus? bonus,
  required pw.MemoryImage logoImage,
  List<ResumoMotivo> resumoMotivos = const [],
}) {
  final ordenados = [...lancamentos]
    ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));

  final totalPenalidades =
      ordenados.fold<int>(0, (soma, l) => soma + l.pontos.abs());
  final saldo = pontosIniciais - totalPenalidades;

  // ── Cálculo da faixa de bônus atingida (mesmo critério do app) ─────────
  // A faixa que vale é a de maior número de pontos cujo pontos seja
  // <= saldo atual do colaborador.
  FaixaBonus? faixaAtingida;
  if (bonus != null) {
    final saldoComparacao = saldo < 0 ? 0 : saldo;
    final faixasOrdenadas = [...bonus.faixas]
      ..sort((a, b) => b.pontos.compareTo(a.pontos));
    for (final faixa in faixasOrdenadas) {
      if (faixa.pontos <= saldoComparacao) {
        faixaAtingida = faixa;
        break;
      }
    }
  }
  final valorBonus = faixaAtingida?.valor;

  final dataFormatada = DateFormat('dd/MM/yyyy HH:mm');
  final geradoEm = DateFormat('dd/MM/yyyy \'às\' HH:mm').format(DateTime.now());

  return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
      header: (context) {
        if (context.pageNumber > 1) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Text(
              'Relatório · ${colaborador.nome}',
              style: const pw.TextStyle(fontSize: 9, color: _cinzaTexto),
            ),
          );
        }
        return pw.SizedBox();
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ),
      build: (context) => [
        // ── Cabeçalho institucional (logo + dados da empresa + doc) ─────
        _cabecalhoInstitucional(
          logoImage: logoImage,
          rotulo: 'RELATÓRIO',
          mes: mes,
          ano: ano,
        ),
        pw.SizedBox(height: 14),

        // ── Dados do colaborador ────────────────────────────────────────
        pw.Container(
          decoration: const pw.BoxDecoration(color: _bgCabecalho),
          child: pw.Row(
            children: [
              pw.Container(width: 4, height: 46, color: _laranja),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('COLABORADOR',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: _cinzaTexto)),
                          pw.SizedBox(height: 2),
                          pw.Text(colaborador.nome,
                              style: const pw.TextStyle(
                                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SETOR',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: _cinzaTexto)),
                          pw.SizedBox(height: 2),
                          pw.Text(colaborador.setor,
                              style: const pw.TextStyle(
                                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('PONTOS NO MÊS',
                                  style: const pw.TextStyle(
                                      fontSize: 7, color: _cinzaTexto)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '$saldo pontos',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: saldo < pontosIniciais
                                      ? const PdfColor.fromInt(0xFFE05252)
                                      : _cinzaTexto,
                                ),
                              ),
                            ],
                          ),
                          if (valorBonus != null) ...[
                            pw.SizedBox(width: 10),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text('BÔNUS',
                                    style: const pw.TextStyle(
                                        fontSize: 7, color: _cinzaTexto)),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _formatarMoeda(valorBonus),
                                  style: const pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _laranja,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Container(height: 0.8, color: _cinzaBorda),
        pw.SizedBox(height: 4),
        pw.Text(
          'Pontuação inicial: $pontosIniciais · '
          'Total de penalidades: $totalPenalidades pontos em '
          '${ordenados.length} '
          '${ordenados.length == 1 ? 'lançamento' : 'lançamentos'}'
          '${faixaAtingida != null ? ' · Faixa atingida: ${faixaAtingida.pontos} pts' : ''}',
          style: const pw.TextStyle(fontSize: 9, color: _cinzaTexto),
        ),

        if (resumoMotivos.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _blocoResumoMotivos(resumoMotivos),
        ],

        if (bonus != null && bonus.observacoes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          for (final obs in bonus.observacoes)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _bgCabecalho,
                border: pw.Border.all(color: _cinzaBorda, width: 0.7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    obs.nome,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _laranja,
                    ),
                  ),
                  if (obs.itens.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    for (final item in obs.itens)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          '- ${item.descricao}',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: _cinzaTexto,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],

        pw.SizedBox(height: 18),

        if (ordenados.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Nenhuma penalidade lançada neste mês.',
              style: const pw.TextStyle(fontSize: 11, color: _cinzaTexto),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.1),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2.2),
              5: const pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _laranja),
                children: [
                  _celulaCabecalho('Categoria / Subcategoria',
                      textAlign: pw.TextAlign.center),
                  _celulaCabecalho('Data', textAlign: pw.TextAlign.center),
                  _celulaCabecalho('Pontos', textAlign: pw.TextAlign.center),
                  _celulaCabecalho('Motivo', textAlign: pw.TextAlign.center),
                  _celulaCabecalho('Observação / OS',
                      textAlign: pw.TextAlign.center),
                  _celulaCabecalho('Lançado por',
                      textAlign: pw.TextAlign.center),
                ],
              ),
              for (int i = 0; i < ordenados.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : _cinzaClaro,
                  ),
                  children: [
                    _celula(
                      ordenados[i].subcategoriaId == null
                          ? 'Penalidade avulsa'
                          : '${ordenados[i].categoriaNome}\n${ordenados[i].subcategoriaDesc}',
                      negrito: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _celula(
                      dataFormatada.format(ordenados[i].criadoEm),
                      textAlign: pw.TextAlign.center,
                    ),
                    _celula(
                      '${ordenados[i].pontos}',
                      cor: const PdfColor.fromInt(0xFFE05252),
                      negrito: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _celula(
                      ordenados[i].motivoNome ?? '-',
                      textAlign: pw.TextAlign.center,
                    ),
                    _celula(
                      'OS: ${ordenados[i].os}\n${ordenados[i].observacao}',
                      textAlign: pw.TextAlign.center,
                    ),
                    _celula(
                      ordenados[i].usuarioNome,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Relatório gerado em $geradoEm',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
}

/// Formata um valor double como moeda BRL (ex.: 1234.5 -> "R$ 1.234,50").
String _formatarMoeda(double valor) {
  final negativo = valor < 0;
  final abs = valor.abs();
  final partes = abs.toStringAsFixed(2).split('.');
  final inteiro = partes[0];
  final centavos = partes[1];

  final buffer = StringBuffer();
  for (int i = 0; i < inteiro.length; i++) {
    final posicaoDaDireita = inteiro.length - i;
    buffer.write(inteiro[i]);
    if (posicaoDaDireita > 1 && posicaoDaDireita % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${negativo ? '-' : ''}R\$ ${buffer.toString()},$centavos';
}

pw.Widget _celulaCabecalho(String texto, {pw.TextAlign? textAlign}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      texto,
      textAlign: textAlign,
      style: const pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );
}

pw.Widget _celula(
  String texto, {
  PdfColor? cor,
  bool negrito = false,
  pw.TextAlign? textAlign,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      texto,
      textAlign: textAlign,
      style: pw.TextStyle(
        fontSize: 8.5,
        color: cor ?? const PdfColor.fromInt(0xFF1A1A1A),
        fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}