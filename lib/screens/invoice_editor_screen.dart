import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/strings.dart';
import '../models/crm.dart';
import '../models/enums.dart';
import '../models/invoice.dart';
import '../models/item.dart';
import '../models/shop_settings.dart';
import '../services/accounting_engine.dart';
import '../services/billing_repository.dart';
import '../services/map_customers.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_share.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/common.dart';
import '../widgets/customer_location_section.dart';
import '../widgets/signature_pad.dart';
import '../widgets/vyapar.dart';

class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({
    super.key,
    required this.controller,
    this.existing,
    this.creditFor,
    this.forCustomer,
    this.viewOnly = false,
  });

  final BillingController controller;
  final Invoice? existing;
  final Invoice? creditFor;
  final Customer? forCustomer;
  final bool viewOnly;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  late final TextEditingController customer;
  late final TextEditingController phone;
  late final TextEditingController trn;
  late final TextEditingController buyerCr;
  late final TextEditingController notes;
  late final TextEditingController discount;
  late final TextEditingController cashPaid;
  late final TextEditingController invoiceNoCtl;
  late final TextEditingController delivery;
  late final TextEditingController barcode;
  late final String invoiceId;
  late final DocType docType;
  late List<InvoiceLine> lines;
  Customer? selected;
  late final bool createdNew;
  String? error;
  String customerSig = '';
  String shopPhotoBase64 = '';
  double gpsLat = 0;
  double gpsLng = 0;
  String payMethod = 'cash';
  String paymentType = 'cash';
  late DateTime invoiceDate;
  late DateTime supplyDate;
  final FocusNode _customerFocus = FocusNode();
  bool _showPartyList = false;
  bool _applyingParty = false;
  bool receivedInFull = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final creditFor = widget.creditFor;
    createdNew = existing == null;
    docType = creditFor != null || existing?.docType == DocType.creditNote
        ? DocType.creditNote
        : DocType.taxInvoice;
    invoiceId = existing?.id ?? newId();
    final opt = widget.controller.settings.options;
    invoiceNoCtl = TextEditingController(
      text: existing?.invoiceNo ??
          nextDocNo(
            widget.controller.invoices,
            docType,
            prefix: opt.invoicePrefix,
            auto: true,
          ),
    );
    delivery = TextEditingController(text: existing?.deliveryCharge.toString() ?? '0');
    barcode = TextEditingController();
    customer = TextEditingController(
      text: existing?.customerName ?? creditFor?.customerName ?? '',
    );
    phone = TextEditingController(text: existing?.customerPhone ?? creditFor?.customerPhone ?? '');
    trn = TextEditingController(text: existing?.customerTrn ?? creditFor?.customerTrn ?? '');
    buyerCr = TextEditingController(text: existing?.buyerCr ?? creditFor?.buyerCr ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    discount = TextEditingController(text: existing?.discount.toString() ?? '0');
    cashPaid = TextEditingController(text: existing?.amountPaid.toString() ?? '0');
    lines = [...?existing?.lines];
    customerSig = existing?.customerSignature ?? '';
    shopPhotoBase64 = existing?.shopPhotoBase64 ?? '';
    gpsLat = existing?.gpsLat ?? 0;
    gpsLng = existing?.gpsLng ?? 0;
    payMethod = existing?.paymentMethod.isNotEmpty == true ? existing!.paymentMethod : 'cash';
    paymentType = existing?.paymentType.isNotEmpty == true
        ? existing!.paymentType
        : (payMethod == 'bank' || payMethod == 'cheque' ? payMethod : 'cash');
    invoiceDate = existing?.createdAt ?? DateTime.now();
    supplyDate = existing?.supplyDate ?? existing?.createdAt ?? DateTime.now();
    receivedInFull = existing == null
        ? payMethod != 'credit'
        : payMethod != 'credit' && existing.amountPaid >= existing.grandTotal - 0.05;
    _customerFocus.addListener(_onCustomerFocusChange);
    if (widget.forCustomer != null) {
      selected = widget.forCustomer;
      customer.text = selected!.name;
      phone.text = selected!.phone;
      trn.text = selected!.vatNumber;
      buyerCr.text = selected!.crNumber;
    } else if (existing?.customerId != null) {
      selected = widget.controller.customerById(existing!.customerId);
    }
    if (selected == null) {
      final named = (existing?.customerName ?? creditFor?.customerName ?? '').trim().toLowerCase();
      if (named.isNotEmpty) {
        for (final c in widget.controller.customers) {
          if (c.name.toLowerCase() == named || c.display.toLowerCase() == named) {
            selected = c;
            customer.text = c.name;
            break;
          }
        }
      }
    }
    if (creditFor != null && lines.isEmpty) {
      lines = creditFor.lines
          .map(
            (line) => InvoiceLine(
              id: newId(),
              itemId: line.itemId,
              itemName: line.itemName,
              sku: line.sku,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              taxRate: widget.controller.settings.options.effectiveVat,
              billingUnit: line.billingUnit,
              pieces: line.stockPieces,
              variant: line.variant,
              unitCost: line.unitCost,
              taxInclusive: line.taxInclusive,
            ),
          )
          .toList();
    }
    if (receivedInFull && payMethod != 'credit') {
      cashPaid.text = draft.grandTotal.toStringAsFixed(2);
    }
  }

  bool get officeSale => widget.controller.isAdmin || widget.controller.isPartner;

  StockLocation get location {
    final posted = widget.existing?.location ?? widget.creditFor?.location;
    if (posted != null) return posted;
    if (officeSale) return StockLocation.warehouse;
    return widget.controller.session?.sellingLocation ?? StockLocation.van1;
  }

  void _syncReceived(double grand) {
    if (receivedInFull && payMethod != 'credit') {
      cashPaid.text = grand.toStringAsFixed(2);
    }
  }

  Invoice get draft {
    final settings = widget.controller.settings;
    final built = Invoice(
      id: invoiceId,
      invoiceNo: invoiceNoCtl.text.trim().isEmpty ? 'INV-DRAFT' : invoiceNoCtl.text.trim(),
      docType: docType,
      customerName: selected?.name ?? '',
      customerPhone: selected?.phone ?? phone.text.trim(),
      customerTrn: selected?.vatNumber ?? trn.text.trim(),
      notes: notes.text.trim(),
      discount: settings.options.billDiscount ? moneyRound(double.tryParse(discount.text) ?? 0) : 0,
      status: payMethod == 'credit' ? 'due' : 'paid',
      lines: [
        for (final line in lines) line.copyWith(taxRate: settings.options.effectiveVat),
      ],
      location: location,
      sellerName: settings.zatcaSellerName,
      vatTrn: settings.vatTrn,
      crNumber: settings.crNumber,
      zatcaQr: widget.existing?.zatcaQr ?? '',
      originalInvoiceId: widget.creditFor?.id ?? widget.existing?.originalInvoiceId,
      originalInvoiceNo: widget.creditFor?.invoiceNo ?? widget.existing?.originalInvoiceNo,
      submitted: widget.existing?.submitted ?? false,
      createdBy: widget.controller.session?.label ?? '',
      createdAt: invoiceDate,
      customerId: selected?.id,
      amountPaid: 0,
      shopName: selected?.shopName ?? '',
      uuid: widget.existing?.uuid.isNotEmpty == true ? widget.existing!.uuid : invoiceId,
      icv: widget.existing?.icv ?? 0,
      pih: widget.existing?.pih ?? '',
      invoiceHash: widget.existing?.invoiceHash ?? '',
      buyerCr: selected?.crNumber.isNotEmpty == true ? selected!.crNumber : buyerCr.text.trim(),
      taxPercent: settings.options.effectiveVat,
      taxInclusive: () {
        final priced = lines.where((l) => l.unitPrice > 0);
        if (priced.isEmpty) return settings.options.priceInclusive;
        return priced.every((l) => l.taxInclusive);
      }(),
      deliveryCharge: settings.options.deliveryCharges ? moneyRound(double.tryParse(delivery.text) ?? 0) : 0,
      roundOff: settings.options.roundOff,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      customerSignature: customerSig,
      shopPhotoBase64: shopPhotoBase64,
      printCount: widget.existing?.printCount ?? 0,
      paymentMethod: payMethod,
      paymentType: paymentType,
      supplyDate: supplyDate,
    );
    final entered = moneyRound(double.tryParse(cashPaid.text) ?? 0);
    final cap = built.grandTotal;
    final paid = moneyRound(entered.clamp(0, cap).toDouble());
    final settled = paid + 0.001 >= cap;
    return built.copyWith(
      amountPaid: paid,
      status: settled ? 'paid' : 'due',
    );
  }

  bool get locked =>
      widget.viewOnly ||
      widget.controller.isPartner ||
      (widget.existing != null &&
          widget.existing!.submitted &&
          !widget.controller.canEditPostedInvoices);

  @override
  void dispose() {
    customer.dispose();
    phone.dispose();
    trn.dispose();
    buyerCr.dispose();
    notes.dispose();
    discount.dispose();
    cashPaid.dispose();
    invoiceNoCtl.dispose();
    delivery.dispose();
    barcode.dispose();
    _customerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildEditor(context),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final s = widget.controller.s;
    final invoice = draft;
    final digest = ZatcaQr.digestOf(
      uuid: invoice.uuid.isEmpty ? invoice.id : invoice.uuid,
      invoiceNo: invoice.invoiceNo,
      icv: invoice.icv > 0 ? invoice.icv : widget.controller.invoices.where((i) => i.submitted).length + 1,
      pih: invoice.pih.isEmpty ? zatcaZeroPih : invoice.pih,
      totalWithVat: invoice.grandTotal,
      vatAmount: invoice.taxTotal,
      timestamp: invoice.createdAt,
    );
    final qrPreview = invoice.zatcaQr.isEmpty
        ? ZatcaQr.encode(
            sellerName: widget.controller.settings.zatcaSellerName,
            vatNumber: widget.controller.settings.vatTrn,
            timestamp: invoice.createdAt,
            totalWithVat: invoice.grandTotal,
            vatAmount: invoice.taxTotal,
            invoiceHash: digest.bytes,
          )
        : invoice.zatcaQr;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(
          docType == DocType.creditNote
              ? s.t('Credit Note', 'إشعار دائن')
              : s.t('Add Sale', 'إضافة بيع'),
        ),
        actions: [
          if (docType == DocType.taxInvoice)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: _cashCreditToggle(locked)),
            ),
          LocaleToggleButton(widget.controller),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text(
            '${location.label} · TRN ${widget.controller.settings.vatTrn}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.t(
                  'Posted documents are locked for salesmen.',
                  'المستندات المرحلة مقفلة على حساب المندوب.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          UkCard(
            child: Column(
              children: [
                TextField(
                  controller: customer,
                  focusNode: _customerFocus,
                  enabled: !locked,
                  onTap: locked
                      ? null
                      : () => setState(() => _showPartyList = true),
                  decoration: InputDecoration(
                    labelText: s.t('Customer *', 'العميل *'),
                    hintText: s.t('Search party name or phone', 'ابحث بالاسم أو الجوال'),
                    suffixIcon: locked
                        ? null
                        : IconButton(
                            tooltip: s.t('New party', 'طرف جديد'),
                            onPressed: _openNewParty,
                            icon: const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.accent),
                          ),
                  ),
                  onChanged: (value) {
                    if (_applyingParty) return;
                    setState(() {
                      _showPartyList = true;
                      if (selected != null &&
                          value.trim().toLowerCase() != selected!.name.trim().toLowerCase() &&
                          value.trim().toLowerCase() != selected!.display.trim().toLowerCase()) {
                        selected = null;
                      }
                    });
                  },
                ),
                if (!locked && _showPartyList) _partySuggestions(s),
                if (!locked) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phone,
                          enabled: !locked,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: s.t('Phone', 'الجوال')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: trn,
                          enabled: !locked,
                          decoration: InputDecoration(labelText: s.t('VAT / TRN', 'الرقم الضريبي')),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: invoiceNoCtl,
                        enabled: !locked && !widget.controller.settings.options.autoInvoiceNo,
                        decoration: InputDecoration(labelText: s.t('Invoice no', 'رقم الفاتورة')),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateBox(
                        label: s.t('Invoice date', 'تاريخ الفاتورة'),
                        value: invoiceDate,
                        enabled: !locked,
                        onPick: (d) => setState(() => invoiceDate = d),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.controller.settings.options.showOutstandingOnBill && selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.t(
                  'Outstanding: ${sar.format(widget.controller.customerDue(selected!.id))}',
                  'المستحق: ${sar.format(widget.controller.customerDue(selected!.id))}',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
            ),
          if ((widget.controller.settings.options.posMode || widget.controller.settings.options.barcodeEnabled) && !locked) ...[
            const SizedBox(height: 8),
            TextField(
              controller: barcode,
              decoration: InputDecoration(
                labelText: s.t('Scan / enter product code', 'أدخل رمز المنتج'),
                suffixIcon: const Icon(Icons.qr_code_scanner),
              ),
              onSubmitted: (sku) async {
                final match = widget.controller.items.where((i) => i.sku.toLowerCase() == sku.trim().toLowerCase());
                if (match.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Product code not found', 'رمز المنتج غير موجود'))));
                  return;
                }
                final item = match.first;
                final available = widget.controller.stockAt(location, item.id).quantity;
                final already = lines.where((l) => l.itemId == item.id).fold<double>(0, (sum, l) => sum + l.stockPieces);
                final place = officeSale ? s.t('warehouse', 'المستودع') : s.t('van', 'الفان');
                if (docType == DocType.taxInvoice && already + 1 > available + 0.001) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(s.t('Cannot sell', 'تعذر البيع')),
                      content: Text(
                        available <= 0.001
                            ? s.t('${item.name}: $place stock is 0.', '${item.name}: مخزون $place صفر.')
                            : s.t(
                                '${item.name}: $place has ${available.toStringAsFixed(0)} pcs.',
                                '${item.name}: في $place ${available.toStringAsFixed(0)} قطعة.',
                              ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('OK', 'حسناً'))),
                      ],
                    ),
                  );
                  return;
                }
                barcode.clear();
                setState(() {
                  lines = [
                    ...lines,
                    InvoiceLine(
                      id: newId(),
                      itemId: item.id,
                      itemName: item.name,
                      sku: item.sku,
                      quantity: 1,
                      unitPrice: item.saleRateFor(BillingUnit.piece),
                      taxRate: widget.controller.settings.options.effectiveVat,
                      pieces: 1,
                      variant: item.variantLabel,
                      unitCost: moneyRound(item.cogsPerPiece),
                      taxInclusive: widget.controller.settings.options.priceInclusive,
                    ),
                  ];
                });
              },
            ),
          ],
          if (selected != null && selected!.creditLimit > 0) ...[
            const SizedBox(height: 8),
            Text(
              widget.controller.remainingCreditLabel(selected!, extra: draft.grandTotal - draft.amountPaid),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: locked
                ? null
                : () async {
                    final sig = await SignaturePadDialog.capture(context);
                    if (sig != null) setState(() => customerSig = sig);
                  },
            icon: const Icon(Icons.draw_outlined),
            label: Text(
              customerSig.isEmpty
                  ? s.t('Customer signature', 'توقيع العميل')
                  : s.t('Signature captured', 'تم حفظ التوقيع'),
            ),
          ),
          const SizedBox(height: 8),
          _shopPhoto(locked),
          const SizedBox(height: 16),
          if (lines.isEmpty)
            EmptyHint(icon: Icons.add_shopping_cart, message: s.t('Tap + to add items to this sale.', 'اضغط + لإضافة أصناف للبيع.'))
          else
            ...lines.asMap().entries.map((entry) {
              final line = entry.value;
              return UkCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.itemName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            '${line.quantity.toStringAsFixed(0)} ${line.billingUnit.shortLabel} = ${line.stockPieces.toStringAsFixed(0)} ${s.t('Pcs', 'قطعة')} · ${sar.format(line.unitPrice)} · ${line.taxInclusive ? s.t('With Tax', 'شامل الضريبة') : s.t('Without Tax', 'غير شامل')}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${s.t('Subtotal', 'المجموع')} ${sar.format(line.taxable)} · ${s.vat} ${sar.format(line.tax)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      sar.format(line.lineTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (!locked)
                      IconButton(
                        onPressed: () => setState(() {
                          lines.removeAt(entry.key);
                          if (receivedInFull && payMethod != 'credit') {
                            cashPaid.text = draft.grandTotal.toStringAsFixed(2);
                          }
                        }),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              );
            }),
          if (!locked) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.fabRed,
                foregroundColor: Colors.white,
              ),
              onPressed: _pickItem,
              icon: const Icon(Icons.add),
              label: Text(s.t('+ Add Items to Sale', '+ إضافة أصناف للبيع')),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.controller.settings.options.billDiscount) ...[
            TextField(
              controller: discount,
              enabled: !locked,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.t('Discount (excl. VAT)', 'الخصم بدون ضريبة')),
              onChanged: (_) {
                _syncReceived(draft.grandTotal);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
          if (widget.controller.settings.options.deliveryCharges) ...[
            TextField(
              controller: delivery,
              enabled: !locked,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.t('Delivery / packaging', 'توصيل / تغليف')),
              onChanged: (_) {
                _syncReceived(draft.grandTotal);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
          if (docType == DocType.taxInvoice)
            UkCard(
              child: Column(
                children: [
                  _kv(s.t('Subtotal', 'المجموع'), invoice.taxableNet),
                  _kv(s.t('VAT 15%', 'ضريبة 15%'), invoice.taxTotal),
                  _kv(s.t('Grand Total', 'الإجمالي'), invoice.grandTotal, bold: true),
                  const Divider(height: 16),
                  TextField(
                    controller: cashPaid,
                    enabled: !locked,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.t('Amount Received', 'المبلغ المستلم'),
                    ),
                    onChanged: (value) {
                      final typed = double.tryParse(value) ?? 0;
                      if ((typed - invoice.grandTotal).abs() > 0.05) {
                        receivedInFull = false;
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _kv(s.t('Change', 'الباقي'), _moneyGap(cashPaid.text, invoice.grandTotal, change: true)),
                  _kv(
                    s.t('Balance Due', 'المتبقي'),
                    _moneyGap(cashPaid.text, invoice.grandTotal, change: false),
                    bold: true,
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: notes,
              enabled: !locked,
              decoration: InputDecoration(labelText: s.t('Description', 'الوصف')),
            ),
          const SizedBox(height: 12),
          if (docType == DocType.taxInvoice)
          UkCard(
            child: Column(
              children: [
                _dateBox(
                  label: s.t('Date of supply', 'تاريخ التوريد'),
                  value: supplyDate,
                  enabled: !locked,
                  onPick: (d) => setState(() => supplyDate = d),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentType == 'cheque' || paymentType == 'bank' || paymentType == 'cash'
                      ? paymentType
                      : 'cash',
                  decoration: InputDecoration(labelText: s.t('Payment type', 'نوع الدفع')),
                  items: [
                    DropdownMenuItem(value: 'cash', child: Text(s.t('Cash', 'كاش'))),
                    DropdownMenuItem(value: 'bank', child: Text(s.t('Bank', 'بنك'))),
                    DropdownMenuItem(value: 'cheque', child: Text(s.t('Cheque', 'شيك'))),
                  ],
                  onChanged: locked
                      ? null
                      : (v) => setState(() {
                            paymentType = v ?? 'cash';
                            if (payMethod != 'credit') {
                              payMethod = paymentType == 'cash' ? 'cash' : 'bank';
                            }
                          }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  enabled: !locked,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.t('Description', 'الوصف')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: qrPreview,
              size: 148,
              backgroundColor: Colors.white,
            ),
          ),
          const Center(child: Text('ZATCA TLV QR')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ICV: ${invoice.icv > 0 ? invoice.icv : widget.controller.invoices.where((i) => i.submitted).length + 1}'),
                  Text('UUID: ${invoice.uuid.isEmpty ? invoice.id : invoice.uuid}'),
                  Text(
                    'PIH: ${(invoice.pih.isEmpty ? zatcaZeroPih : invoice.pih).substring(0, 16)}…',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          if (lines.isNotEmpty) ...[
            Text(
              s.t(
                'Pair a 58mm or 80mm Bluetooth thermal printer, then print. The system picker lists Bluetooth printers.',
                'اربط طابعة حرارية بلوتوث 58 أو 80مم ثم اطبع. تظهر طابعات البلوتوث في قائمة النظام.',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => const PdfService().printThermal(
                      invoice.copyWith(zatcaQr: qrPreview),
                      widget.controller.settings.copyWith(paper: PaperProfile.thermal58),
                    ),
                    child: Text(s.t('Print 58mm', 'طباعة 58مم'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => const PdfService().printThermal(
                      invoice.copyWith(zatcaQr: qrPreview),
                      widget.controller.settings.copyWith(paper: PaperProfile.thermal80),
                    ),
                    child: Text(s.t('Print 80mm', 'طباعة 80مم'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: () => const PdfService().shareA4(
                  invoice.copyWith(zatcaQr: qrPreview),
                  widget.controller.settings,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  s.t('Download PDF', 'تحميل PDF'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => const WhatsAppShare().zatcaBill(
                  invoice: invoice.copyWith(zatcaQr: qrPreview),
                  settings: widget.controller.settings,
                  arabic: s.isAr,
                ),
                icon: const Icon(Icons.chat),
                label: Text(
                  s.t('Share via WhatsApp', 'مشاركة واتساب'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!locked)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.fabRed,
                foregroundColor: Colors.white,
              ),
              onPressed: lines.isEmpty || selected == null ? null : _save,
              icon: const Icon(Icons.lock_outline),
              label: Text(
                docType == DocType.creditNote
                    ? s.t('Issue credit note & restore stock', 'إصدار إشعار دائن وإعادة المخزون')
                    : officeSale
                        ? s.t('Submit bill & deduct warehouse stock', 'اعتماد الفاتورة وخصم مخزون المستودع')
                        : s.t('Submit bill & deduct van stock', 'اعتماد الفاتورة وخصم مخزون الفان'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _partySuggestions(dynamic s) {
    final matches = _matchingParties();
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: false,
      descendantsAreTraversable: false,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.controller.s.t('Parties', 'الأطراف'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openNewParty,
                    icon: const Icon(Icons.add, size: 18, color: AppTheme.accent),
                    label: Text(
                      widget.controller.s.t('+ New Party', '+ طرف جديد'),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        widget.controller.s.t('No matching party. Tap + New Party.', 'لا يوجد طرف مطابق. اضغط + طرف جديد.'),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      primary: false,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final party = matches[index];
                        final due = widget.controller.customerDue(party.id);
                        final title = party.name.isEmpty ? party.display : party.name;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectParty(party),
                            onTapDown: (_) => _selectParty(party),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${party.phone.isEmpty ? '—' : party.phone}'
                                          '${party.vatNumber.isEmpty ? '' : '  ·  ${party.vatNumber}'}'
                                          '  ·  ${widget.controller.s.t('Balance', 'الرصيد')} ${sar.format(due)}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (due > 0.05)
                                    Text(
                                      sar.format(due),
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFC62828)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Customer> _matchingParties() {
    final q = customer.text.trim().toLowerCase();
    final all = widget.controller.customers;
    if (q.isEmpty) return all.take(12).toList();
    return all
        .where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.shopName.toLowerCase().contains(q) ||
              c.display.toLowerCase().contains(q) ||
              c.phone.contains(q);
        })
        .take(12)
        .toList();
  }

  void _onCustomerFocusChange() {
    if (!mounted || _applyingParty) return;
    if (_customerFocus.hasFocus && !locked) {
      setState(() => _showPartyList = true);
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || _applyingParty || _customerFocus.hasFocus) return;
      setState(() => _showPartyList = false);
    });
  }

  void _selectParty(Customer party) {
    _applyingParty = true;
    selected = party;
    customer.text = party.name.isNotEmpty ? party.name : party.display;
    phone.text = party.phone;
    trn.text = party.vatNumber;
    buyerCr.text = party.crNumber;
    _showPartyList = false;
    if (mounted) setState(() {});
    _customerFocus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyingParty = false;
    });
  }

  Future<void> _openNewParty() async {
    if (locked) return;
    _customerFocus.unfocus();
    final created = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _NewPartySheet(
          billing: widget.controller,
          initialName: customer.text.trim(),
        ),
      ),
    );
    await waitForOverlaySettle();
    if (!mounted || created == null) return;
    _selectParty(created);
  }

  double _moneyGap(String typed, double grand, {required bool change}) {
    final entered = moneyRound(double.tryParse(typed) ?? 0);
    if (change) return entered > grand ? moneyRound(entered - grand) : 0;
    return entered >= grand - 0.001 ? 0 : moneyRound(grand - entered);
  }

  Widget _kv(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            sar.format(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: bold ? 16 : 14,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopPhoto(bool locked) {
    final s = widget.controller.s;
    Uint8List? bytes;
    if (shopPhotoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(shopPhotoBase64);
      } catch (_) {
        bytes = null;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('Shop photo', 'صورة المحل'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, height: 140, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked ? null : () => _captureShopPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(s.t('Capture', 'التقاط')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked ? null : () => _captureShopPhoto(ImageSource.gallery),
                icon: const Icon(Icons.upload_outlined),
                label: Text(s.t('Upload', 'رفع')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _captureShopPhoto(ImageSource source) async {
    final s = widget.controller.s;
    try {
      final file = await _pickShopPhoto(source);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('That photo was empty. Try another.', 'الصورة فارغة. جرّب غيرها.'))),
        );
        return;
      }
      if (bytes.length > 900000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('Photo is too large. Take a smaller one.', 'الصورة كبيرة جداً. التقط صورة أصغر.'))),
        );
        return;
      }
      setState(() => shopPhotoBase64 = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'Camera or files are blocked. Allow camera access, or use Upload.',
              'الكاميرا أو الملفات محظورة. اسمح بالكاميرا أو استخدم الرفع.',
            ),
          ),
        ),
      );
    }
  }

  Future<XFile?> _pickShopPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 60,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (source != ImageSource.camera) rethrow;
      if (kIsWeb) {
        return picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          imageQuality: 60,
          requestFullMetadata: false,
        );
      }
      rethrow;
    }
  }

  Widget _cashCreditToggle(bool disabled) {
    final s = widget.controller.s;
    final credit = payMethod == 'credit';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniTab(s.t('Cash', 'كاش'), !credit, disabled
              ? null
              : () => setState(() {
                    payMethod = paymentType == 'bank' || paymentType == 'cheque' ? 'bank' : 'cash';
                    receivedInFull = true;
                    cashPaid.text = moneyFixed(draft.grandTotal);
                  })),
          _miniTab(s.t('Credit', 'آجل'), credit, disabled
              ? null
              : () => setState(() {
                    final full = draft.grandTotal;
                    final typed = moneyRound(double.tryParse(cashPaid.text) ?? 0);
                    payMethod = 'credit';
                    receivedInFull = false;
                    if (typed <= 0 || typed >= full - 0.05) cashPaid.text = '0';
                  })),
        ],
      ),
    );
  }

  Widget _miniTab(String label, bool selected, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? Colors.white : AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime value,
    required bool enabled,
    required ValueChanged<DateTime> onPick,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: InkWell(
        onTap: !enabled
            ? null
            : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (picked != null) onPick(picked);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            DateFormat('dd MMM yyyy').format(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Future<void> _pickItem([CatalogItem? preset]) async {
    final billing = widget.controller;
    if (billing.items.isEmpty) return;
    final result = await showModalBottomSheet<_SaleLineDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: _AddSaleItemSheet(
            billing: billing,
            location: location,
            requireVanStock: docType == DocType.taxInvoice && !officeSale,
            checkStock: docType == DocType.taxInvoice,
            officeSale: officeSale,
            reserved: {
              for (final line in lines)
                if (line.itemId != null)
                  line.itemId!: lines
                      .where((row) => row.itemId == line.itemId)
                      .fold<double>(0, (sum, row) => sum + row.stockPieces),
            },
            defaultInclusive: billing.settings.options.priceInclusive,
            preset: preset,
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    final item = result.item;
    final qty = result.qty;
    final unit = result.unit;
    final pieces = moneyRound(qty * unit.piecesEach(item.cartonSize));
    final promo = widget.controller.matchingPromo(pieces);
    final unitPrice = moneyRound(promo == null ? result.rate : result.rate * (1 - promo.discountPct / 100));
    setState(() {
      lines = [
        ...lines,
        InvoiceLine(
          id: newId(),
          itemId: item.id,
          itemName: item.name,
          sku: item.sku,
          quantity: qty,
          unitPrice: unitPrice,
          taxRate: billing.settings.options.effectiveVat,
          billingUnit: unit,
          pieces: pieces,
          variant: promo == null ? item.variantLabel : '${item.variantLabel} · ${promo.name}',
          lineDiscount: result.discount,
          unitCost: moneyRound(item.cogsPerPiece),
          taxInclusive: result.taxInclusive,
        ),
        if (promo != null && promo.sampleQty > 0)
          InvoiceLine(
            id: newId(),
            itemId: item.id,
            itemName: '${item.name} sample',
            sku: item.sku,
            quantity: promo.sampleQty,
            unitPrice: 0,
            taxRate: 0,
            billingUnit: BillingUnit.piece,
            pieces: promo.sampleQty,
            variant: 'SAMPLE',
            unitCost: moneyRound(item.cogsPerPiece),
          ),
      ];
      if (receivedInFull && payMethod != 'credit') {
        cashPaid.text = draft.grandTotal.toStringAsFixed(2);
      }
    });
  }

  Future<void> _save() async {
    try {
      try {
        final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 4));
        gpsLat = pos.latitude;
        gpsLng = pos.longitude;
      } catch (_) {}
      if (!mounted) return;
      if (selected != null && gpsLat.abs() < 0.01 && gpsLng.abs() < 0.01 && selected!.hasGps) {
        gpsLat = selected!.lat;
        gpsLng = selected!.lng;
      }
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.s.t(
                'Select a customer before saving the bill.',
                'اختر عميلاً قبل حفظ الفاتورة.',
              ),
            ),
          ),
        );
        _customerFocus.requestFocus();
        setState(() => _showPartyList = true);
        return;
      }
      if (customerSig.isEmpty && docType == DocType.taxInvoice && !locked) {
        final sig = await SignaturePadDialog.capture(context);
        if (sig != null) customerSig = sig;
      }
      final d = draft;
      if (selected != null &&
          selected!.creditLimit > 0 &&
          widget.controller.settings.options.enforceCreditLimit) {
        final projected = widget.controller.customerDue(selected!.id) + d.grandTotal - d.amountPaid;
        if (projected > selected!.creditLimit + 0.009) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.controller.s.t(
                  'Credit limit exceeded. Reduce credit, collect cash, or ask Admin to raise the limit.',
                  'تم تجاوز حد الائتمان. خفّض الآجل أو حصّل كاش أو اطلب من المدير رفع الحد.',
                ),
              ),
            ),
          );
          return;
        }
      }
      if (widget.existing != null && widget.controller.isAdmin) {
        await widget.controller.updateInvoice(d);
      } else {
        await widget.controller.submitInvoice(d);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted with ZATCA timestamp & QR')),
      );
      final stamped = widget.controller.invoices.firstWhere((i) => i.id == invoiceId, orElse: () => draft);
      final settings = widget.controller.settings;
      if (settings.autoPrint && settings.paper.isThermal) {
        await const PdfService().printThermal(stamped, settings);
        await widget.controller.markPrinted(stamped.id);
      }
      if (settings.options.autoWhatsApp) {
        await const WhatsAppShare().zatcaBill(
          invoice: stamped,
          settings: settings,
          arabic: widget.controller.s.isAr,
        );
      }
      if (mounted) popAfterFrame(context);
    } on RbacException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.controller.s.t('Cannot post invoice', 'تعذر اعتماد الفاتورة')),
          content: Text(e.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.controller.s.t('OK', 'حسناً'))),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _SaleLineDraft {
  const _SaleLineDraft({
    required this.item,
    required this.qty,
    required this.rate,
    required this.unit,
    required this.taxInclusive,
    required this.discount,
  });

  final CatalogItem item;
  final double qty;
  final double rate;
  final BillingUnit unit;
  final bool taxInclusive;
  final double discount;
}

class _AddSaleItemSheet extends StatefulWidget {
  const _AddSaleItemSheet({
    required this.billing,
    required this.location,
    required this.requireVanStock,
    required this.checkStock,
    required this.officeSale,
    required this.reserved,
    required this.defaultInclusive,
    this.preset,
  });

  final BillingController billing;
  final StockLocation location;
  final bool requireVanStock;
  final bool checkStock;
  final bool officeSale;
  final Map<String, double> reserved;
  final bool defaultInclusive;
  final CatalogItem? preset;

  @override
  State<_AddSaleItemSheet> createState() => _AddSaleItemSheetState();
}

class _AddSaleItemSheetState extends State<_AddSaleItemSheet> {
  late CatalogItem item;
  late BillingUnit unit;
  late bool taxInclusive;
  late final TextEditingController search;
  late final TextEditingController qty;
  late final TextEditingController rate;
  late final TextEditingController disc;
  String? stockError;
  double listRate = 0;

  BillingController get billing => widget.billing;

  @override
  void initState() {
    super.initState();
    item = widget.preset ?? billing.items.first;
    unit = BillingUnit.piece;
    taxInclusive = widget.defaultInclusive;
    search = TextEditingController(text: widget.preset?.name ?? '');
    qty = TextEditingController(text: '1');
    listRate = item.saleRateFor(unit);
    rate = TextEditingController(text: listRate.toStringAsFixed(2));
    disc = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    search.dispose();
    qty.dispose();
    rate.dispose();
    disc.dispose();
    super.dispose();
  }

  void _select(CatalogItem row) {
    setState(() {
      item = row;
      stockError = null;
      search.text = row.name;
      _applyListRate();
    });
  }

  void _applyListRate() {
    listRate = item.saleRateFor(unit);
    rate.text = listRate.toStringAsFixed(2);
  }

  void _commit(double q, double r, double d, double pieces) {
    if (widget.checkStock) {
      final available = billing.stockAt(widget.location, item.id).quantity;
      final held = widget.reserved[item.id] ?? 0;
      final sample = billing.matchingPromo(pieces)?.sampleQty ?? 0;
      final needed = moneyRound(pieces + sample);
      final left = moneyRound(available - held);
      if (needed > left + 0.001) {
        final s = billing.s;
        final place = widget.location == StockLocation.warehouse
            ? s.t('warehouse', 'المستودع')
            : s.t('van', 'الفان');
        setState(() {
          stockError = left <= 0.001
              ? s.t('${item.name}: $place stock is 0.', '${item.name}: مخزون $place صفر.')
              : s.t(
                  '${item.name}: $place has ${left.toStringAsFixed(0)} pcs left. This line needs ${needed.toStringAsFixed(0)}.',
                  '${item.name}: المتبقي في $place ${left.toStringAsFixed(0)} قطعة. المطلوب ${needed.toStringAsFixed(0)}.',
                );
        });
        return;
      }
    }
    final charged = r;
    final gap = moneyRound(listRate - charged);
    final autoOff = gap > 0.001 ? moneyRound(gap * q) : 0.0;
    final manual = billing.settings.options.itemDiscount ? d : 0.0;
    final off = autoOff > 0 ? autoOff : manual;
    final storedRate = autoOff > 0 ? listRate : charged;
    Navigator.pop(
      context,
      _SaleLineDraft(
        item: item,
        qty: q,
        rate: storedRate,
        unit: unit,
        taxInclusive: taxInclusive,
        discount: off,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = billing.s;
    final vatPct = billing.settings.options.effectiveVat;
    final q = double.tryParse(qty.text.trim()) ?? 0;
    final r = moneyRound(double.tryParse(rate.text.trim()) ?? 0);
    final d = moneyRound(double.tryParse(disc.text.trim()) ?? 0);
    final charged = r;
    final gap = moneyRound(listRate - charged);
    final autoOff = gap > 0.001 ? moneyRound(gap * q) : 0.0;
    final lineOff = autoOff > 0 ? autoOff : (billing.settings.options.itemDiscount ? d : 0.0);
    final baseRate = autoOff > 0 ? listRate : charged;
    final discountPct = listRate > 0 && gap > 0.001 ? moneyRound((gap / listRate) * 100) : 0.0;
    final split = AccountingEngine.splitEnteredRate(
      amount: moneyRound((baseRate * q) - lineOff),
      taxPercent: vatPct,
      inclusive: taxInclusive,
    );
    final onHand = billing.stockAt(widget.location, item.id).quantity;
    final held = widget.reserved[item.id] ?? 0;
    final available = moneyRound(onHand - held);
    final each = unit.piecesEach(item.cartonSize);
    final totalPcs = moneyRound(q * each);
    final warehouse = widget.location == StockLocation.warehouse;
    final stockLabel = warehouse
        ? s.t('Warehouse stock', 'مخزون المستودع')
        : s.t('Van stock', 'مخزون الفان');
    final blockEmpty = widget.requireVanStock && available <= 0.001;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Add Items to Sale', 'إضافة أصناف للبيع'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: s.t('Search product', 'بحث عن صنف'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            _ProductMatches(
              search: search,
              billing: billing,
              location: widget.location,
              selectedId: item.id,
              onPick: _select,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in BillingUnit.values)
                  ChoiceChip(
                    label: Text(_unitLabel(s, option)),
                    selected: unit == option,
                    onSelected: (_) => setState(() {
                      unit = option;
                      stockError = null;
                      _applyListRate();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '1 ${_unitLabel(s, unit)} = ${each.toStringAsFixed(0)} ${s.t('Pcs', 'قطعة')} · ${s.t('Line', 'السطر')} ${totalPcs.toStringAsFixed(0)} ${s.t('Pcs', 'قطعة')}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.t('Quantity', 'الكمية')),
                    onChanged: (_) => setState(() => stockError = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: rate,
                    readOnly: !billing.isAdmin,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.t('Rate', 'السعر'),
                      helperText: billing.isAdmin
                          ? null
                          : s.t('Catalog price is set by Admin.', 'سعر الكتالوج يحدده المدير.'),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<bool>(
              initialValue: taxInclusive,
              decoration: InputDecoration(labelText: s.t('Tax', 'الضريبة')),
              items: [
                DropdownMenuItem(
                  value: true,
                  child: Text(s.t('With Tax (inclusive)', 'شامل الضريبة')),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(s.t('Without Tax (exclusive)', 'غير شامل الضريبة')),
                ),
              ],
              onChanged: (v) => setState(() => taxInclusive = v ?? taxInclusive),
            ),
            if (billing.settings.options.itemDiscount) ...[
              const SizedBox(height: 10),
              TextField(
                controller: disc,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('Item discount (SAR)', 'خصم الصنف')),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${s.t('Discount', 'الخصم')} ${sar.format(lineOff)}  ·  ${discountPct.toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              '${s.t('Subtotal', 'المجموع')} ${sar.format(split.net)}  ·  ${s.vat} ${sar.format(split.tax)}  ·  ${s.t('Total', 'الإجمالي')} ${sar.format(split.gross)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              '$stockLabel ${available.toStringAsFixed(0)} ${s.t('pcs', 'قطعة')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (stockError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  stockError!,
                  style: const TextStyle(color: AppTheme.fabRed, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.fabRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: q <= 0 || blockEmpty
                    ? null
                    : () => _commit(q, r, d, totalPcs),
                child: Text(s.t('Add item', 'إضافة الصنف'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(S s, BillingUnit option) => switch (option) {
        BillingUnit.piece => s.t('Pcs', 'قطعة'),
        BillingUnit.dozen => s.t('Dozen', 'درزن'),
        BillingUnit.box => s.t('Box', 'علبة'),
        BillingUnit.carton => s.t('Carton', 'كرتون'),
      };
}

class _ProductMatches extends StatefulWidget {
  const _ProductMatches({
    required this.search,
    required this.billing,
    required this.location,
    required this.selectedId,
    required this.onPick,
  });

  final TextEditingController search;
  final BillingController billing;
  final StockLocation location;
  final String selectedId;
  final ValueChanged<CatalogItem> onPick;

  @override
  State<_ProductMatches> createState() => _ProductMatchesState();
}

class _ProductMatchesState extends State<_ProductMatches> {
  int _queryGen = 0;

  @override
  void initState() {
    super.initState();
    widget.search.addListener(_schedule);
  }

  @override
  void didUpdateWidget(covariant _ProductMatches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      oldWidget.search.removeListener(_schedule);
      widget.search.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.search.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    final token = ++_queryGen;
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (!mounted || token != _queryGen) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.trim().toLowerCase();
    final matches = <CatalogItem>[];
    for (final row in widget.billing.items) {
      if (query.isNotEmpty) {
        final name = row.name.toLowerCase();
        final sku = row.sku.toLowerCase();
        if (!name.contains(query) && !sku.contains(query)) continue;
      }
      matches.add(row);
      if (matches.length == 8) break;
    }
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.billing.s.t('No matching products', 'لا توجد أصناف مطابقة'),
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    final s = widget.billing.s;
    final rows = (matches.length / 2).ceil();
    return SizedBox(
      height: rows * 96.0,
      child: GridView.builder(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 88,
        ),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final row = matches[index];
          final selected = row.id == widget.selectedId;
          final stock = widget.billing.stockAt(widget.location, row.id).quantity;
          return Material(
            color: selected ? const Color(0xFFE3F2FD) : Colors.white,
            elevation: selected ? 0 : 1,
            shadowColor: const Color(0x140F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: selected ? AppTheme.accent : const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onPick(row),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const Spacer(),
                    Text(
                      sar.format(row.sellingPrice),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${stock.toStringAsFixed(0)} ${s.t('pcs', 'قطعة')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewPartySheet extends StatefulWidget {
  const _NewPartySheet({required this.billing, this.initialName = ''});

  final BillingController billing;
  final String initialName;

  @override
  State<_NewPartySheet> createState() => _NewPartySheetState();
}

class _NewPartySheetState extends State<_NewPartySheet> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController cr;
  late final TextEditingController vat;
  late final TextEditingController opening;
  late final TextEditingController lat;
  late final TextEditingController lng;
  late final TextEditingController coordInput;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
    phone = TextEditingController();
    address = TextEditingController();
    cr = TextEditingController();
    vat = TextEditingController();
    opening = TextEditingController(text: '0');
    lat = TextEditingController();
    lng = TextEditingController();
    coordInput = TextEditingController();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    cr.dispose();
    vat.dispose();
    opening.dispose();
    lat.dispose();
    lng.dispose();
    coordInput.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final partyName = name.text.trim();
    if (partyName.isEmpty) {
      setState(() => error = widget.billing.s.t('Party name is required.', 'اسم الطرف مطلوب.'));
      return;
    }
    final parsed = resolveShopPoint(
      manual: coordInput.text,
      latText: lat.text,
      lngText: lng.text,
    );
    final party = Customer(
      id: newId(),
      name: partyName,
      phone: phone.text.trim(),
      shopName: partyName,
      crNumber: cr.text.trim(),
      vatNumber: vat.text.trim(),
      lat: parsed?.lat ?? double.tryParse(lat.text) ?? 0,
      lng: parsed?.lng ?? double.tryParse(lng.text) ?? 0,
      address: address.text.trim().isNotEmpty
          ? address.text.trim()
          : (parsed?.address ?? '').trim(),
      openingBalance: moneyRound(double.tryParse(opening.text) ?? 0),
    );
    await widget.billing.saveCustomer(party);
    if (!mounted) return;
    popAfterFrame(context, party);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.billing.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('New Party', 'طرف جديد'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: s.t('Customer Name (Required)', 'اسم العميل (مطلوب)')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: s.t('Mobile Number', 'رقم الجوال')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vat,
                    decoration: InputDecoration(labelText: s.t('VAT / TRN Number', 'الرقم الضريبي')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: cr,
                    decoration: InputDecoration(labelText: s.t('CR Number', 'السجل التجاري')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: InputDecoration(labelText: s.t('Billing address', 'عنوان الفاتورة')),
            ),
            CustomerLocationSection(
              lat: lat,
              lng: lng,
              coordInput: coordInput,
              address: address,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: opening,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.t('Opening balance (optional)', 'الرصيد الافتتاحي (اختياري)')),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: AppTheme.fabRed, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.fabRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: _save,
                child: Text(s.t('Save party', 'حفظ الطرف'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
