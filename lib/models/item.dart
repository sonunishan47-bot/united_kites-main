import '../models/enums.dart';
import '../utils/formatters.dart';

class CatalogItem {
  CatalogItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.department,
    required this.size,
    required this.color,
    required this.volume,
    required this.unit,
    required this.purchaseCost,
    required this.sellingPrice,
    required this.unitsPerCarton,
    required this.cartonPrice,
    this.taxRate = vatRate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String sku;
  final String name;
  final ProductDept department;
  final String size;
  final String color;
  final String volume;
  final String unit;
  final double purchaseCost;
  final double sellingPrice;
  final double unitsPerCarton;
  final double cartonPrice;
  final double taxRate;
  final DateTime updatedAt;

  static String nextProductCode(List<CatalogItem> items, ProductDept department) {
    final prefix = switch (department) {
      ProductDept.footwear => 'FW',
      ProductDept.perfume => 'PF',
      _ => 'DR',
    };
    var maxN = 0;
    final pattern = RegExp('^$prefix-?(\\d+)\$', caseSensitive: false);
    for (final item in items) {
      final match = pattern.firstMatch(item.sku.trim());
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n > maxN) maxN = n;
    }
    return '$prefix-${(maxN + 1).toString().padLeft(4, '0')}';
  }

  static String _foldKey(CatalogItem item) {
    final sku = item.sku.trim().toLowerCase();
    if (sku.isNotEmpty) return 'sku:$sku';
    final name = item.name.trim().toLowerCase();
    final volume = item.volume.trim().toLowerCase();
    return 'name:$name|$volume|${item.department.name}';
  }

  /// One row per product id, then per SKU / name so cloud upserts cannot fan out.
  static List<CatalogItem> unique(List<CatalogItem> items) {
    final byId = <String, CatalogItem>{};
    for (final item in items) {
      if (item.id.isEmpty || item.id == 'null') continue;
      final prev = byId[item.id];
      if (prev == null || !item.updatedAt.isBefore(prev.updatedAt)) {
        byId[item.id] = item;
      }
    }
    final byKey = <String, CatalogItem>{};
    for (final item in byId.values) {
      final key = _foldKey(item);
      final prev = byKey[key];
      if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
        byKey[key] = item;
      }
    }
    final byName = <String, CatalogItem>{};
    for (final item in byKey.values) {
      final nk =
          '${item.department.name}|${item.name.trim().toLowerCase()}|${item.volume.trim().toLowerCase()}';
      final prev = byName[nk];
      if (prev == null || item.updatedAt.isAfter(prev.updatedAt)) {
        byName[nk] = item;
      }
    }
    return byName.values.toList();
  }

  static const dozenPieces = 12.0;

  double get cartonSize => unitsPerCarton <= 0 ? 1 : unitsPerCarton;

  /// True when the saved unit says the entered selling rate is for a pack.
  /// Piece rows keep the typed rate even if a carton size is set.
  bool get pricesArePerPack {
    final u = unit.trim().toLowerCase();
    return u == 'pack' || u == 'dozen' || u == 'carton' || u == 'doz' || u == 'box';
  }

  double get purchasePerPiece {
    if (!pricesArePerPack) return purchaseCost;
    return moneyRound(purchaseCost / cartonSize);
  }

  double get sellingPerPiece {
    if (!pricesArePerPack) return sellingPrice;
    return moneyRound(sellingPrice / cartonSize);
  }

  bool get _explicitPackPrice {
    final u = unit.trim().toLowerCase();
    return u == 'dozen' || u == 'doz' || u == 'carton' || u == 'box';
  }

  /// Pcs uses the saved sale price. Dozen, carton, and box prices are converted.
  double saleRateFor(BillingUnit billing) {
    if (billing == BillingUnit.piece) return moneyRound(sellingPrice);
    if (_explicitPackPrice) return rateFor(billing);
    return moneyRound(sellingPrice * billing.piecesEach(cartonSize));
  }

  /// One piece of purchase cost. A dozen or carton price is split per piece.
  double get cogsPerPiece {
    if (!_explicitPackPrice || cartonSize <= 1.0001) return purchaseCost;
    return purchasePerPiece;
  }

  double get packPurchasePrice =>
      pricesArePerPack ? purchaseCost : moneyRound(purchaseCost * cartonSize);

  double get packSellingPrice =>
      pricesArePerPack ? sellingPrice : moneyRound(sellingPrice * cartonSize);

  /// Pack count and leftover pieces for warehouse qty stored in pieces.
  ({double packs, double leftover}) packSplit(double pieces) {
    final qty = pieces < 0 ? 0.0 : pieces;
    final pack = cartonSize;
    if (pack <= 1.0001) return (packs: 0, leftover: qty);
    final packs = (qty / pack).floorToDouble();
    return (packs: packs, leftover: moneyRound(qty - packs * pack));
  }

  /// Piece and generic pack rows: quantity × the entered purchase rate.
  /// Explicit dozen, carton, or box prices divide by pieces per pack, in
  /// halalas, so 96 × 10 / 12 stays 80.00 instead of 96 × 0.83.
  double stockValueOf(double pieces) => _stockExtended(pieces, purchaseCost);

  double stockSellValueOf(double pieces) => _stockExtended(pieces, sellingPrice);

  double _stockExtended(double pieces, double rate) {
    final u = unit.trim().toLowerCase();
    final explicitPack = u == 'dozen' || u == 'doz' || u == 'carton' || u == 'box';
    final qty = pieces < 0 ? 0.0 : pieces;
    if (!explicitPack || cartonSize <= 1.0001) return moneyRound(qty * rate);
    return _extendedValue(qty, rate);
  }

  double _extendedValue(double pieces, double rate) {
    final qty = pieces < 0 ? 0.0 : pieces;
    if (qty <= 0 || rate == 0) return 0;
    if (!pricesArePerPack || cartonSize <= 1.0001) return moneyRound(qty * rate);
    final qtyMilli = (qty * 1000).round();
    final packMilli = (cartonSize * 1000).round();
    if (packMilli <= 0) return 0;
    return fromHalalas(roundDiv(toHalalas(rate) * qtyMilli, packMilli));
  }

  static double toBasePieces({
    double pieces = 0,
    double cartons = 0,
    double dozens = 0,
    required double unitsPerCarton,
  }) {
    final ctn = unitsPerCarton <= 0 ? 1 : unitsPerCarton;
    return moneyRound(pieces + cartons * ctn + dozens * dozenPieces);
  }

  String stockBreakdown(double qty) {
    final pcs = qty < 0 ? 0 : qty;
    final boxes = pcs / cartonSize;
    final doz = pcs / dozenPieces;
    return '${pcs.toStringAsFixed(0)} pcs · ${boxes.toStringAsFixed(1)} boxes · ${doz.toStringAsFixed(1)} doz';
  }

  double get margin => sellingPerPiece - purchasePerPiece;
  double get marginPct =>
      purchasePerPiece <= 0 ? 0 : (margin / purchasePerPiece) * 100;

  double rateFor(BillingUnit unit) =>
      moneyRound(sellingPerPiece * unit.piecesEach(cartonSize));

  double costFor(BillingUnit unit) =>
      moneyRound(purchasePerPiece * unit.piecesEach(cartonSize));

  String get variantLabel {
    final parts = <String>[
      if (size.isNotEmpty) 'Sz $size',
      if (color.isNotEmpty) color,
      if (volume.isNotEmpty) volume,
    ];
    return parts.isEmpty ? department.label : parts.join(' · ');
  }

  CatalogItem copyWith({
    String? sku,
    String? name,
    ProductDept? department,
    String? size,
    String? color,
    String? volume,
    String? unit,
    double? purchaseCost,
    double? sellingPrice,
    double? unitsPerCarton,
    double? cartonPrice,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      department: department ?? this.department,
      size: size ?? this.size,
      color: color ?? this.color,
      volume: volume ?? this.volume,
      unit: unit ?? this.unit,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unitsPerCarton: unitsPerCarton ?? this.unitsPerCarton,
      cartonPrice: cartonPrice ?? this.cartonPrice,
      taxRate: taxRate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'department': department.name,
        'category': department.label,
        'size': size,
        'color': color,
        'volume': volume,
        'unit': unit,
        'purchase_cost': purchaseCost,
        'selling_price': sellingPrice,
        'price': sellingPrice,
        'units_per_carton': unitsPerCarton,
        'carton_price': cartonPrice,
        'tax_rate': taxRate,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim() ?? '';
    final sku = json['sku']?.toString() ?? '';
    return CatalogItem(
      id: (rawId.isEmpty || rawId == 'null') ? (sku.isNotEmpty ? sku : rawId) : rawId,
      sku: sku,
      name: json['name']?.toString() ?? '',
      department: ProductDeptX.fromId(
        json['department']?.toString() ?? json['category']?.toString(),
      ),
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      volume: json['volume']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'pcs',
      purchaseCost: asDouble(json['purchase_cost'] ?? json['purchaseCost']),
      sellingPrice: asDouble(
        json['selling_price'] ?? json['sellingPrice'] ?? json['price'],
      ),
      unitsPerCarton: asDouble(json['units_per_carton'] ?? json['unitsPerCarton'] ?? 12)
          .clamp(1, 9999)
          .toDouble(),
      cartonPrice: asDouble(json['carton_price'] ?? json['cartonPrice']),
      taxRate: asDouble(json['tax_rate'] ?? json['taxRate'] ?? vatRate),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
