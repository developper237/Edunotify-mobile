import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'presence_archive.dart';

Future<Uint8List> genererPdfPresence(SessionArchive archive) async {
  final pdf = pw.Document();
  final a = archive;

  final dateStr =
      '${a.debutLe.day.toString().padLeft(2, '0')}/'
      '${a.debutLe.month.toString().padLeft(2, '0')}/'
      '${a.debutLe.year}  '
      '${a.debutLe.hour.toString().padLeft(2, '0')}:'
      '${a.debutLe.minute.toString().padLeft(2, '0')}';

  const orange = PdfColor.fromInt(0xFFF97316);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SmartCampus',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: orange)),
              pw.Text('Rapport de présence',
                  style: pw.TextStyle(
                      fontSize: 13, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 2,
            color: orange,
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (_) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Text(
            'Document généré par SmartCampus - '
                '${DateTime.now().day}/'
                '${DateTime.now().month}/'
                '${DateTime.now().year}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
      build: (context) => [
        // Infos session
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfInfoRow('Matière',    a.matiere),
              _pdfInfoRow('Professeur', a.professeur),
              _pdfInfoRow('Salle',      a.salle),
              _pdfInfoRow('Type',       a.type),
              _pdfInfoRow('Date',       dateStr),
              _pdfInfoRow('Durée',      a.dureeLabel),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Stats
        pw.Row(children: [
          _pdfStat('Total',    '${a.total}',      PdfColors.grey700),
          _pdfStat('Présents', '${a.nbPresents}', PdfColors.green700),
          _pdfStat('Absents',  '${a.nbAbsents}',  PdfColors.red700),
          _pdfStat('Taux',
              '${a.tauxPresence.toStringAsFixed(0)}%',
              a.tauxPresence >= 75
                  ? PdfColors.green700
                  : a.tauxPresence >= 50
                  ? PdfColors.orange700
                  : PdfColors.red700),
        ]),
        pw.SizedBox(height: 20),

        // Tableau présents
        if (a.presents.isNotEmpty) ...[
          pw.Text('Étudiants présents (${a.nbPresents})',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green50),
                children: [
                  _pdfHeader('Matricule'),
                  _pdfHeader('Nom & Prénom'),
                  _pdfHeader('Heure'),
                  _pdfHeader('Méthode'),
                ],
              ),
              ...a.presents.map((e) => pw.TableRow(
                children: [
                  _pdfCell(e.matricule),
                  _pdfCell('${e.prenom} ${e.nom.toUpperCase()}'),
                  _pdfCell(
                    e.confirmedAt != null
                        ? '${e.confirmedAt!.hour.toString().padLeft(2, '0')}:'
                        '${e.confirmedAt!.minute.toString().padLeft(2, '0')}'
                        : '--:--',
                  ),
                  _pdfCell(e.methode == 'manuel' ? 'Manuel' : 'Code OTP'),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Tableau absents
        if (a.absents.isNotEmpty) ...[
          pw.Text('Étudiants absents (${a.nbAbsents})',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.red50),
                children: [
                  _pdfHeader('Matricule'),
                  _pdfHeader('Nom & Prénom'),
                ],
              ),
              ...a.absents.map((e) => pw.TableRow(
                children: [
                  _pdfCell(e.matricule),
                  _pdfCell('${e.prenom} ${e.nom.toUpperCase()}'),
                ],
              )),
            ],
          ),
        ],

        pw.SizedBox(height: 16),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfInfoRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(children: [
    pw.SizedBox(
      width: 90,
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold)),
    ),
    pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
  ]),
);

pw.Widget _pdfStat(String label, String value, PdfColor color) =>
    pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
        ]),
      ),
    );

pw.Widget _pdfHeader(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text,
      style:
      pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
);

pw.Widget _pdfCell(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
);