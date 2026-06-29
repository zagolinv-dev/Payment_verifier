import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

class ReceiptPdfExport {
  static Future<Uint8List> _buildPdf({
    required String title,
    required Map<String, List<TransactionEntity>> grouped,
  }) async {
    final pdf = pw.Document();

    // Pre-fetch network image bytes for PDF embedding
    // Falls back to a signed URL if the public URL returns a non-200 status.
    final imageBytes = <String, Uint8List>{};
    final client = HttpClient();
    for (final txs in grouped.values) {
      for (final tx in txs) {
        final img = tx.receiptImage;
        if (img == null) continue;
        if (img.startsWith('http://') || img.startsWith('https://')) {
          // Strip fragment (#path=...) before fetching
          final fetchUrl = img.contains('#') ? img.substring(0, img.indexOf('#')) : img;
          try {
            final request = await client.getUrl(Uri.parse(fetchUrl));
            final response = await request.close();
            if (response.statusCode == 200) {
              final bytes = <int>[];
              await for (final chunk in response) bytes.addAll(chunk);
              imageBytes[tx.id] = Uint8List.fromList(bytes);
            } else {
              // Non-200: try a signed URL using the embedded storage path
              final storagePath = _extractStoragePath(img);
              if (storagePath != null) {
                try {
                  final signed = await Supabase.instance.client.storage
                      .from('receipts')
                      .createSignedUrl(storagePath, 3600);
                  final req2 = await client.getUrl(Uri.parse(signed));
                  final res2 = await req2.close();
                  if (res2.statusCode == 200) {
                    final bytes = <int>[];
                    await for (final chunk in res2) bytes.addAll(chunk);
                    imageBytes[tx.id] = Uint8List.fromList(bytes);
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        } else {
          try {
            final file = File(img);
            if (file.existsSync()) imageBytes[tx.id] = file.readAsBytesSync();
          } catch (_) {}
        }
      }
    }
    client.close();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "T's Verify",
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ),
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Generated: ${_pdfDateTime(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey400,
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Text(
          'Page ${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
          textAlign: pw.TextAlign.center,
        ),
        build: (context) {
          final pages = <pw.Widget>[];
          double grandTotalAmount = 0;
          double grandTotalTips = 0;
          int grandTotalCount = 0;

          final sortedScanners = grouped.keys.toList()..sort();

          for (final scannerName in sortedScanners) {
            final txs = grouped[scannerName]!;
            double scannerAmount = 0;
            double scannerTips = 0;
            int scannerCount = 0;

            for (final tx in txs) {
              if (tx.status == TransactionStatus.verified) {
                scannerAmount += tx.amount;
                scannerTips += tx.tip;
                scannerCount++;
              }
            }
            grandTotalAmount += scannerAmount;
            grandTotalTips += scannerTips;
            grandTotalCount += scannerCount;

            pages.add(pw.SizedBox(height: 16));
            pages.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _safe(scannerName),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.Text(
                      '$scannerCount scans',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            );

            pages.add(pw.SizedBox(height: 6));
            pages.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FixedColumnWidth(76),
                  2: const pw.FixedColumnWidth(52),
                  3: const pw.FixedColumnWidth(72),
                  4: const pw.FixedColumnWidth(56),
                  5: const pw.FixedColumnWidth(52),  // Tip — wider so values don't truncate
                  6: const pw.FixedColumnWidth(68),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _headerCell('#'),
                      _headerCell('Buyer'),
                      _headerCell('Bank'),
                      _headerCell('Reference'),
                      _headerCell('Amount'),
                      _headerCell('Tip'),
                      _headerCell('Date'),
                    ],
                  ),
                  for (int i = 0; i < txs.length; i++)
                    pw.TableRow(
                      children: [
                        _cell('${i + 1}'),
                        _cell(txs[i].buyerName),
                        _cell(txs[i].bankName.length > 8
                            ? '${txs[i].bankName.substring(0, 8)}...'
                            : txs[i].bankName),
                        _cell(txs[i].referenceCode.length > 10
                            ? '...${txs[i].referenceCode.substring(txs[i].referenceCode.length - 8)}'
                            : txs[i].referenceCode),
                        _cell(_pdfMoney(txs[i].amount)),
                        _tipCell(txs[i].tip > 0 ? _pdfMoney(txs[i].tip) : '-'),
                        _cell(AppFormatters.formatDateShort(txs[i].createdAt)),
                      ],
                    ),
                ],
              ),
            );

            // Receipt images for this scanner
            final txsWithImages = txs.where((t) => t.receiptImage != null).toList();
            if (txsWithImages.isNotEmpty) {
              pages.add(pw.SizedBox(height: 8));
              pages.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  child: pw.Text(
                    'Receipt Images:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              );
              pages.add(pw.SizedBox(height: 4));

              // Show images in rows of 3 with metadata captions
              for (int i = 0; i < txsWithImages.length; i += 3) {
                final rowTxs = txsWithImages.sublist(i, (i + 3).clamp(0, txsWithImages.length));
                final rowWidgets = <pw.Widget>[];
                for (final tx in rowTxs) {
                  try {
                    final bytes = imageBytes[tx.id];
                    if (bytes != null) {
                      final img = pw.MemoryImage(bytes);
                      rowWidgets.add(
                        pw.Expanded(
                          child: pw.Container(
                            margin: const pw.EdgeInsets.only(right: 4),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.ClipRect(
                                  child: pw.Image(img, width: 100, height: 120, fit: pw.BoxFit.cover),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  _safe(tx.referenceCode),
                                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                                  textAlign: pw.TextAlign.center,
                                ),
                                pw.Text(
                                  _safe(_pdfMoney(tx.amount)),
                                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                  textAlign: pw.TextAlign.center,
                                ),
                                if (tx.tip > 0)
                                  pw.Text(
                                    _safe('+${_pdfMoney(tx.tip)} tip'),
                                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                pw.SizedBox(height: 3),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      rowWidgets.add(pw.Expanded(child: pw.Container()));
                    }
                  } catch (_) {
                    rowWidgets.add(pw.Expanded(child: pw.Container()));
                  }
                }
                // Fill remaining slots in the row with empty containers
                while (rowWidgets.length < 3) {
                  rowWidgets.add(pw.Expanded(child: pw.Container()));
                }
                pages.add(
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: rowWidgets,
                  ),
                );
                pages.add(pw.SizedBox(height: 6));
              }
            }

            pages.add(pw.SizedBox(height: 6));
            pages.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Revenue:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(_pdfMoney(scannerAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Tips:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(
                          scannerTips > 0 ? _pdfMoney(scannerTips) : '-',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Divider(thickness: 0.5, color: PdfColors.green300),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total (incl. tips):', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text(_pdfMoney(scannerAmount + scannerTips), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          pages.add(pw.Divider(thickness: 2));
          pages.add(pw.SizedBox(height: 8));
          pages.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green800,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Total Scans: $grandTotalCount',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
                  ),
                  pw.Text(
                    'Total Revenue: ${_pdfMoney(grandTotalAmount)}',
                    style: pw.TextStyle(fontSize: 13, color: PdfColors.white),
                  ),
                  pw.Text(
                    'Total Tips: ${_pdfMoney(grandTotalTips)}',
                    style: pw.TextStyle(fontSize: 13, color: PdfColors.amberAccent),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Grand Total (Revenue + Tips): ${_pdfMoney(grandTotalAmount + grandTotalTips)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
          );

          return pages;
        },
      ),
    );

    return pdf.save();
  }

  /// Strip non-ASCII characters so the default PDF font always renders cleanly.
  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');

  static String _pdfDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  /// Plain ASCII currency format safe for PDF rendering (no locale-specific symbols)
  static String _pdfMoney(double amount) {
    return 'Br ${amount.toStringAsFixed(2)}';
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        _safe(text),
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        _safe(text),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
      ),
    );
  }

  /// Tip cell — bold so tips are visually distinct
  static pw.Widget _tipCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        _safe(text),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  /// Extracts the Supabase Storage path from a receipt URL.
  /// Handles both the "#path=..." fragment we embed and the URL path itself.
  static String? _extractStoragePath(String url) {
    // Check embedded fragment: "#path=userId/receipt_123.jpg"
    final uri = Uri.tryParse(url);
    if (uri != null && uri.fragment.startsWith('path=')) {
      return uri.fragment.substring(5);
    }
    // Fallback: parse from URL path ".../receipts/userId/receipt_123.jpg"
    final match = RegExp(r'/receipts/(.+?)(?:\?|$)').firstMatch(url);
    return match?.group(1);
  }

  static Map<String, List<TransactionEntity>> _groupByScanner(
    List<TransactionEntity> transactions,
    Map<String, String> scannerIdToName,
  ) {
    final grouped = <String, List<TransactionEntity>>{};
    for (final tx in transactions) {
      final name = tx.verifiedBy != null
          ? (scannerIdToName[tx.verifiedBy] ?? tx.verifiedBy!)
          : 'Unknown';
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(tx);
    }
    return grouped;
  }

  static Future<void> exportAllReceipts({
    required List<TransactionEntity> transactions,
    required Map<String, String> scannerIdToName,
  }) async {
    final grouped = _groupByScanner(transactions, scannerIdToName);
    final pdfBytes = await _buildPdf(
      title: 'All Receipts Export - 7+ Days Report',
      grouped: grouped,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'receipts_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportWaiterReceipts({
    required List<TransactionEntity> transactions,
    required String waiterName,
  }) async {
    final grouped = {waiterName: transactions};
    final pdfBytes = await _buildPdf(
      title: 'Scanned Receipts - $waiterName',
      grouped: grouped,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${waiterName.replaceAll(' ', '_')}_receipts.pdf',
    );
  }
}
