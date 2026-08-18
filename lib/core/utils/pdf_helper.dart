import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';

class PdfHelper {
  static String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'نقداً';
      case 'bank':
        return 'تحويل بنكي';
      case 'card':
        return 'بطاقة';
      default:
        return method;
    }
  }

  /// Generate a thermal receipt PDF (80mm width)
  static pw.Document _buildReceipt(Invoice invoice) {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicBoldFont));
    final fmt = NumberFormat('#,##0.00');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
              // Restaurant name
              pw.Text(
                'Hot Burger',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'فاتورة مبيعات',
                style: pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Invoice details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم الفاتورة:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text(invoice.invoiceNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('التاريخ:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    invoice.createdAt != null
                        ? DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(DateTime.parse(invoice.createdAt!))
                        : DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              if (invoice.status.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الحالة:', style: pw.TextStyle(fontSize: 9)),
                    pw.Text(invoice.status, style: pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('طريقة الدفع:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    _paymentMethodLabel(invoice.paymentMethod),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Products table header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text('المنتج', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    width: 30,
                    child: pw.Text('الكمية', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    width: 45,
                    child: pw.Text('السعر', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    width: 50,
                    child: pw.Text('الإجمالي', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),

              // Products list
              if (invoice.items != null)
                ...invoice.items!.map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            item.productName,
                            style: pw.TextStyle(fontSize: 8),
                            maxLines: 1,
                            // overflow: pw.TextOverflow.ellipsis, // Not available in this version of pdf package
                          ),
                        ),
                        pw.Container(
                          width: 30,
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          width: 45,
                          child: pw.Text(
                            '${fmt.format(item.price)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          width: 50,
                          child: pw.Text(
                            '${fmt.format(item.total)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Totals
              pw.Column(
                children: [
                  if (invoice.discountAmount > 0) ...[
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('الإجمالي الفرعي:', style: pw.TextStyle(fontSize: 9)),
                      pw.Text('${fmt.format(invoice.subtotalAmount)} ج.س', style: pw.TextStyle(fontSize: 9)),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('الخصم:', style: pw.TextStyle(fontSize: 9)),
                      pw.Text('- ${fmt.format(invoice.discountAmount)} ج.س', style: pw.TextStyle(fontSize: 9)),
                    ]),
                    pw.SizedBox(height: 3),
                  ],
                  pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${fmt.format(invoice.totalAmount)} ج.س', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (invoice.paymentMethod == 'cash') ...[
                    pw.SizedBox(height: 3),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('المستلم:', style: pw.TextStyle(fontSize: 9)),
                      pw.Text('${fmt.format(invoice.paidAmount)} ج.س', style: pw.TextStyle(fontSize: 9)),
                    ]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('الباقي:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${fmt.format(invoice.changeAmount)} ج.س', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                ],
              ),

              pw.SizedBox(height: 6),

              // Notes
              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'ملاحظات: ${invoice.notes}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ),

              pw.SizedBox(height: 8),
              pw.Text(
                'شكراً لزيارتكم',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Hot Burger © ${DateTime.now().year}',
                style: pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  // الخطوط العربية (تُحمّل مرة واحدة عبر rootBundle)
  static pw.Font? _arabicFont;
  static pw.Font? _arabicBoldFont;

  static Future<void> _loadArabicFonts() async {
    _arabicFont ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    _arabicBoldFont ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
  }

  /// Print or preview the invoice
  static Future<void> printInvoice(Invoice invoice) async {
    await _loadArabicFonts();
    final pdf = _buildReceipt(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'فاتورة_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Generate an inventory audit trail PDF report (reuses the Arabic font system)
  static Future<void> printInventoryHistoryReport(List<Map<String, dynamic>> logs) async {
    await _loadArabicFonts();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicBoldFont));
    final fmt = NumberFormat('#,##0.####');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  pw.Text('Hot Burger', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('تقرير سجل حركات المخزون', style: pw.TextStyle(fontSize: 13), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('عدد الحركات: ${logs.length}', textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(2.5), 1: pw.FlexColumnWidth(1.8), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.3), 5: pw.FlexColumnWidth(1.2)},
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Text('المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('النوع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('قبل', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('التغيير', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('بعد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('التاريخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  ],
                ),
                ...logs.map((log) {
                  final change = (log['quantity_change'] as num).toDouble();
                  final date = DateTime.parse(log['action_date'] as String);
                  return pw.TableRow(
                    children: [
                      pw.Text((log['ingredient_name'] as String?) ?? '-', textAlign: pw.TextAlign.center),
                      pw.Text(_arabicActionLabel(log['action_type'] as String), textAlign: pw.TextAlign.center),
                      pw.Text(fmt.format((log['quantity_before'] as num).toDouble()), textAlign: pw.TextAlign.center),
                      pw.Text('${change >= 0 ? '+' : ''}${fmt.format(change)}', textAlign: pw.TextAlign.center),
                      pw.Text(fmt.format((log['quantity_after'] as num).toDouble()), textAlign: pw.TextAlign.center),
                      pw.Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}', textAlign: pw.TextAlign.center),
                    ],
                  );
                }),
              ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'سجل_حركات_المخزون_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf',
    );
  }

  static String _arabicActionLabel(String action) {
    const labels = {
      'added': 'إضافة مادة',
      'edited': 'تعديل مادة',
      'manual_adjust': 'تعديل يدوي',
      'price_changed': 'تعديل السعر',
      'purchase': 'شراء',
      'sale': 'بيع',
      'sale_deleted': 'استرجاع',
    };
    return labels[action] ?? action;
  }

  /// Generate a thermal shift report PDF (80mm width)
  static pw.Document _buildShiftReport(Map<String, dynamic> summary, {DateTime? startDate, DateTime? endDate}) {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicBoldFont));
    final fmt = NumberFormat('#,##0.00');
    final start = startDate ?? DateTime.now();
    final end = endDate ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
              pw.Text('Hot Burger', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('تقرير تقفيل الوردية', style: pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الفترة:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${DateFormat('yyyy/MM/dd').format(start)} - ${DateFormat('yyyy/MM/dd').format(end)}', style: pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('التاريخ:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text(DateFormat('yyyy/MM/dd', 'ar').format(DateTime.now()), style: pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('عدد الفواتير:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${summary['invoiceCount']}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المبيعات:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${fmt.format(summary['totalSales'])} ج.س', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('نقداً:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${fmt.format(summary['cashTotal'])} ج.س', style: pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('تحويل بنكي:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${fmt.format(summary['bankTotal'])} ج.س', style: pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('بطاقة:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${fmt.format(summary['cardTotal'])} ج.س', style: pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('صافي الربح:', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('${fmt.format(summary['grossProfitFromSnapshot'] ?? 0)} ج.س', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Text('شكراً لزيارتكم', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text('Hot Burger © ${DateTime.now().year}', style: pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
    return pdf;
  }

  /// Print shift report
  static Future<void> printShiftReport(Map<String, dynamic> summary, {DateTime? startDate, DateTime? endDate}) async {
    await _loadArabicFonts();
    final pdf = _buildShiftReport(summary, startDate: startDate, endDate: endDate);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'تقرير_وردية_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf',
    );
  }

  /// Show a dialog to choose between print, preview, or share
  static Future<void> showPrintOptions(BuildContext context, Invoice invoice) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خيارات الفاتورة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('طباعة / معاينة'),
                subtitle: const Text('عرض الفاتورة أو إرسالها للطابعة الحرارية'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  printInvoice(invoice);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('إلغاء'),
                onTap: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
