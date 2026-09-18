import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/checklist_comercial.dart';
import '../models/colaborador.dart';
import '../services/checklist_comercial_service.dart' show ResumoRequisito;
import 'relatorio_penalidades_pdf.dart'
    show
        gerarNomeArquivoSeguro,
        salvarEAbrirPdfCompartilhado,
        carregarLogoRelatorio,
        cabecalhoInstitucionalRelatorio;

const PdfColor _laranja = PdfColor.fromInt(0xFFF2711C);
const PdfColor _verde = PdfColor.fromInt(0xFF2E7D32);
const PdfColor _vermelho = PdfColor.fromInt(0xFFE05252);
const PdfColor _cinzaTexto = PdfColor.fromInt(0xFF4A4A4A);
const PdfColor _cinzaClaro = PdfColor.fromInt(0xFFF0F0F0);
const PdfColor _bgCabecalho = PdfColor.fromInt(0xFFF3F4F6);

// carregarLogoRelatorio é importada de relatorio_penalidades_pdf.dart —
// reaproveita a mesma logo institucional usada em todos os relatórios.

/// Dados de um colaborador comercial para a seção dele dentro do
/// relatório geral (equivalente a DadosRelatorioColaborador, do lado
/// de bônus).
class DadosRelatorioComercial {
  final Colaborador colaborador;
  final List<ChecklistComercial> checklists;

  DadosRelatorioComercial({required this.colaborador, required this.checklists});
}

/// Gera o PDF de checklists de UM colaborador comercial em um mês/ano.
/// Sem pontos/valores — apenas a lista de checklists e, para cada um,
/// quais requisitos ficaram não conformes (com a observação
/// preenchida), além de um resumo de contagem por requisito no mês.
Future<void> gerarRelatorioChecklistComercialPdf({
  required Colaborador colaborador,
  required int mes,
  required int ano,
  required List<ChecklistComercial> checklists,
  List<ResumoRequisito> resumoRequisitos = const [],
}) async {
  final doc = pw.Document();
  final logoImage = await carregarLogoRelatorio();

  doc.addPage(
    _paginaColaboradorComercial(
      colaborador: colaborador,
      mes: mes,
      ano: ano,
      checklists: checklists,
      resumoRequisitos: resumoRequisitos,
      logoImage: logoImage,
    ),
  );

  final nomeArquivo =
      'checklist_${gerarNomeArquivoSeguro(colaborador.nome)}_${ano}_${mes.toString().padLeft(2, '0')}.pdf';

  await salvarEAbrirPdfCompartilhado(doc, nomeArquivo);
}

/// Gera um único PDF com a seção de checklist de vários colaboradores
/// comerciais no mesmo mês/ano — usado dentro do relatório GERAL,
/// misturado com as páginas de bônus (cada colaborador entra com sua
/// própria seção, sem misturar dados entre si).
Future<void> gerarSecaoComercialRelatorioGeral({
  required pw.Document doc,
  required int mes,
  required int ano,
  required List<DadosRelatorioComercial> dadosPorColaborador,
  required pw.MemoryImage logoImage,
  String subtitulo = 'Todos os colaboradores',
}) async {
  if (dadosPorColaborador.isEmpty) return;

  final resumoGeral = <int, ResumoRequisito>{};
  for (final dados in dadosPorColaborador) {
    for (final checklist in dados.checklists) {
      for (final item in checklist.itensNaoConformes) {
        final atual = resumoGeral[item.requisitoId];
        resumoGeral[item.requisitoId] = ResumoRequisito(
          requisitoId: item.requisitoId,
          requisitoNome: item.requisitoNome,
          total: (atual?.total ?? 0) + 1,
        );
      }
    }
  }
  final resumoOrdenado = resumoGeral.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  doc.addPage(
    _paginaResumoRequisitos(
      mes: mes,
      ano: ano,
      resumoRequisitos: resumoOrdenado,
      logoImage: logoImage,
      subtitulo: '$subtitulo · Setor Comercial',
    ),
  );

  for (final dados in dadosPorColaborador) {
    doc.addPage(
      _paginaColaboradorComercial(
        colaborador: dados.colaborador,
        mes: mes,
        ano: ano,
        checklists: dados.checklists,
        resumoRequisitos: const [],
        logoImage: logoImage,
      ),
    );
  }
}

/// Rodapé padrão de paginação ("Página X de Y"), igual ao usado nos
/// relatórios de bônus/penalidades — mantém o mesmo estilo visual em
/// todas as páginas do relatório (resumo e detalhe por colaborador).
pw.Widget _rodapePaginacao(pw.Context context) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );

/// Bloco de destaque (faixa cinza com borda lateral laranja) usado logo
/// abaixo do cabeçalho institucional, com pares rótulo/valor — mesmo
/// padrão visual do relatório de bônus (COLABORADOR/SETOR/PONTOS), mas
/// sem os campos de bônus, já que o setor Comercial não usa pontos.
pw.Widget _blocoDestaque(List<({String rotulo, String valor, PdfColor? cor})> campos) {
  return pw.Container(
    decoration: const pw.BoxDecoration(color: _bgCabecalho),
    child: pw.Row(
      children: [
        pw.Container(width: 4, height: 46, color: _laranja),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                for (final campo in campos)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(campo.rotulo,
                          style: const pw.TextStyle(fontSize: 7, color: _cinzaTexto)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        campo.valor,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: campo.cor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

pw.MultiPage _paginaResumoRequisitos({
  required int mes,
  required int ano,
  required List<ResumoRequisito> resumoRequisitos,
  required pw.MemoryImage logoImage,
  required String subtitulo,
}) {
  final geradoEm = _dataFormatada(DateTime.now());

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
    footer: (context) => _rodapePaginacao(context),
    build: (context) => [
      cabecalhoInstitucionalRelatorio(
        logoImage: logoImage,
        rotulo: 'RESUMO POR REQUISITO',
        mes: mes,
        ano: ano,
      ),
      pw.SizedBox(height: 14),
      _blocoDestaque([
        (rotulo: 'ESCOPO', valor: subtitulo, cor: null),
        (
          rotulo: 'TOTAL DE NÃO CONFORMIDADES',
          valor: '${resumoRequisitos.fold<int>(0, (soma, r) => soma + r.total)}',
          cor: _laranja,
        ),
      ]),
      pw.SizedBox(height: 18),
      if (resumoRequisitos.isEmpty)
        pw.Container(
          padding: const pw.EdgeInsets.all(24),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Nenhuma não-conformidade registrada neste período.',
            style: const pw.TextStyle(fontSize: 11, color: _cinzaTexto),
          ),
        )
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {0: pw.FlexColumnWidth(2.4), 1: pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _laranja),
              children: [
                _celulaCabecalho('Requisito'),
                _celulaCabecalho('Vezes não conforme', textAlign: pw.TextAlign.center),
              ],
            ),
            for (int i = 0; i < resumoRequisitos.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cinzaClaro),
                children: [
                  _celula(resumoRequisitos[i].requisitoNome),
                  _celula('${resumoRequisitos[i].total}',
                      textAlign: pw.TextAlign.center, negrito: true, cor: _vermelho),
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

pw.MultiPage _paginaColaboradorComercial({
  required Colaborador colaborador,
  required int mes,
  required int ano,
  required List<ChecklistComercial> checklists,
  required List<ResumoRequisito> resumoRequisitos,
  required pw.MemoryImage logoImage,
}) {
  final ordenados = List.of(checklists)..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

  final totalChecklists = ordenados.length;
  final totalNaoConformidades =
      ordenados.fold<int>(0, (soma, c) => soma + c.itensNaoConformes.length);

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
    footer: (context) => _rodapePaginacao(context),
    build: (context) => [
      // ── Cabeçalho institucional (logo + dados da empresa + doc) ──────
      cabecalhoInstitucionalRelatorio(
        logoImage: logoImage,
        rotulo: 'RELATÓRIO · SETOR COMERCIAL',
        mes: mes,
        ano: ano,
      ),
      pw.SizedBox(height: 14),
      // ── Dados do colaborador (sem bônus/pontos, setor Comercial) ─────
      _blocoDestaque([
        (rotulo: 'COLABORADOR', valor: colaborador.nome, cor: null),
        (rotulo: 'SETOR', valor: colaborador.setor, cor: null),
      ]),
      pw.SizedBox(height: 16),
      pw.Row(
        children: [
          _blocoResumo(rotulo: 'Checklists no mês', valor: '$totalChecklists'),
          pw.SizedBox(width: 12),
          _blocoResumo(
            rotulo: 'Não-conformidades',
            valor: '$totalNaoConformidades',
            cor: totalNaoConformidades > 0 ? _vermelho : _verde,
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      if (resumoRequisitos.isNotEmpty) ...[
        pw.Text(
          'Resumo por requisito (não conforme)',
          style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _cinzaTexto),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {0: pw.FlexColumnWidth(2.4), 1: pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _laranja),
              children: [
                _celulaCabecalho('Requisito'),
                _celulaCabecalho('Vezes não conforme', textAlign: pw.TextAlign.center),
              ],
            ),
            for (int i = 0; i < resumoRequisitos.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _cinzaClaro),
                children: [
                  _celula(resumoRequisitos[i].requisitoNome),
                  _celula('${resumoRequisitos[i].total}',
                      textAlign: pw.TextAlign.center, negrito: true, cor: _vermelho),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 18),
      ],
      pw.Text(
        'Checklists lançados',
        style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _cinzaTexto),
      ),
      pw.SizedBox(height: 6),
      if (ordenados.isEmpty)
        pw.Container(
          padding: const pw.EdgeInsets.all(24),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Nenhum checklist lançado neste mês.',
            style: const pw.TextStyle(fontSize: 11, color: _cinzaTexto),
          ),
        )
      else
        for (final checklist in ordenados) ...[
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'OS ${checklist.os}',
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: checklist.tudoConforme ? _verde : _vermelho,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        checklist.tudoConforme
                            ? 'Conforme'
                            : '${checklist.itensNaoConformes.length} pendência(s)',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${_dataFormatada(checklist.criadoEm)} · Lançado por ${checklist.usuarioNome}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                if (checklist.itensNaoConformes.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  for (final item in checklist.itensNaoConformes)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '- ${item.requisitoNome}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _vermelho,
                            ),
                          ),
                          if (item.observacao != null && item.observacao!.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 10, top: 1),
                              child: pw.Text(
                                item.observacao!,
                                style: const pw.TextStyle(fontSize: 8.5, color: _cinzaTexto),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      pw.SizedBox(height: 12),
      pw.Text(
        'Relatório gerado em ${_dataFormatada(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    ],
  );
}

pw.Widget _blocoResumo({required String rotulo, required String valor, PdfColor? cor}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _cinzaClaro,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(rotulo, style: const pw.TextStyle(fontSize: 8, color: _cinzaTexto)),
          pw.SizedBox(height: 2),
          pw.Text(
            valor,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: cor ?? _laranja),
          ),
        ],
      ),
    ),
  );
}

/// Formata data e hora como "dd/mm/aaaa hh:mm", usada nos cartões de
/// checklist e no rodapé do relatório.
String _dataFormatada(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

pw.Widget _celulaCabecalho(String texto, {pw.TextAlign? textAlign}) {  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: pw.Text(
      texto,
      textAlign: textAlign,
      softWrap: true,
      style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    ),
  );
}

pw.Widget _celula(String texto, {PdfColor? cor, bool negrito = false, pw.TextAlign? textAlign}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: pw.Text(
      texto,
      textAlign: textAlign,
      softWrap: true,
      style: pw.TextStyle(
        fontSize: 8.5,
        color: cor ?? const PdfColor.fromInt(0xFF1A1A1A),
        fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

// A implementação de salvar/abrir o PDF é a mesma usada por todo o
// app — ver salvarEAbrirPdfCompartilhado, importada acima.