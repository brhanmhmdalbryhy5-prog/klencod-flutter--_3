import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/anime.dart';
import 'storage_service.dart';

class ExportService {
  final StorageService _storage = StorageService();

  Future<String> exportAsCsv() async {
    try {
      final animes = await _storage.loadAnimes();
      final rows = <List<String>>[
        [
          'الاسم', 'الحالة', 'التصنيفات', 'الحلقات', 'تمت المشاهدة',
          'تقييمي', 'التقييم العالمي', 'السنة', 'الاستوديو', 'النوع'
        ],
        ...animes.map((a) => [
              a.title,
              a.status,
              a.genre,
              a.episodes.toString(),
              a.watchedEpisodes.toString(),
              a.rating.toStringAsFixed(1),
              a.globalRating?.toStringAsFixed(1) ?? '',
              a.releaseYear?.toString() ?? '',
              a.studios ?? '',
              a.format ?? '',
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/anime_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString('\uFEFF$csv');

      await Share.shareXFiles([XFile(file.path)], text: 'تصدير مكتبتي - CSV');
      return '✅ تم تصدير ${animes.length} أنمي بصيغة CSV.';
    } catch (e) {
      return '❌ فشل التصدير: $e';
    }
  }

  Future<String> exportAsPdf() async {
    try {
      final animes = await _storage.loadAnimes();

      final fontData = await PdfGoogleFonts.cairoRegular();
      final boldFontData = await PdfGoogleFonts.cairoBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontData,
          bold: boldFontData,
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('مكتبة الأنمي',
                        style: pw.TextStyle(
                            fontSize: 26, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('إجمالي الأنميات: ${animes.length}',
                        style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                        'تاريخ التصدير: ${DateTime.now().toString().split('.').first}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['الاسم', 'الحالة', 'التصنيفات', 'الحلقات', 'تقييمي', 'السنة'],
                data: animes
                    .map((a) => [
                          a.title,
                          a.status,
                          a.genre,
                          '${a.watchedEpisodes}/${a.episodes}',
                          a.rating > 0 ? a.rating.toStringAsFixed(1) : '-',
                          a.releaseYear?.toString() ?? '-',
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF741C2B)),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerRight,
                cellPadding: const pw.EdgeInsets.all(6),
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                // ✅ تم حذف evenRowDecoration (غير مدعوم في هذه النسخة)
              ),
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/anime_library_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'مكتبة الأنمي - PDF');
      return '✅ تم تصدير ${animes.length} أنمي بصيغة PDF.';
    } catch (e) {
      return '❌ فشل التصدير: $e';
    }
  }

  Future<String> exportAsMarkdown() async {
    try {
      final animes = await _storage.loadAnimes();
      final buffer = StringBuffer();
      buffer.writeln('# مكتبة الأنمي\n');
      buffer.writeln('> ${animes.length} أنمي\n');
      buffer.writeln('---\n');

      for (var anime in animes) {
        buffer.writeln('## ${anime.title}');
        if (anime.genre.isNotEmpty) {
          buffer.writeln('- **التصنيفات:** ${anime.genre}');
        }
        if (anime.status.isNotEmpty) {
          buffer.writeln('- **الحالة:** ${anime.status}');
        }
        if (anime.episodes > 0) {
          buffer.writeln(
              '- **الحلقات:** ${anime.watchedEpisodes}/${anime.episodes}');
        }
        if (anime.rating > 0) {
          buffer.writeln('- **تقييمي:** ${anime.rating.toStringAsFixed(1)}/10');
        }
        if (anime.globalRating != null) {
          buffer.writeln(
              '- **التقييم العالمي:** ${anime.globalRating!.toStringAsFixed(1)}/10');
        }
        if (anime.releaseYear != null) {
          buffer.writeln('- **السنة:** ${anime.releaseYear}');
        }
        if (anime.studios != null) {
          buffer.writeln('- **الاستوديو:** ${anime.studios}');
        }
        if (anime.summary.isNotEmpty) {
          buffer.writeln('\n> ${anime.summary}\n');
        }
        buffer.writeln('---\n');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/anime_library_${DateTime.now().millisecondsSinceEpoch}.md');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)],
          text: 'مكتبة الأنمي - Markdown');
      return '✅ تم تصدير ${animes.length} أنمي بصيغة Markdown.';
    } catch (e) {
      return '❌ فشل التصدير: $e';
    }
  }
}