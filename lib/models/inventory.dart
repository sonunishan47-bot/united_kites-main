import '../models/enums.dart';
import '../utils/formatters.dart';

class InventoryRow {
  InventoryRow({
    required this.itemId,
    required this.location,
    required this.quantity,
    required this.reorderLevel,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String itemId;
  final StockLocation location;
  final double quantity;
  final double reorderLevel;
  final DateTime updatedAt;

  bool get isLow => quantity <= reorderLevel;

  String get key => stockKey(location, itemId);

  InventoryRow copyWith({
    double? quantity,
    double? reorderLevel,
    DateTime? updatedAt,
  }) {
    return InventoryRow(
      itemId: itemId,
      location: location,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'location': location.name,
        'quantity': quantity,
        'reorder_level': reorderLevel,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InventoryRow.fromJson(Map<String, dynamic> json) {
    return InventoryRow(
      itemId: (json['item_id'] ?? json['itemId']).toString(),
      location: StockLocationX.fromId(json['location']?.toString()),
      quantity: asDouble(json['quantity']),
      reorderLevel: asDouble(json['reorder_level'] ?? json['reorderLevel']),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

String stockKey(StockLocation location, String itemId) =>
    '${location.name}::$itemId';

class StockMovement {
  StockMovement({
    required this.id,
    required this.itemId,
    required this.location,
    required this.delta,
    required this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String itemId;
  final StockLocation location;
  final double delta;
  final String reason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'location': location.name,
        'delta': delta,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'].toString(),
      itemId: (json['item_id'] ?? json['itemId']).toString(),
      location: StockLocationX.fromId(json['location']?.toString()),
      delta: asDouble(json['delta']),
      reason: json['reason']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ItemTxn {
  ItemTxn({
    required this.at,
    required this.label,
    required this.qty,
    required this.amount,
    this.party = '',
    this.rate = 0,
    this.unit = 'Pcs',
    this.billedQty = 0,
    this.sale = false,
  });

  final DateTime at;
  final String label;
  final double qty;
  final double amount;
  final String party;
  final double rate;
  final String unit;
  final double billedQty;
  final bool sale;
}

class StockReturnLine {
  StockReturnLine({
    required this.itemId,
    required this.sku,
    required this.name,
    required this.pieces,
    this.unitPrice = 0,
    this.enteredQty = 0,
    this.unit = 'pcs',
    this.taxRate = 0,
    this.taxInclusive = false,
    this.unitCost = 0,
  });

  final String itemId;
  final String sku;
  final String name;
  final double pieces;
  final double unitPrice;
  final double enteredQty;
  final String unit;
  final double taxRate;
  final bool taxInclusive;
  final double unitCost;

  double get qty => enteredQty > 0 ? enteredQty : pieces;

  double get enteredAmount => moneyRound(unitPrice * qty);

  double get lineValue {
    if (taxRate <= 0) return enteredAmount;
    if (taxInclusive) return enteredAmount;
    return moneyRound(enteredAmount * (1 + taxRate / 100));
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'sku': sku,
        'name': name,
        'pieces': pieces,
        'unit_price': unitPrice,
        'entered_qty': enteredQty,
        'unit': unit,
        'tax_rate': taxRate,
        'tax_inclusive': taxInclusive,
        'unit_cost': unitCost,
      };

  factory StockReturnLine.fromJson(Map<String, dynamic> json) {
    return StockReturnLine(
      itemId: (json['item_id'] ?? json['itemId']).toString(),
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pieces: asDouble(json['pieces'] ?? json['quantity']),
      unitPrice: asDouble(json['unit_price'] ?? json['unitPrice']),
      enteredQty: asDouble(json['entered_qty'] ?? json['enteredQty']),
      unit: (json['unit']?.toString().isNotEmpty == true) ? json['unit'].toString() : 'pcs',
      taxRate: asDouble(json['tax_rate'] ?? json['taxRate']),
      taxInclusive: json['tax_inclusive'] == true || json['taxInclusive'] == true,
      unitCost: asDouble(json['unit_cost'] ?? json['unitCost']),
    );
  }
}

class StockReturnRequest {
  StockReturnRequest({
    required this.id,
    required this.van,
    required this.kind,
    required this.lines,
    this.status = 'pending',
    this.note = '',
    this.originalInvoiceId,
    this.originalInvoiceNo,
    this.customerId,
    this.customerName = '',
    this.requestedBy = '',
    this.reviewNote = '',
    this.creditNoteId,
    DateTime? createdAt,
    this.reviewedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final StockLocation van;
  /// salable → warehouse, damaged → damage stock
  final String kind;
  final String status;
  final List<StockReturnLine> lines;
  final String note;
  final String? originalInvoiceId;
  final String? originalInvoiceNo;
  final String? customerId;
  final String customerName;
  final String requestedBy;
  final String reviewNote;
  final String? creditNoteId;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isDamaged => kind == 'damaged';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  String get shortId => id.length <= 8 ? id : id.substring(id.length - 8);
  double get totalValue => moneyRound(lines.fold(0.0, (s, l) => s + l.lineValue));

  StockReturnRequest copyWith({
    String? status,
    String? reviewNote,
    DateTime? reviewedAt,
    String? creditNoteId,
  }) {
    return StockReturnRequest(
      id: id,
      van: van,
      kind: kind,
      lines: lines,
      status: status ?? this.status,
      note: note,
      originalInvoiceId: originalInvoiceId,
      originalInvoiceNo: originalInvoiceNo,
      customerId: customerId,
      customerName: customerName,
      requestedBy: requestedBy,
      reviewNote: reviewNote ?? this.reviewNote,
      creditNoteId: creditNoteId ?? this.creditNoteId,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'van': van.name,
        'kind': kind,
        'status': status,
        'lines': lines.map((l) => l.toJson()).toList(),
        'note': note,
        'original_invoice_id': originalInvoiceId,
        'original_invoice_no': originalInvoiceNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'requested_by': requestedBy,
        'review_note': reviewNote,
        'credit_note_id': creditNoteId,
        'created_at': createdAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
      };

  factory StockReturnRequest.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'];
    return StockReturnRequest(
      id: json['id'].toString(),
      van: StockLocationX.fromId(json['van']?.toString()),
      kind: json['kind']?.toString() ?? 'salable',
      status: json['status']?.toString() ?? 'pending',
      lines: raw is List
          ? raw
              .map((row) => StockReturnLine.fromJson(Map<String, dynamic>.from(row as Map)))
              .toList()
          : const [],
      note: json['note']?.toString() ?? '',
      originalInvoiceId: json['original_invoice_id']?.toString(),
      originalInvoiceNo: json['original_invoice_no']?.toString(),
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? '',
      reviewNote: json['review_note']?.toString() ?? '',
      creditNoteId: json['credit_note_id']?.toString() ?? json['creditNoteId']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
    );
  }
}

class VanLoadLine {
  VanLoadLine({
    required this.itemId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.purchaseCost,
    required this.sellingPrice,
  });

  final String itemId;
  final String sku;
  final String name;
  final double quantity;
  final double purchaseCost;
  final double sellingPrice;

  double get costValue => quantity * purchaseCost;
  double get sellValue => quantity * sellingPrice;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'sku': sku,
        'name': name,
        'quantity': quantity,
        'purchase_cost': purchaseCost,
        'selling_price': sellingPrice,
      };

  factory VanLoadLine.fromJson(Map<String, dynamic> json) {
    return VanLoadLine(
      itemId: (json['item_id'] ?? json['itemId']).toString(),
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: asDouble(json['quantity']),
      purchaseCost: asDouble(json['purchase_cost'] ?? json['purchaseCost']),
      sellingPrice: asDouble(json['selling_price'] ?? json['sellingPrice']),
    );
  }
}

class VanLoad {
  VanLoad({
    required this.id,
    required this.van,
    required this.lines,
    this.inbound = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final StockLocation van;
  /// True: warehouse → van. False: van → warehouse.
  final bool inbound;
  final List<VanLoadLine> lines;
  final DateTime createdAt;

  double get totalCost => lines.fold(0, (s, l) => s + l.costValue);
  double get totalSell => lines.fold(0, (s, l) => s + l.sellValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'van': van.name,
        'total_cost': totalCost,
        'total_sell': totalSell,
        'created_at': createdAt.toIso8601String(),
        'inbound': inbound,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory VanLoad.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'];
    return VanLoad(
      id: json['id'].toString(),
      van: StockLocationX.fromId(json['van']?.toString()),
      inbound: json['inbound'] != false,
      lines: raw is List
          ? raw
              .map((row) => VanLoadLine.fromJson(Map<String, dynamic>.from(row as Map)))
              .toList()
          : const [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
