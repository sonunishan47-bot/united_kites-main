enum StockLocation { warehouse, van1, van2, damage }

extension StockLocationX on StockLocation {
  String get id => name;

  String get label => switch (this) {
        StockLocation.warehouse => 'Warehouse',
        StockLocation.van1 => 'Van 1',
        StockLocation.van2 => 'Van 2',
        StockLocation.damage => 'Damage stock',
      };

  bool get isVan => this == StockLocation.van1 || this == StockLocation.van2;

  static StockLocation fromId(String? value) {
    return StockLocation.values.firstWhere(
      (loc) => loc.name == value || loc.id == value,
      orElse: () => StockLocation.warehouse,
    );
  }
}

enum AppRole { salesman, admin, partner }

enum ProductDept { apparel, footwear, perfume, other }

extension ProductDeptX on ProductDept {
  String get label => switch (this) {
        ProductDept.apparel => 'Dress',
        ProductDept.footwear => 'Footwear',
        ProductDept.perfume => 'Perfume',
        ProductDept.other => 'Other',
      };

  static const catalogChoices = [ProductDept.footwear, ProductDept.apparel, ProductDept.perfume];

  static ProductDept fromId(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v.contains('dress') || v.contains('apparel')) return ProductDept.apparel;
    if (v.contains('foot')) return ProductDept.footwear;
    if (v.contains('perfume')) return ProductDept.perfume;
    return ProductDept.values.firstWhere(
      (d) => d.name == v,
      orElse: () => ProductDept.other,
    );
  }
}

enum BillingUnit { piece, dozen, box, carton }

extension BillingUnitX on BillingUnit {
  static BillingUnit parse(String? raw) {
    return BillingUnit.values.firstWhere(
      (unit) => unit.name == raw,
      orElse: () => BillingUnit.piece,
    );
  }

  String get shortLabel => switch (this) {
        BillingUnit.piece => 'Pcs',
        BillingUnit.dozen => 'Dozen',
        BillingUnit.box => 'Box',
        BillingUnit.carton => 'Carton',
      };

  /// Pieces in one of this unit. Dozen is always 12. Box and Carton use the product pack size.
  double piecesEach(double unitsPerCarton) {
    final pack = unitsPerCarton <= 0 ? 1.0 : unitsPerCarton;
    return switch (this) {
      BillingUnit.piece => 1,
      BillingUnit.dozen => 12,
      BillingUnit.box => pack,
      BillingUnit.carton => pack,
    };
  }
}

/// Warehouse / transfer quantity entry. Stock is always stored as pieces.
enum StockQtyUnit { piece, carton, dozen }

extension StockQtyUnitX on StockQtyUnit {
  String get label => switch (this) {
        StockQtyUnit.piece => 'Pieces',
        StockQtyUnit.carton => 'Cartons / Boxes',
        StockQtyUnit.dozen => 'Dozens',
      };

  double toPieces(double qty, double unitsPerCarton) {
    final n = qty.isNaN || qty.isInfinite ? 0.0 : qty;
    return switch (this) {
      StockQtyUnit.piece => n,
      StockQtyUnit.carton => n * (unitsPerCarton <= 0 ? 1 : unitsPerCarton),
      StockQtyUnit.dozen => n * 12,
    };
  }
}

enum DocType { taxInvoice, creditNote }

class UserSession {
  const UserSession({
    required this.role,
    this.van,
    required this.label,
    this.credentialStamp = '',
  });

  final AppRole role;
  final StockLocation? van;
  final String label;
  /// SHA-256 of the PIN that opened this session. Mismatch → logout.
  final String credentialStamp;

  bool get isAdmin => role == AppRole.admin;
  bool get isSalesman => role == AppRole.salesman;
  bool get isPartner => role == AppRole.partner;
  bool get isReadOnly => isPartner;

  StockLocation get sellingLocation => van ?? StockLocation.van1;

  UserSession copyWith({String? credentialStamp, String? label}) {
    return UserSession(
      role: role,
      van: van,
      label: label ?? this.label,
      credentialStamp: credentialStamp ?? this.credentialStamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'van': van?.name,
        'label': label,
        'credential_stamp': credentialStamp,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final roleName = json['role']?.toString();
    final role = roleName == 'admin'
        ? AppRole.admin
        : roleName == 'partner'
            ? AppRole.partner
            : AppRole.salesman;
    return UserSession(
      role: role,
      van: json['van'] == null ? null : StockLocationX.fromId(json['van'].toString()),
      label: json['label']?.toString() ?? role.name,
      credentialStamp: (json['credential_stamp'] ?? json['credentialStamp'] ?? '').toString(),
    );
  }

  static const salesmanVan1 = UserSession(
    role: AppRole.salesman,
    van: StockLocation.van1,
    label: 'Salesman · Van 1',
  );

  static const salesmanVan2 = UserSession(
    role: AppRole.salesman,
    van: StockLocation.van2,
    label: 'Salesman · Van 2',
  );

  static const admin = UserSession(
    role: AppRole.admin,
    label: 'Admin',
  );

  static const partner = UserSession(
    role: AppRole.partner,
    label: 'Partner',
  );
}
