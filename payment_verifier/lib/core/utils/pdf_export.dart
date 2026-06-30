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

    final allTxs = grouped.values.expand((l) => l).toList();

    // Pre-fetch network image bytes for PDF embedding
    final imageBytes = <String, Uint8List>{};
    final client = HttpClient();
    for (final txs in grouped.values) {
      for (final tx in txs) {
        final img = tx.receiptImage;
        if (img == null) continue;
        if (img.startsWith('http://') || img.startsWith('https://')) {
          final fetchUrl = img.contains('#') ? img.substring(0, img.indexOf('#')) : img;
          try {
            final request = await client.getUrl(Uri.parse(fetchUrl));
            final response = await request.close();
            if (response.statusCode == 200) {
              final bytes = <int>[];
              await for (final chunk in response) bytes.addAll(chunk);
              imageBytes[tx.id] = Uint8List.fromList(bytes);
            } else {
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

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    double periodRevenue(List<TransactionEntity> txs, DateTime start) {
      double s = 0;
      for (final tx in txs) {
        if (tx.status == TransactionStatus.verified && tx.createdAt.isAfter(start)) {
          s += tx.amount + tx.tip;
        }
      }
      return s;
    }

    int periodCount(List<TransactionEntity> txs, DateTime start) {
      int c = 0;
      for (final tx in txs) {
        if (tx.status == TransactionStatus.verified && tx.createdAt.isAfter(start)) c++;
      }
      return c;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
                  _pdfDateTime(now),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Container(height: 1, color: PdfColors.green200),
            pw.SizedBox(height: 6),
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 13,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
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

          // ── Period Summary Cards ──
          final periodData = <(String label, DateTime start)>[
            ('Today', todayStart),
            ('This Week', weekStart),
            ('This Month', monthStart),
            ('This Year', yearStart),
            ('All Time', DateTime(2000)),
          ];

          pages.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.green200, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Revenue Summary',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  for (final p in periodData)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            p.$1,
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            '${_pdfMoney(periodRevenue(allTxs, p.$2))}  (${periodCount(allTxs, p.$2)} scans)',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );

          pages.add(pw.SizedBox(height: 14));

          // ── Scanner Breakdown ──
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

            pages.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      scannerName,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.Text(
                      '$scannerCount scans — ${_pdfMoney(scannerAmount)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            );
            pages.add(pw.SizedBox(height: 6));

            // ── Transactions Table ──
            if (txs.isNotEmpty) {
              pages.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(20),
                    1: const pw.FixedColumnWidth(72),
                    2: const pw.FixedColumnWidth(46),
                    3: const pw.FixedColumnWidth(68),
                    4: const pw.FixedColumnWidth(52),
                    5: const pw.FixedColumnWidth(48),
                    6: const pw.FixedColumnWidth(62),
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
                        decoration: txs[i].tip > 0
                            ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFFDE7))
                            : null,
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
                          txs[i].tip > 0
                              ? _tipCell(_pdfMoney(txs[i].tip))
                              : _cell('-'),
                          _cell(AppFormatters.formatDateShort(txs[i].createdAt)),
                        ],
                      ),
                  ],
                ),
              );
            }

            // ── Receipt Images Grid ──
            final txsWithImages = txs.where((t) => t.receiptImage != null).toList();
            if (txsWithImages.isNotEmpty) {
              pages.add(pw.SizedBox(height: 10));
              pages.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: pw.Text(
                    'Receipt Images',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              );
              pages.add(pw.SizedBox(height: 4));

              for (int i = 0; i < txsWithImages.length; i += 2) {
                final rowTxs = txsWithImages.sublist(i, (i + 2).clamp(0, txsWithImages.length));
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
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Image(img, width: 160, height: 180, fit: pw.BoxFit.cover),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  width: double.infinity,
                                  color: PdfColors.grey50,
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        tx.referenceCode,
                                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                                      ),
                                      pw.SizedBox(height: 1),
                                      pw.Text(
                                        '${_pdfMoney(tx.amount)}${tx.tip > 0 ? ' (+${_pdfMoney(tx.tip)} tip)' : ''}',
                                        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                      ),
                                    ],
                                  ),
                                ),
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
                while (rowWidgets.length < 2) {
                  rowWidgets.add(pw.Expanded(child: pw.Container()));
                }
                pages.add(
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: rowWidgets,
                  ),
                );
                pages.add(pw.SizedBox(height: 8));
              }
            }

            // ── Scanner Summary ──
            pages.add(pw.SizedBox(height: 6));
            pages.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _summaryRow('Revenue', _pdfMoney(scannerAmount), PdfColors.green800),
                    pw.SizedBox(height: 2),
                    _summaryRow(
                      'Tips',
                      scannerTips > 0 ? _pdfMoney(scannerTips) : '-',
                      PdfColors.amber,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Divider(thickness: 0.5, color: PdfColors.green300),
                    pw.SizedBox(height: 2),
                    _summaryRow(
                      'Total (incl. tips)',
                      _pdfMoney(scannerAmount + scannerTips),
                      PdfColors.green800,
                    ),
                  ],
                ),
              ),
            );

            pages.add(pw.SizedBox(height: 14));
          }

          // ── Grand Total ──
          pages.add(pw.Divider(thickness: 1.5, color: PdfColors.green300));
          pages.add(pw.SizedBox(height: 8));
          pages.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.green800,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                  pw.SizedBox(height: 6),
                  _grandTotalRow('Total Scans', '$grandTotalCount'),
                  pw.SizedBox(height: 3),
                  _grandTotalRow('Revenue', _pdfMoney(grandTotalAmount)),
                  pw.SizedBox(height: 3),
                  _grandTotalRow('Tips', _pdfMoney(grandTotalTips)),
                  pw.SizedBox(height: 3),
                  pw.Divider(thickness: 0.5, color: PdfColors.green400),
                  pw.SizedBox(height: 4),
                  _grandTotalRow(
                    'Grand Total (Revenue + Tips)',
                    _pdfMoney(grandTotalAmount + grandTotalTips),
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

  static String _pdfMoney(double amount) {
    return 'Br ${amount.toStringAsFixed(2)}';
  }

  static String _pdfDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
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
        text,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _tipCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.amber,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _grandTotalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: label.startsWith('Grand') ? 14 : 11, color: PdfColors.white)),
        pw.Text(value, style: pw.TextStyle(fontSize: label.startsWith('Grand') ? 14 : 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ],
    );
  }

  static String? _extractStoragePath(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.fragment.startsWith('path=')) {
      return uri.fragment.substring(5);
    }
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
