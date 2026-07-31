import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/election.dart';

class PdfService {
  static Future<Uint8List> build(Election e) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final sorted = [...e.candidates]..sort((a, b) => b.votes.compareTo(a.votes));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => [
        pw.Text('BÁO CÁO KẾT QUẢ KIỂM PHIẾU', style: pw.TextStyle(font: bold, fontSize: 18)),
        pw.SizedBox(height: 10),
        pw.Text('Cuộc bầu cử: ${e.name}'),
        pw.Text('Đơn vị: ${e.unit}'),
        pw.Text('Mã: ${e.code}'),
        pw.Text('Tổng phiếu đã nhập: ${e.totalBallots}'),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Hạng', 'Ứng cử viên', 'Được chọn', 'Tỷ lệ', 'Không chọn'],
          data: List.generate(sorted.length, (i) {
            final c = sorted[i];
            final pct = e.totalBallots == 0 ? 0 : c.votes * 100 / e.totalBallots;
            return ['${i + 1}', c.name, '${c.votes}', '${pct.toStringAsFixed(2)}%', '${e.totalBallots - c.votes}'];
          }),
        ),
      ],
    ));
    return doc.save();
  }

  static Future<void> share(Election e) async {
    final bytes = await build(e);
    await Printing.sharePdf(bytes: bytes, filename: 'ket_qua_${e.code}.pdf');
  }
}
