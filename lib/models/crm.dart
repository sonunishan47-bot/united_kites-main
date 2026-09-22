import '../utils/formatters.dart';

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.shopName,
    required this.crNumber,
    required this.vatNumber,
    required this.lat,
    required this.lng,
    this.address = '',
    this.creditLimit = 0,
    this.openingBalance = 0,
    this.shopPhotoBase64 = '',
  });

  final String id;
  final String name;
  final String phone;
  final String shopName;
  final String crNumber;
  final String vatNumber;
  final double lat;
  final double lng;
  final String address;
  /// Max open credit. Only Admin may change this.
  final double creditLimit;
  /// Opening receivable (customer owes). Optional.
  final double openingBalance;
  final String shopPhotoBase64;

  bool get hasGps => lat.abs() > 0.01 || lng.abs() > 0.01;

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  String get directionsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

  String get display => shopName.isEmpty ? name : '$shopName · $name';

  Customer copyWith({
    String? name,
    String? phone,
    String? shopName,
    String? crNumber,
    String? vatNumber,
    double? lat,
    double? lng,
    String? address,
    double? creditLimit,
    double? openingBalance,
    String? shopPhotoBase64,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      shopName: shopName ?? this.shopName,
      crNumber: crNumber ?? this.crNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      openingBalance: openingBalance ?? this.openingBalance,
      shopPhotoBase64: shopPhotoBase64 ?? this.shopPhotoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'shop_name': shopName,
        'cr_number': crNumber,
        'vat_number': vatNumber,
        'lat': lat,
        'lng': lng,
        'address': address,
        'credit_limit': creditLimit,
        'opening_balance': openingBalance,
        if (shopPhotoBase64.isNotEmpty) 'shop_photo': shopPhotoBase64,
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      shopName: (json['shop_name'] ?? json['shopName'] ?? '').toString(),
      crNumber: (json['cr_number'] ?? json['crNumber'] ?? '').toString(),
      vatNumber: (json['vat_number'] ?? json['vatNumber'] ?? '').toString(),
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      address: json['address']?.toString() ?? '',
      creditLimit: asDouble(json['credit_limit'] ?? json['creditLimit']),
      openingBalance: asDouble(json['opening_balance'] ?? json['openingBalance']),
      shopPhotoBase64: (json['shop_photo'] ?? json['shopPhoto'] ?? '').toString(),
    );
  }
}

class CustomerLedgerEntry {
  CustomerLedgerEntry({
    required this.date,
    required this.invoiceNo,
    required this.items,
    required this.billed,
    required this.received,
    required this.balance,
    required this.kind,
    this.method = 'cash',
    this.invoiceId = '',
    this.paymentId = '',
  });

  final DateTime date;
  final String invoiceNo;
  final String items;
  final double billed;
  final double received;
  final double balance;
  final String kind;
  final String invoiceId;
  final String paymentId;
  /// `cash`, `bank`, or `credit`.
  final String method;
}

class LedgerPayment {
  LedgerPayment({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.method,
    this.invoiceId,
    this.note = '',
    this.van,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String customerId;
  final double amount;
  final String method;
  final String? invoiceId;
  final String note;
  final String? van;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'amount': amount,
        'method': method,
        'invoice_id': invoiceId,
        'note': note,
        'van': van,
        'created_at': createdAt.toIso8601String(),
      };

  factory LedgerPayment.fromJson(Map<String, dynamic> json) {
    return LedgerPayment(
      id: json['id'].toString(),
      customerId: (json['customer_id'] ?? json['customerId']).toString(),
      amount: asDouble(json['amount']),
      method: json['method']?.toString() ?? 'cash',
      invoiceId: json['invoice_id']?.toString(),
      note: json['note']?.toString() ?? '',
      van: json['van']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class VanExpense {
  VanExpense({
    required this.id,
    required this.van,
    required this.category,
    required this.amount,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String van;
  final String category;
  final double amount;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'van': van,
        'category': category,
        'amount': amount,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory VanExpense.fromJson(Map<String, dynamic> json) {
    return VanExpense(
      id: json['id'].toString(),
      van: json['van']?.toString() ?? 'van1',
      category: json['category']?.toString() ?? 'fuel',
      amount: asDouble(json['amount']),
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PromoRule {
  PromoRule({
    required this.id,
    required this.name,
    required this.minPieces,
    required this.discountPct,
    this.sampleQty = 0,
  });

  final String id;
  final String name;
  final double minPieces;
  final double discountPct;
  final double sampleQty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'min_pieces': minPieces,
        'discount_pct': discountPct,
        'sample_qty': sampleQty,
      };

  factory PromoRule.fromJson(Map<String, dynamic> json) {
    return PromoRule(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      minPieces: asDouble(json['min_pieces'] ?? json['minPieces']),
      discountPct: asDouble(json['discount_pct'] ?? json['discountPct']),
      sampleQty: asDouble(json['sample_qty'] ?? json['sampleQty']),
    );
  }
}

class CashSettlement {
  CashSettlement({
    required this.id,
    required this.van,
    required this.cashCollected,
    required this.outstandingDues,
    required this.handedOver,
    this.note = '',
    this.salesTotal = 0,
    this.chequeCollected = 0,
    this.bankSales = 0,
    this.creditSales = 0,
    this.expensesDeducted = 0,
    this.vanStockValue = 0,
    this.netDeposit = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String van;
  final double cashCollected;
  final double outstandingDues;
  final double handedOver;
  final String note;
  final double salesTotal;
  final double chequeCollected;
  final double bankSales;
  final double creditSales;
  final double expensesDeducted;
  final double vanStockValue;
  final double netDeposit;
  final DateTime createdAt;

  double get expectedCash => moneyRound(cashCollected);
  double get variance => moneyRound(handedOver - netDeposit);

  Map<String, dynamic> toJson() => {
        'id': id,
        'van': van,
        'cash_collected': cashCollected,
        'outstanding_dues': outstandingDues,
        'handed_over': handedOver,
        'note': note,
        'sales_total': salesTotal,
        'cheque_collected': chequeCollected,
        'bank_sales': bankSales,
        'credit_sales': creditSales,
        'expenses_deducted': expensesDeducted,
        'van_stock_value': vanStockValue,
        'net_deposit': netDeposit,
        'created_at': createdAt.toIso8601String(),
      };

  factory CashSettlement.fromJson(Map<String, dynamic> json) {
    return CashSettlement(
      id: json['id'].toString(),
      van: json['van']?.toString() ?? 'van1',
      cashCollected: asDouble(json['cash_collected'] ?? json['cashCollected']),
      outstandingDues: asDouble(json['outstanding_dues'] ?? json['outstandingDues']),
      handedOver: asDouble(json['handed_over'] ?? json['handedOver']),
      note: json['note']?.toString() ?? '',
      salesTotal: asDouble(json['sales_total'] ?? json['salesTotal']),
      chequeCollected: asDouble(json['cheque_collected'] ?? json['chequeCollected']),
      bankSales: asDouble(json['bank_sales'] ?? json['bankSales']),
      creditSales: asDouble(json['credit_sales'] ?? json['creditSales']),
      expensesDeducted: asDouble(json['expenses_deducted'] ?? json['expensesDeducted']),
      vanStockValue: asDouble(json['van_stock_value'] ?? json['vanStockValue']),
      netDeposit: asDouble(json['net_deposit'] ?? json['netDeposit']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class VisitLog {
  VisitLog({
    required this.id,
    required this.customerId,
    required this.van,
    required this.outcome,
    this.reason = '',
    this.lat = 0,
    this.lng = 0,
    this.invoiceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String customerId;
  final String van;
  /// `sale` or `nonsale`
  final String outcome;
  final String reason;
  final double lat;
  final double lng;
  final String? invoiceId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'van': van,
        'outcome': outcome,
        'reason': reason,
        'lat': lat,
        'lng': lng,
        'invoice_id': invoiceId,
        'created_at': createdAt.toIso8601String(),
      };

  factory VisitLog.fromJson(Map<String, dynamic> json) {
    return VisitLog(
      id: json['id'].toString(),
      customerId: (json['customer_id'] ?? json['customerId']).toString(),
      van: json['van']?.toString() ?? 'van1',
      outcome: json['outcome']?.toString() ?? 'nonsale',
      reason: json['reason']?.toString() ?? '',
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      invoiceId: json['invoice_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
