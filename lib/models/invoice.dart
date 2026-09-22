import '../models/enums.dart';
import '../services/accounting_engine.dart';
import '../utils/formatters.dart';

class InvoiceLine {
  InvoiceLine({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = vatRate,
    this.billingUnit = BillingUnit.piece,
    this.pieces = 0,
    this.variant = '',
    this.lineDiscount = 0,
    this.unitCost = 0,
    this.taxInclusive = false,
  });

  final String id;
  final String? itemId;
  final String itemName;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final BillingUnit billingUnit;
  final double pieces;
  final String variant;
  final double lineDiscount;
  /// Purchase cost per piece, snapshotted at sale time.
  final double unitCost;
  /// True = entered rate includes VAT (With Tax). False = exclusive (Without Tax).
  final bool taxInclusive;

  double get stockPieces => pieces > 0 ? pieces : quantity;

  double get enteredAmount {
    final gross = moneyRound(unitPrice * quantity);
    return moneyRound((gross - lineDiscount).clamp(0, double.infinity).toDouble());
  }

  ({double net, double tax, double gross}) get vatSplit =>
      AccountingEngine.splitEnteredRate(
        amount: enteredAmount,
        taxPercent: taxRate,
        inclusive: taxInclusive,
      );

  /// Exclusive net (subtotal contribution).
  double get taxable => vatSplit.net;
  double get tax => vatSplit.tax;
  double get lineTotal => vatSplit.gross;
  double get costAmount => moneyRound(unitCost * stockPieces);
  /// (Selling − purchase) × sold qty after line discount, excluding VAT.
  double get lineRealizedProfit => moneyRound(taxable - costAmount);

  InvoiceLine copyWith({
    double? taxRate,
    double? quantity,
    double? lineDiscount,
    double? unitCost,
    double? pieces,
    bool? taxInclusive,
  }) {
    return InvoiceLine(
      id: id,
      itemId: itemId,
      itemName: itemName,
      sku: sku,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      taxRate: taxRate ?? this.taxRate,
      billingUnit: billingUnit,
      pieces: pieces ?? this.pieces,
      variant: variant,
      lineDiscount: lineDiscount ?? this.lineDiscount,
      unitCost: unitCost ?? this.unitCost,
      taxInclusive: taxInclusive ?? this.taxInclusive,
    );
  }

  Map<String, dynamic> toJson({String? invoiceId}) => {
        'id': id,
        'invoice_id': ?invoiceId,
        'item_id': itemId,
        'item_name': itemName,
        'sku': sku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'line_total': lineTotal,
        'billing_unit': billingUnit.name,
        'pieces': stockPieces,
        'variant': variant,
        'line_discount': lineDiscount,
        'unit_cost': unitCost,
        'tax_inclusive': taxInclusive,
      };

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    final unit = BillingUnitX.parse(json['billing_unit']?.toString());
    return InvoiceLine(
      id: json['id'].toString(),
      itemId: json['item_id']?.toString(),
      itemName: (json['item_name'] ?? json['itemName'] ?? '').toString(),
      sku: json['sku']?.toString() ?? '',
      quantity: asDouble(json['quantity']),
      unitPrice: asDouble(json['unit_price'] ?? json['unitPrice']),
      taxRate: asDouble(json['tax_rate'] ?? json['taxRate'] ?? vatRate),
      billingUnit: unit,
      pieces: asDouble(json['pieces']),
      variant: json['variant']?.toString() ?? '',
      lineDiscount: asDouble(json['line_discount'] ?? json['lineDiscount']),
      unitCost: asDouble(json['unit_cost'] ?? json['unitCost']),
      taxInclusive: json['tax_inclusive'] == true || json['taxInclusive'] == true,
    );
  }
}

class Invoice {
  Invoice({
    required this.id,
    required this.invoiceNo,
    required this.docType,
    required this.customerName,
    required this.customerPhone,
    required this.customerTrn,
    required this.notes,
    required this.discount,
    required this.status,
    required this.lines,
    required this.location,
    required this.sellerName,
    required this.vatTrn,
    required this.crNumber,
    required this.zatcaQr,
    DateTime? createdAt,
    this.originalInvoiceId,
    this.originalInvoiceNo,
    this.submitted = true,
    this.createdBy = '',
    this.customerId,
    this.amountPaid = 0,
    this.shopName = '',
    this.uuid = '',
    this.icv = 0,
    this.pih = '',
    this.invoiceHash = '',
    this.buyerCr = '',
    this.taxPercent = vatRate,
    this.taxInclusive = false,
    this.deliveryCharge = 0,
    this.roundOff = false,
    this.gpsLat = 0,
    this.gpsLng = 0,
    this.customerSignature = '',
    this.shopPhotoBase64 = '',
    this.printCount = 0,
    this.returnKind = '',
    this.paymentMethod = 'cash',
    this.paymentType = 'cash',
    this.outstandingAfter,
    DateTime? supplyDate,
  }) : createdAt = createdAt ?? DateTime.now(),
       supplyDate = supplyDate ?? createdAt ?? DateTime.now();

  final String id;
  final String invoiceNo;
  final DocType docType;
  final String customerName;
  final String customerPhone;
  final String customerTrn;
  final String notes;
  final double discount;
  final String status;
  final List<InvoiceLine> lines;
  final DateTime createdAt;
  final StockLocation location;
  final String sellerName;
  final String vatTrn;
  final String crNumber;
  final String zatcaQr;
  final String? originalInvoiceId;
  final String? originalInvoiceNo;
  final bool submitted;
  final String createdBy;
  final String? customerId;
  final double amountPaid;
  final String shopName;
  /// ZATCA UUID (usually the invoice id).
  final String uuid;
  /// Invoice Counter Value (sequential).
  final int icv;
  /// Previous Invoice Hash (hex SHA-256).
  final String pih;
  /// This invoice's cryptographic hash (hex SHA-256).
  final String invoiceHash;
  /// Buyer commercial registration.
  final String buyerCr;
  final double taxPercent;
  final bool taxInclusive;
  final double deliveryCharge;
  final bool roundOff;
  final double gpsLat;
  final double gpsLng;
  final String customerSignature;
  /// Shop photo captured with this sale. Kept off the ZATCA QR payload.
  final String shopPhotoBase64;
  final int printCount;
  /// Credit note: `salable` restores van stock; `damaged` does not.
  final String returnKind;
  /// `cash`, `bank`, or `credit`.
  final String paymentMethod;
  /// Instrument: `cash`, `bank`, or `cheque`.
  final String paymentType;
  /// Customer "You'll Get" after this credit note is posted.
  final double? outstandingAfter;
  final DateTime supplyDate;

  String get buyerVat => customerTrn;

  String get resolvedPayMethod {
    if (isCreditNote) return 'credit';
    if (amountPaid <= 0.05) return 'credit';
    final instrument = paymentType.toLowerCase();
    if (instrument == 'cheque') return 'cheque';
    if (instrument == 'bank' || instrument == 'transfer') return 'bank';
    final m = paymentMethod.toLowerCase();
    if (m == 'cheque') return 'cheque';
    if (m == 'bank' || m == 'transfer') return 'bank';
    if (m == 'credit') return amountPaid > 0.05 ? 'cash' : 'credit';
    return 'cash';
  }

  bool get isCreditNote => docType == DocType.creditNote;

  double get balanceDue =>
      moneyRound((grandTotal - amountPaid).clamp(0, double.infinity).toDouble());

  bool get isDue => !isCreditNote && balanceDue > 0.05;

  /// Subtotal = Σ (qty × selling price − line discount).
  double get goodsTotal =>
      moneyRound(lines.fold(0.0, (sum, line) => sum + line.taxable));

  double get subtotal => goodsTotal;

  double get netAfterDiscount =>
      AccountingEngine.netAfterDiscount(goodsTotal, discount);

  /// Net, VAT, and payable after line math, bill discount, and delivery.
  ///
  /// Bill discount is exclusive of VAT (the sale screen label). It is shared
  /// across lines by their exclusive nets, then each line's own VAT rate is
  /// applied again so mixed rates are not flattened to one header percent.
  ({double net, double tax, double gross}) get priced {
    final lineNets = <int>[for (final line in lines) toHalalas(line.taxable)];
    var net = lineNets.fold(0, (sum, value) => sum + value);
    var tax = lines.fold(0, (sum, line) => sum + toHalalas(line.tax));
    final disc = discount <= 0 ? 0 : (toHalalas(discount) > net ? net : toHalalas(discount));
    if (disc > 0 && net > 0) {
      final shares = AccountingEngine.allocateDiscount(lineNets, disc);
      net = 0;
      tax = 0;
      for (var i = 0; i < lines.length; i++) {
        final base = lineNets[i] - shares[i];
        net += base;
        tax += AccountingEngine.vatExclusiveHalalas(base, lines[i].taxRate);
      }
    }
    if (deliveryCharge > 0.001) {
      final split = AccountingEngine.splitEnteredRate(
        amount: deliveryCharge,
        taxPercent: taxPercent,
        inclusive: taxInclusive,
      );
      net += toHalalas(split.net);
      tax += toHalalas(split.tax);
    }
    var gross = net + tax;
    if (roundOff) gross = roundDiv(gross, 100) * 100;
    return (net: fromHalalas(net), tax: fromHalalas(tax), gross: fromHalalas(gross));
  }

  /// Tax base after bill discount and delivery.
  double get taxableNet => priced.net;

  double get taxTotal => priced.tax;

  double get grandTotal => priced.gross;

  double get costOfGoodsSold =>
      moneyRound(lines.fold(0.0, (sum, line) => sum + line.costAmount));

  /// Realized goods profit excluding VAT. Credit notes reverse the sign.
  double get realizedProfit {
    final goods = AccountingEngine.realizedProfit(
      subtotal: goodsTotal,
      discount: discount,
      cogs: costOfGoodsSold,
    );
    return isCreditNote ? moneyRound(-goods) : goods;
  }

  Invoice copyWith({
    String? invoiceNo,
    String? customerName,
    String? customerPhone,
    String? customerTrn,
    String? notes,
    double? discount,
    String? status,
    List<InvoiceLine>? lines,
    String? sellerName,
    String? vatTrn,
    String? crNumber,
    String? zatcaQr,
    bool? submitted,
    String? customerId,
    double? amountPaid,
    String? shopName,
    String? uuid,
    int? icv,
    String? pih,
    String? invoiceHash,
    String? buyerCr,
    double? taxPercent,
    bool? taxInclusive,
    double? deliveryCharge,
    bool? roundOff,
    double? gpsLat,
    double? gpsLng,
    String? customerSignature,
    String? shopPhotoBase64,
    int? printCount,
    String? returnKind,
    String? paymentMethod,
    String? paymentType,
    double? outstandingAfter,
    DateTime? createdAt,
    DateTime? supplyDate,
  }) {
    return Invoice(
      id: id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      docType: docType,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerTrn: customerTrn ?? this.customerTrn,
      notes: notes ?? this.notes,
      discount: discount ?? this.discount,
      status: status ?? this.status,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
      location: location,
      sellerName: sellerName ?? this.sellerName,
      vatTrn: vatTrn ?? this.vatTrn,
      crNumber: crNumber ?? this.crNumber,
      zatcaQr: zatcaQr ?? this.zatcaQr,
      originalInvoiceId: originalInvoiceId,
      originalInvoiceNo: originalInvoiceNo,
      submitted: submitted ?? this.submitted,
      createdBy: createdBy,
      customerId: customerId ?? this.customerId,
      amountPaid: amountPaid ?? this.amountPaid,
      shopName: shopName ?? this.shopName,
      uuid: uuid ?? this.uuid,
      icv: icv ?? this.icv,
      pih: pih ?? this.pih,
      invoiceHash: invoiceHash ?? this.invoiceHash,
      buyerCr: buyerCr ?? this.buyerCr,
      taxPercent: taxPercent ?? this.taxPercent,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      roundOff: roundOff ?? this.roundOff,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      customerSignature: customerSignature ?? this.customerSignature,
      shopPhotoBase64: shopPhotoBase64 ?? this.shopPhotoBase64,
      printCount: printCount ?? this.printCount,
      returnKind: returnKind ?? this.returnKind,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentType: paymentType ?? this.paymentType,
      outstandingAfter: outstandingAfter ?? this.outstandingAfter,
      supplyDate: supplyDate ?? this.supplyDate,
    );
  }

  Map<String, dynamic> toHeaderJson() => {
        'id': id,
        'invoice_no': invoiceNo,
        'doc_type': docType.name,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_trn': customerTrn,
        'notes': notes,
        'subtotal': taxableNet,
        'tax_total': taxTotal,
        'discount': discount,
        'grand_total': grandTotal,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'location': location.name,
        'seller_name': sellerName,
        'vat_trn': vatTrn,
        'cr_number': crNumber,
        'zatca_qr': zatcaQr,
        'original_invoice_id': originalInvoiceId,
        'original_invoice_no': originalInvoiceNo,
        'submitted': submitted,
        'created_by': createdBy,
        'customer_id': customerId,
        'amount_paid': amountPaid,
        'shop_name': shopName,
        'uuid': uuid.isEmpty ? id : uuid,
        'icv': icv,
        'pih': pih,
        'invoice_hash': invoiceHash,
        'buyer_cr': buyerCr,
        'buyer_vat': customerTrn,
        'tax_percent': taxPercent,
        'tax_inclusive': taxInclusive,
        'delivery_charge': deliveryCharge,
        'round_off': roundOff,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'customer_signature': customerSignature,
        if (shopPhotoBase64.isNotEmpty) 'shop_photo': shopPhotoBase64,
        'print_count': printCount,
        'return_kind': returnKind,
        'payment_method': paymentMethod,
        'payment_type': paymentType,
        if (outstandingAfter != null) 'outstanding_after': outstandingAfter,
        'supply_date': supplyDate.toIso8601String(),
      };

  Map<String, dynamic> toLocalJson() => {
        ...toHeaderJson(),
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final type = json['doc_type']?.toString() == 'creditNote' ||
            json['doc_type']?.toString() == 'credit_note'
        ? DocType.creditNote
        : DocType.taxInvoice;
    final headerInclusive =
        json['tax_inclusive'] == true || json['taxInclusive'] == true;
    final parsedLines = rawLines is List
        ? rawLines.map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            final line = InvoiceLine.fromJson(map);
            final hasFlag =
                map.containsKey('tax_inclusive') || map.containsKey('taxInclusive');
            return hasFlag ? line : line.copyWith(taxInclusive: headerInclusive);
          }).toList()
        : <InvoiceLine>[];
    return Invoice(
      id: json['id'].toString(),
      invoiceNo: (json['invoice_no'] ?? json['invoiceNo'] ?? '').toString(),
      docType: type,
      customerName:
          (json['customer_name'] ?? json['customerName'] ?? '').toString(),
      customerPhone:
          (json['customer_phone'] ?? json['customerPhone'] ?? '').toString(),
      customerTrn: (json['customer_trn'] ?? json['customerTrn'] ?? '').toString(),
      notes: json['notes']?.toString() ?? '',
      discount: asDouble(json['discount']),
      status: json['status']?.toString() ?? 'paid',
      lines: parsedLines,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      location: StockLocationX.fromId(json['location']?.toString()),
      sellerName: json['seller_name']?.toString() ?? '',
      vatTrn: (json['vat_trn'] ?? json['vatTrn'] ?? '').toString(),
      crNumber: (json['cr_number'] ?? json['crNumber'] ?? '').toString(),
      zatcaQr: (json['zatca_qr'] ?? json['zatcaQr'] ?? '').toString(),
      originalInvoiceId: json['original_invoice_id']?.toString(),
      originalInvoiceNo: json['original_invoice_no']?.toString(),
      submitted: json['submitted'] != false,
      createdBy: json['created_by']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      amountPaid: asDouble(json['amount_paid'] ?? json['amountPaid']),
      shopName: json['shop_name']?.toString() ?? '',
      uuid: (json['uuid'] ?? json['id'] ?? '').toString(),
      icv: (json['icv'] is num)
          ? (json['icv'] as num).toInt()
          : int.tryParse(json['icv']?.toString() ?? '') ?? 0,
      pih: json['pih']?.toString() ?? '',
      invoiceHash: (json['invoice_hash'] ?? json['invoiceHash'] ?? '').toString(),
      buyerCr: (json['buyer_cr'] ?? json['buyerCr'] ?? '').toString(),
      taxPercent: asDouble(json['tax_percent'] ?? json['taxPercent'] ?? vatRate),
      taxInclusive: json['tax_inclusive'] == true || json['taxInclusive'] == true,
      deliveryCharge: asDouble(json['delivery_charge'] ?? json['deliveryCharge']),
      roundOff: json['round_off'] == true || json['roundOff'] == true,
      gpsLat: asDouble(json['gps_lat'] ?? json['gpsLat']),
      gpsLng: asDouble(json['gps_lng'] ?? json['gpsLng']),
      customerSignature: (json['customer_signature'] ?? json['customerSignature'] ?? '').toString(),
      shopPhotoBase64: (json['shop_photo'] ?? json['shopPhoto'] ?? '').toString(),
      printCount: (json['print_count'] is num)
          ? (json['print_count'] as num).toInt()
          : int.tryParse(json['print_count']?.toString() ?? '') ?? 0,
      returnKind: (json['return_kind'] ?? json['returnKind'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'cash').toString(),
      paymentType: (json['payment_type'] ?? json['paymentType'] ?? json['payment_method'] ?? 'cash').toString(),
      outstandingAfter: json['outstanding_after'] == null && json['outstandingAfter'] == null
          ? null
          : asDouble(json['outstanding_after'] ?? json['outstandingAfter']),
      supplyDate: DateTime.tryParse(json['supply_date']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
