import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'presence_archive.dart';

Future<Uint8List> genererPdfPresence(SessionArchive archive) async {
  final pdf = pw.Document();
  final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(archive.debutLe);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        // En-tête avec Logo ou Titre Stylisé
        pw.Header(
          level: 0,
          child: pw.Row(
            // CORRECTION : Utiliser mainAxisAlignment au lieu de main
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Rapport de Présence EduNotify",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(dateStr, style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Détails de la session dans un encadré
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            // CORRECTION : Utiliser crossAxisAlignment au lieu de cross
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Matière : ${archive.matiere}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Professeur : ${archive.professeur}"),
              pw.Text("Salle : ${archive.salle}"),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // Table des présents
        pw.Text("Étudiants Présents (${archive.presents.length})",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          context: context,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.center,
          },
          data: <List<String>>[
            <String>['Matricule', 'Nom', 'Prénom', 'Heure'],
            ...archive.presents.map((e) => [
              e.matricule,
              e.nom.toUpperCase(),
              e.prenom,
              e.confirmedAt != null ? DateFormat('HH:mm').format(e.confirmedAt!) : '-'
            ]),
          ],
        ),

        pw.SizedBox(height: 30),

        // Table des absents
        pw.Text("Étudiants Absents (${archive.absents.length})",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          context: context,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
          cellHeight: 25,
          data: <List<String>>[
            <String>['Matricule', 'Nom', 'Prénom'],
            ...archive.absents.map((e) => [e.matricule, e.nom.toUpperCase(), e.prenom]),
          ],
        ),
      ],
      // CORRECTION : Le footer se définit ici dans MultiPage, pas comme un enfant du build
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} sur ${context.pagesCount}',
          style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
        ),
      ),
    ),
  );

  return pdf.save();
}