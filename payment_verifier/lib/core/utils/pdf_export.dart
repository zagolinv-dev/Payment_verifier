import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:payment_verifier/core/utils/formatters.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

class ReceiptPdfExport {
  static Future<Uint8List> _buildPdf({
    required String title,
    required Map<String, List<TransactionEntity>> grouped,
  }) async {
    final pdf = pw.Document();

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
              'Generated: ${AppFormatters.formatDateTime(DateTime.now())}',
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
                      scannerName,
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
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FixedColumnWidth(80),
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
                        _cell(AppFormatters.formatETB(txs[i].amount)),
                        _cell(txs[i].tip > 0 ? AppFormatters.formatETB(txs[i].tip) : '—'),
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
                pw.Text(
                  'Receipt Images:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              );
              pages.add(pw.SizedBox(height: 4));

              // Show images in rows of 3
              for (int i = 0; i < txsWithImages.length; i += 3) {
                final rowTxs = txsWithImages.sublist(i, (i + 3).clamp(0, txsWithImages.length));
                final rowWidgets = <pw.Widget>[];
                for (final tx in rowTxs) {
                  try {
                    final file = File(tx.receiptImage!);
                    if (file.existsSync()) {
                      final bytes = file.readAsBytesSync();
                      final img = pw.MemoryImage(bytes);
                      rowWidgets.add(
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              pw.Image(img, width: 80, height: 100, fit: pw.BoxFit.cover),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                tx.buyerName.length > 12
                                    ? '${tx.buyerName.substring(0, 12)}...'
                                    : tx.buyerName,
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      rowWidgets.add(
                        pw.Expanded(child: pw.Container()),
                      );
                    }
                  } catch (_) {
                    rowWidgets.add(
                      pw.Expanded(child: pw.Container()),
                    );
                  }
                }
                pages.add(
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: rowWidgets,
                  ),
                );
                pages.add(pw.SizedBox(height: 4));
              }
            }

            pages.add(pw.SizedBox(height: 6));
            pages.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Subtotal: ${AppFormatters.formatETB(scannerAmount)}  |  Tips: ${AppFormatters.formatETB(scannerTips)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
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
                    'Total Revenue: ${AppFormatters.formatETB(grandTotalAmount)}',
                    style: pw.TextStyle(fontSize: 13, color: PdfColors.white),
                  ),
                  pw.Text(
                    'Total Tips: ${AppFormatters.formatETB(grandTotalTips)}',
                    style: pw.TextStyle(fontSize: 13, color: PdfColors.amberAccent),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Grand Total (Revenue + Tips): ${AppFormatters.formatETB(grandTotalAmount + grandTotalTips)}',
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
      title: 'All Receipts Export — 7+ Days Report',
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
      title: 'Scanned Receipts — $waiterName',
      grouped: grouped,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${waiterName.replaceAll(' ', '_')}_receipts.pdf',
    );
  }
}
