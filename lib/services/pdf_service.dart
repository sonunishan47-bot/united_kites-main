import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/crm.dart';
import '../models/enums.dart';
import '../models/invoice.dart';
import '../models/shop_settings.dart';
import '../services/analytics_engine.dart';
import '../utils/formatters.dart';

class PdfService {
  const PdfService();

  static const _headerPurple = PdfColor.fromInt(0xFF5B67B8);
  static const _rowTint = PdfColor.fromInt(0xFFF3F0FA);
  static const _totalTint = PdfColor.fromInt(0xFFE8E4F5);
  static const _ink = PdfColor.fromInt(0xFF1A1A1A);

  PdfPageFormat thermalFormat(ShopSettings settings) => _thermalPage(settings);

  PdfPageFormat _thermalPage(ShopSettings settings) {
    final narrow = settings.paper == PaperProfile.thermal58;
    final base = narrow ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    return base.copyWith(
      marginLeft: narrow ? 8 : 10,
      marginRight: narrow ? 8 : 10,
      marginTop: 8,
      marginBottom: 12,
    );
  }

  String _fit(String value, {required bool narrow}) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final width = narrow ? 22 : 32;
    if (text.length <= width) return text;
    final lines = <String>[];
    for (var i = 0; i < text.length; i += width) {
      final end = i + width > text.length ? text.length : i + width;
      lines.add(text.substring(i, end));
    }
    return lines.join('\n');
  }

  pw.MemoryImage? _profileLogo(ShopSettings settings) {
    final custom = settings.logoBytes;
    if (custom == null || custom.isEmpty) return null;
    return pw.MemoryImage(custom);
  }

  Future<void> preview(Invoice invoice, ShopSettings settings) {
    final thermal = settings.paper.isThermal;
    return Printing.layoutPdf(
      name: invoice.invoiceNo,
      format: thermal ? thermalFormat(settings) : PdfPageFormat.a4,
      usePrinterSettings: true,
      onLayout: (format) => thermal
          ? buildThermal(invoice, settings)
          : buildA4(invoice, settings),
    );
  }

  Future<void> printThermal(Invoice invoice, ShopSettings settings, {bool duplicate = false}) {
    final format = thermalFormat(settings);
    return Printing.layoutPdf(
      name: '${invoice.invoiceNo}-${settings.paper.label}',
      format: format,
      usePrinterSettings: true,
      onLayout: (_) => buildThermal(invoice, settings, duplicate: duplicate),
    );
  }

  Future<void> shareA4(Invoice invoice, ShopSettings settings, {bool duplicate = false}) async {
    final bytes = await buildA4(invoice, settings, duplicate: duplicate);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${invoice.invoiceNo}.pdf',
      subject: invoice.isCreditNote ? 'Credit Note ${invoice.invoiceNo}' : 'Tax Invoice ${invoice.invoiceNo}',
    );
  }

  /// Defaults to A4 tax invoice for WhatsApp / email.
  Future<void> share(Invoice invoice, ShopSettings settings) =>
      shareA4(invoice, settings);

  Future<Uint8List> build(
    Invoice invoice,
    ShopSettings settings,
    PdfPageFormat format,
  ) {
    final thermal = format.width <= PdfPageFormat.roll80.width + 8;
    return thermal
        ? buildThermal(invoice, settings)
        : buildA4(invoice, settings);
  }

  Future<Uint8List> buildThermal(Invoice invoice, ShopSettings settings, {bool duplicate = false}) async {
    pw.Font? arabic;
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!inTest) {
      try {
        arabic = await PdfGoogleFonts.notoNaskhArabicRegular()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: _thermalPage(settings),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          fontFallback: [?arabic],
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: _thermal(
            invoice,
            settings,
            hasArabicFont: arabic != null,
            logo: _profileLogo(settings),
            duplicate: duplicate || invoice.printCount > 0,
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildA4(Invoice invoice, ShopSettings settings, {bool duplicate = false}) async {
    final logo = _profileLogo(settings);

    pw.Font? arabic;
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!inTest) {
      try {
        arabic = await PdfGoogleFonts.notoNaskhArabicRegular()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 24,
          marginBottom: 24,
        ),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          fontFallback: [?arabic],
        ),
        build: (context) => [
          _a4Header(invoice, settings, logo: logo, arabic: arabic),
          pw.SizedBox(height: 14),
          _a4Title(invoice, duplicate: duplicate || invoice.printCount > 0),
          pw.SizedBox(height: 14),
          _a4Meta(invoice, settings),
          pw.SizedBox(height: 12),
          _a4Table(invoice),
          pw.SizedBox(height: 10),
          _a4Summary(invoice),
          pw.SizedBox(height: 22),
          _a4Footer(invoice, settings, arabic: arabic != null),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _a4Header(
    Invoice invoice,
    ShopSettings settings, {
    pw.MemoryImage? logo,
    pw.Font? arabic,
  }) {
    final name = settings.zatcaSellerName.toUpperCase();
    pw.Widget line(String label, String value) {
      if (value.trim().isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.Text(
          '$label$value',
          style: const pw.TextStyle(fontSize: 9, color: _ink),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (arabic != null && settings.hasDistinctArabicName)
                pw.Text(
                  settings.shopNameAr,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: arabic,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              if (settings.printAddress.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3, bottom: 2),
                  child: pw.Text(
                    settings.printAddress,
                    style: const pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                ),
              line('Phone: ', settings.phone),
              if (settings.phone2.isNotEmpty) line('Phone 2: ', settings.phone2),
              line('Email: ', settings.email),
              if (settings.printTrnCr) ...[
                line('TRN / VAT: ', settings.vatTrn.isEmpty ? '-' : settings.vatTrn),
                line('CR: ', settings.crNumber.isEmpty ? '-' : settings.crNumber),
              ],
              if (arabic != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.isCreditNote ? 'إشعار دائن' : 'فاتورة ضريبية',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: arabic,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(
          width: 92,
          height: 92,
          child: settings.options.showLogo && logo != null
              ? pw.Image(logo, fit: pw.BoxFit.contain)
              : pw.SizedBox(),
        ),
      ],
    );
  }

  pw.Widget _a4Title(Invoice invoice, {bool duplicate = false}) {
    final title = invoice.isCreditNote ? 'Credit Note' : 'Tax Invoice';
    return pw.Column(
      children: [
        if (duplicate)
          pw.Text(
            'DUPLICATE COPY',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        if (duplicate) pw.SizedBox(height: 4),
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Container(
            width: 118,
            height: 1.4,
            color: _ink,
          ),
        ),
      ],
    );
  }

  pw.Widget _a4Meta(Invoice invoice, ShopSettings settings) {
    pw.Widget kv(String k, String v) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 92,
              child: pw.Text(
                k,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(
              child: pw.Text(':  $v', style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );
    }

    final billName = invoice.shopName.isNotEmpty
        ? invoice.shopName
        : invoice.customerName;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Bill To',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(billName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              if (invoice.shopName.isNotEmpty && invoice.customerName != invoice.shopName)
                pw.Text(invoice.customerName, style: const pw.TextStyle(fontSize: 9)),
              if (invoice.customerPhone.isNotEmpty)
                pw.Text(invoice.customerPhone, style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                _isB2b(invoice) ? 'B2B standard tax invoice' : 'B2C simplified tax invoice',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (invoice.customerTrn.isNotEmpty)
                pw.Text('Buyer VAT ${invoice.customerTrn}', style: const pw.TextStyle(fontSize: 9)),
              if (invoice.buyerCr.isNotEmpty)
                pw.Text('Buyer CR ${invoice.buyerCr}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.SizedBox(
          width: 220,
          child: pw.Column(
            children: [
              kv(invoice.isCreditNote ? 'Credit Note No.' : 'Invoice No.', invoice.invoiceNo),
              kv('Date', invoiceDate.format(invoice.createdAt)),
              kv('Date of Supply', invoiceDate.format(invoice.createdAt)),
              if (invoice.originalInvoiceNo != null)
                kv('Original Invoice', invoice.originalInvoiceNo!),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _a4Table(Invoice invoice) {
    const headers = [
      '#',
      'Item Name',
      'Count',
      'Quantity',
      'Unit',
      'Price/Unit',
      'Net / VAT',
      'Amount (SAR)',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(3.2),
      2: const pw.FixedColumnWidth(38),
      3: const pw.FixedColumnWidth(48),
      4: const pw.FixedColumnWidth(36),
      5: const pw.FixedColumnWidth(58),
      6: const pw.FixedColumnWidth(62),
      7: const pw.FixedColumnWidth(62),
    };

    pw.Widget headCell(String text) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );

    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.center}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 8)),
        );

    String unitOf(InvoiceLine line) => switch (line.billingUnit) {
          BillingUnit.dozen => 'Dz',
          BillingUnit.box => 'Box',
          BillingUnit.carton => 'Ctn',
          BillingUnit.piece => 'Pcs',
        };

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerPurple),
        children: [for (final h in headers) headCell(h)],
      ),
      for (var i = 0; i < invoice.lines.length; i++)
        pw.TableRow(
          decoration: i.isOdd ? const pw.BoxDecoration(color: _rowTint) : null,
          children: [
            cell('${i + 1}'),
            cell(
              [
                invoice.lines[i].itemName,
                if (invoice.lines[i].variant.isNotEmpty) invoice.lines[i].variant,
              ].join('\n'),
              align: pw.TextAlign.left,
            ),
            cell(invoice.lines[i].quantity.toStringAsFixed(0)),
            cell(invoice.lines[i].stockPieces.toStringAsFixed(0)),
            cell(unitOf(invoice.lines[i])),
            cell(moneyFixed(invoice.lines[i].unitPrice)),
            cell('${moneyFixed(invoice.lines[i].taxable)}\n${moneyFixed(invoice.lines[i].tax)}'),
            cell(moneyFixed(invoice.lines[i].lineTotal)),
          ],
        ),
    ];

    final totalCount = invoice.lines.fold<double>(0, (s, l) => s + l.quantity);
    final totalQty = invoice.lines.fold<double>(0, (s, l) => s + l.stockPieces);

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _totalTint),
        children: [
          cell(''),
          cell('Total', align: pw.TextAlign.left),
          cell(totalCount.toStringAsFixed(0)),
          cell(totalQty.toStringAsFixed(0)),
          cell(''),
          cell(''),
          cell(invoice.taxTotal.toStringAsFixed(2)),
          cell(invoice.grandTotal.toStringAsFixed(2)),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _headerPurple, width: 0.6),
      columnWidths: widths,
      children: rows,
    );
  }

  pw.Widget _a4Summary(Invoice invoice) {
    pw.Widget moneyRow(String label, String value, {bool highlight = false, bool bold = false}) {
      return pw.Container(
        color: highlight ? _totalTint : null,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold || highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold || highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice Amount In Words',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
                ),
                child: pw.Text(
                  amountInWords(invoice.grandTotal),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (invoice.notes.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Notes: ${invoice.notes}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 210,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
            ),
            child: pw.Column(
              children: [
                moneyRow('Sub Total', invoice.goodsTotal.toStringAsFixed(2)),
                moneyRow('Discount', invoice.discount.toStringAsFixed(2)),
                moneyRow('Taxable', invoice.taxableNet.toStringAsFixed(2)),
                moneyRow('VAT 15% / ${invoice.taxPercent.toStringAsFixed(0)}%', invoice.taxTotal.toStringAsFixed(2)),
                moneyRow(
                  invoice.isCreditNote ? 'Credit Amount' : 'Total',
                  invoice.grandTotal.toStringAsFixed(2),
                  highlight: true,
                  bold: true,
                ),
                if (invoice.isCreditNote) ...[
                  moneyRow('Received Amount', '0.00'),
                  moneyRow(
                    "You'll Get (after credit)",
                    (invoice.outstandingAfter ?? 0).toStringAsFixed(2),
                    bold: true,
                  ),
                ] else ...[
                  moneyRow('Received Amount', invoice.amountPaid.toStringAsFixed(2)),
                  moneyRow('Balance Due', invoice.balanceDue.toStringAsFixed(2), bold: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _footerText(String note, {required bool arabic}) {
    if (arabic) return note;
    final latin = note.replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return latin.isEmpty ? 'Thank you' : latin;
  }

  pw.Widget _a4Footer(Invoice invoice, ShopSettings settings, {required bool arabic}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qr(invoice, size: 78),
            pw.SizedBox(height: 4),
            pw.Text(
              'ZATCA Phase 1 / 2 QR',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Spacer(),
        pw.SizedBox(
          width: 180,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (settings.options.showSignature) ...[
                if (settings.signatureBytes != null) ...[
                  pw.Image(
                    pw.MemoryImage(settings.signatureBytes!),
                    height: 42,
                    fit: pw.BoxFit.contain,
                  ),
                  pw.SizedBox(height: 4),
                ] else
                  pw.SizedBox(height: 36),
                pw.Container(width: 160, height: 0.8, color: _ink),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Authorized Signatory',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
              if (_customerSig(invoice) != null) ...[
                pw.SizedBox(height: 10),
                pw.Image(_customerSig(invoice)!, height: 36, fit: pw.BoxFit.contain),
                pw.Container(width: 160, height: 0.8, color: _ink),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Customer signature',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
              if (settings.options.showFooter && settings.footerNote.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    _footerText(settings.footerNote, arabic: arabic),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ),
              if (settings.options.showTerms && settings.options.termsText.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(settings.options.termsText, style: const pw.TextStyle(fontSize: 7)),
                ),
              if (settings.printBankDetails && settings.bankPrintText.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    'Bank / IBAN\n${settings.bankPrintText}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isB2b(Invoice invoice) => invoice.customerTrn.trim().isNotEmpty;

  String _title(Invoice invoice) {
    if (invoice.isCreditNote) return 'CREDIT NOTE';
    if (_isB2b(invoice)) return 'TAX INVOICE  B2B';
    return 'SIMPLIFIED TAX INVOICE  B2C';
  }

  pw.Widget _header(
    Invoice invoice,
    ShopSettings settings, {
    required bool compact,
    required bool hasArabicFont,
    pw.MemoryImage? logo,
    bool duplicate = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (duplicate)
          pw.Text(
            'DUPLICATE COPY',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        if (duplicate) pw.SizedBox(height: 4),
        if (logo != null && settings.options.showLogo) ...[
          pw.Center(child: pw.Image(logo, height: compact ? 32 : 48, fit: pw.BoxFit.contain)),
          pw.SizedBox(height: 4),
        ],
        pw.Text(
          _fit(settings.zatcaSellerName, narrow: settings.paper == PaperProfile.thermal58),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: compact ? 11 : 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (hasArabicFont && settings.hasDistinctArabicName)
          pw.Text(
            settings.shopNameAr,
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: compact ? 8 : 10, fontWeight: pw.FontWeight.bold),
          ),
        if (settings.printAddress.isNotEmpty)
          pw.Text(settings.printAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
        if (settings.phone.isNotEmpty)
          pw.Text(settings.phone, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
        if (settings.phone2.isNotEmpty)
          pw.Text(settings.phone2, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
        if (settings.email.isNotEmpty)
          pw.Text(settings.email, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
        if (settings.printTrnCr) ...[
          pw.Text(
            'TRN / VAT ${settings.vatTrn.isEmpty ? '-' : settings.vatTrn}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'CR ${settings.crNumber.isEmpty ? '-' : settings.crNumber}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          _title(invoice),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: compact ? 8 : 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          _isB2b(invoice)
              ? 'Buyer VAT ${invoice.customerTrn}'
              : 'B2C simplified · no buyer VAT',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.Text(invoice.invoiceNo, textAlign: pw.TextAlign.center),
        pw.Text(
          'ICV ${invoice.icv}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.Text(
          _fit('UUID ${invoice.uuid.isEmpty ? invoice.id : invoice.uuid}', narrow: settings.paper == PaperProfile.thermal58),
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 6),
        ),
        pw.Text(
          settings.options.printTime ? isoStamp(invoice.createdAt) : invoiceDate.format(invoice.createdAt),
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.Text(invoice.location.label, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _qr(Invoice invoice, {double size = 72}) {
    final data = invoice.zatcaQr.isNotEmpty
        ? invoice.zatcaQr
        : ZatcaQr.encode(
            sellerName: invoice.sellerName.isNotEmpty
                ? invoice.sellerName
                : invoice.shopName,
            vatNumber: invoice.vatTrn,
            timestamp: invoice.createdAt,
            totalWithVat: invoice.grandTotal,
            vatAmount: invoice.taxTotal,
          );
    return pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: data,
      width: size,
      height: size,
    );
  }

  List<pw.Widget> _thermal(
    Invoice invoice,
    ShopSettings settings, {
    required bool hasArabicFont,
    pw.MemoryImage? logo,
    bool duplicate = false,
  }) {
    final narrow = settings.paper == PaperProfile.thermal58;
    final fs = narrow ? 7.0 : 8.0;
    final b2b = _isB2b(invoice);
    final footer = hasArabicFont
        ? settings.footerNote
        : 'Thank you | ZATCA simplified tax invoice';
    return [
        _header(
          invoice,
          settings,
          compact: true,
          hasArabicFont: hasArabicFont,
          logo: logo,
          duplicate: duplicate,
        ),
        pw.Divider(),
        pw.Text(
          'CUSTOMER',
          style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          invoice.shopName.isNotEmpty ? invoice.shopName : invoice.customerName,
          style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
        ),
        if (invoice.shopName.isNotEmpty && invoice.customerName.isNotEmpty)
          pw.Text(invoice.customerName, style: pw.TextStyle(fontSize: fs)),
        if (invoice.customerPhone.isNotEmpty)
          pw.Text(invoice.customerPhone, style: pw.TextStyle(fontSize: fs)),
        if (invoice.customerTrn.isNotEmpty)
          pw.Text('Buyer VAT ${invoice.customerTrn}', style: pw.TextStyle(fontSize: fs)),
        if (invoice.buyerCr.isNotEmpty)
          pw.Text('Buyer CR ${invoice.buyerCr}', style: pw.TextStyle(fontSize: fs)),
        pw.Text(
          'Pay: ${invoice.resolvedPayMethod.toUpperCase()}',
          style: pw.TextStyle(fontSize: fs),
        ),
        if (invoice.pih.isNotEmpty)
          pw.Text(
            'PIH ${shortRef(invoice.pih, 16)}...',
            style: pw.TextStyle(fontSize: fs - 1),
          ),
        if (invoice.originalInvoiceNo != null)
          pw.Text('Ref ${invoice.originalInvoiceNo}', style: pw.TextStyle(fontSize: fs)),
        pw.Divider(),
        pw.Text(
          'ITEMS',
          style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
        ),
        ...invoice.lines.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _fit(line.itemName, narrow: narrow),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fs),
                ),
                if (line.variant.isNotEmpty)
                  pw.Text(line.variant, style: pw.TextStyle(fontSize: fs - 1)),
                pw.Text(
                  '${line.quantity.toStringAsFixed(0)} ${line.billingUnit.name} x ${moneyFixed(line.unitPrice)}',
                  style: pw.TextStyle(fontSize: fs - 1),
                ),
                if (b2b)
                  pw.Text(
                    'Net ${moneyFixed(line.taxable)}  VAT ${moneyFixed(line.tax)}  Gross ${moneyFixed(line.lineTotal)}',
                    style: pw.TextStyle(fontSize: fs - 1),
                  )
                else
                  pw.Text(
                    'VAT ${moneyFixed(line.tax)}  Incl. ${moneyFixed(line.lineTotal)}',
                    style: pw.TextStyle(fontSize: fs - 1),
                  ),
              ],
            ),
          ),
        ),
        pw.Divider(),
        _totals(invoice, narrow: narrow),
        pw.SizedBox(height: 6),
        pw.Center(child: _qr(invoice, size: narrow ? 46 : 60)),
        pw.SizedBox(height: 3),
        pw.Text(
          'ZATCA QR',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs - 1),
        ),
        pw.Text(
          'VAT ${invoice.taxPercent.toStringAsFixed(0)}% | Bluetooth ${settings.paper.label}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs - 1, fontWeight: pw.FontWeight.bold),
        ),
        if (settings.options.showFooter)
          pw.Text(footer, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
        if (settings.options.showTerms && settings.options.termsText.isNotEmpty)
          pw.Text(settings.options.termsText, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
        if (settings.printBankDetails && settings.bankPrintText.isNotEmpty)
          pw.Text(
            'Bank / IBAN\n${settings.bankPrintText}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fs - 1),
          ),
        if (_customerSig(invoice) != null) ...[
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Image(_customerSig(invoice)!, height: 32, fit: pw.BoxFit.contain)),
          pw.Text('Customer signature', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
        ],
    ];
  }

  pw.Widget _totals(Invoice invoice, {required bool narrow}) {
    final size = narrow ? 7.0 : 8.0;
    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontSize: size,
                ),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: size,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      children: [
        row('Subtotal', moneyFixed(invoice.subtotal)),
        row('Discount', moneyFixed(invoice.discount)),
        if (invoice.deliveryCharge > 0) row('Delivery', moneyFixed(invoice.deliveryCharge)),
        row('VAT ${invoice.taxPercent.toStringAsFixed(0)}% (ZATCA)', moneyFixed(invoice.taxTotal)),
        pw.Divider(),
        row('TOTAL', moneyFixed(invoice.grandTotal), bold: true),
        if (invoice.isCreditNote) ...[
          row('CREDIT', moneyFixed(invoice.grandTotal), bold: true),
          if (invoice.outstandingAfter != null)
            row("YOU'LL GET", moneyFixed(invoice.outstandingAfter!), bold: true),
        ] else ...[
          row('PAID', moneyFixed(invoice.amountPaid)),
          row('BALANCE', moneyFixed(invoice.balanceDue), bold: true),
        ],
      ],
    );
  }

  pw.MemoryImage? _customerSig(Invoice invoice) {
    if (invoice.customerSignature.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(invoice.customerSignature));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> buildPaymentReceipt({
    required LedgerPayment payment,
    required Customer customer,
    required ShopSettings settings,
    required double remainingDue,
  }) async {
    final doc = pw.Document();
    final narrow = settings.paper == PaperProfile.thermal58;
    final fs = narrow ? 8.0 : 9.0;
    doc.addPage(
      pw.Page(
        pageFormat: _thermalPage(settings),
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              _fit(settings.zatcaSellerName, narrow: narrow),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'PAYMENT RECEIVED RECEIPT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: fs + 1, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text('Date: ${isoStamp(payment.createdAt)}', style: pw.TextStyle(fontSize: fs)),
            pw.Text('Receipt: ${shortRef(payment.id)}', style: pw.TextStyle(fontSize: fs)),
            pw.Text('Customer: ${_fit(customer.display, narrow: narrow)}', style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold)),
            if (customer.phone.isNotEmpty) pw.Text(customer.phone, style: pw.TextStyle(fontSize: fs)),
            pw.SizedBox(height: 6),
            pw.Text(
              'Received amount: ${moneyFixed(payment.amount)} SAR',
              style: pw.TextStyle(fontSize: fs + 2, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Payment method: ${payment.method.toUpperCase()}',
              style: pw.TextStyle(fontSize: fs),
            ),
            pw.Text(
              'Remaining balance: ${moneyFixed(remainingDue)} SAR',
              style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
            ),
            if (payment.note.isNotEmpty) pw.Text('Ref: ${payment.note}', style: pw.TextStyle(fontSize: fs)),
            pw.Divider(),
            if (settings.printTrnCr) ...[
              pw.Text('TRN / VAT ${settings.vatTrn}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
              pw.Text('CR ${settings.crNumber}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
            ],
            if (settings.printBankDetails && settings.bankPrintText.isNotEmpty)
              pw.Text(settings.bankPrintText, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs - 1)),
            pw.SizedBox(height: 6),
            pw.Text('Thank you', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> printPaymentReceipt({
    required LedgerPayment payment,
    required Customer customer,
    required ShopSettings settings,
    required double remainingDue,
  }) {
    return Printing.layoutPdf(
      name: 'receipt-${payment.id}',
      format: thermalFormat(settings),
      usePrinterSettings: true,
      onLayout: (_) => buildPaymentReceipt(
        payment: payment,
        customer: customer,
        settings: settings,
        remainingDue: remainingDue,
      ),
    );
  }

  Future<void> sharePaymentReceipt({
    required LedgerPayment payment,
    required Customer customer,
    required ShopSettings settings,
    required double remainingDue,
  }) async {
    final bytes = await buildPaymentReceipt(
      payment: payment,
      customer: customer,
      settings: settings,
      remainingDue: remainingDue,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'receipt-${payment.id}.pdf');
  }

  Future<Uint8List> buildCustomerLedger({
    required Customer customer,
    required List<CustomerLedgerEntry> rows,
    required double billed,
    required double paid,
    required double due,
    required ShopSettings settings,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(settings.zatcaSellerName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('CUSTOMER LEDGER STATEMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(customer.display),
          pw.Text('Phone ${customer.phone}'),
          pw.SizedBox(height: 8),
          pw.Text('Billed ${billed.toStringAsFixed(2)}  Paid ${paid.toStringAsFixed(2)}  Due ${due.toStringAsFixed(2)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Ref / Invoice', 'Bill', 'Paid', 'Method', 'Balance'],
            data: [
              for (final r in rows)
                [
                  invoiceDate.format(r.date),
                  r.invoiceNo,
                  r.billed.toStringAsFixed(2),
                  r.received.toStringAsFixed(2),
                  r.method.toUpperCase(),
                  r.balance.toStringAsFixed(2),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> shareCustomerLedger({
    required Customer customer,
    required List<CustomerLedgerEntry> rows,
    required double billed,
    required double paid,
    required double due,
    required ShopSettings settings,
  }) async {
    final bytes = await buildCustomerLedger(
      customer: customer,
      rows: rows,
      billed: billed,
      paid: paid,
      due: due,
      settings: settings,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'ledger-${customer.shopName}.pdf');
  }

  Future<void> shareDayClose({
    required DayCloseSnapshot snap,
    required ShopSettings settings,
    required String vanLabel,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(settings.zatcaSellerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('DAILY CLOSING / END OF DAY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(vanLabel),
            pw.Text(invoiceDate.format(DateTime.now())),
            pw.SizedBox(height: 12),
            pw.Text('Sales total ${snap.salesTotal.toStringAsFixed(2)}'),
            pw.Text('Cash sales ${moneyFixed(snap.cashSales)}'),
            pw.Text('Credit collections ${moneyFixed(snap.creditCollections)}'),
            pw.Text('Bank sales ${moneyFixed(snap.bankSales)}'),
            pw.Text('Cheque collected ${moneyFixed(snap.chequeCollected)}'),
            pw.Text('Credit sales ${moneyFixed(snap.creditSales)}'),
            pw.Text('Approved expenses ${moneyFixed(snap.expenses)}'),
            pw.Text(
              'Cash sales + credit collections - approved expenses = net handover',
            ),
            pw.Text('Van stock value ${snap.vanStockSell.toStringAsFixed(2)}'),
            pw.Text('Cash collected ${snap.cashCollected.toStringAsFixed(2)}'),
            pw.Text('NET DEPOSIT ${snap.netDeposit.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'day-close-$vanLabel.pdf');
  }
}
