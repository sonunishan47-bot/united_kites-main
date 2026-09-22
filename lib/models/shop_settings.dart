import 'dart:convert';
import 'dart:typed_data';

import 'app_options.dart';
import '../utils/formatters.dart';

class ShopSettings {
  ShopSettings({
    required this.shopName,
    required this.address,
    required this.phone,
    required this.vatTrn,
    required this.crNumber,
    required this.footerNote,
    required this.paper,
    required this.adminPin,
    this.vatRate = 0.0,
    this.iban = '',
    this.partnerPin = '135790',
    this.van1Pin = '112233',
    this.van2Pin = '445566',
    this.masterAdminPin = '246810',
    this.commissionRate = 2,
    this.partnerSharePct = 50,
    this.email = '',
    this.printerName = '',
    this.printerMac = '',
    this.autoPrint = false,
    this.shopNameAr = '',
    this.phone2 = '',
    this.buildingNo = '',
    this.zipCode = '',
    this.city = '',
    this.country = '',
    this.pincode = '',
    this.businessDescription = '',
    this.businessType = '',
    this.businessCategory = '',
    this.booksBeginning = '',
    this.logoBase64 = '',
    this.signatureBase64 = '',
    AppOptions? options,
  }) : options = options ?? AppOptions();

  final String shopName;
  final String shopNameAr;
  final String address;
  final String phone;
  final String phone2;
  final String vatTrn;
  final String crNumber;
  final String iban;
  final String footerNote;
  final PaperProfile paper;
  final String adminPin;
  final double vatRate;
  final String partnerPin;
  final String van1Pin;
  final String van2Pin;
  final String masterAdminPin;
  final double commissionRate;
  final double partnerSharePct;
  final String email;
  final String printerName;
  final String printerMac;
  final bool autoPrint;
  final String buildingNo;
  final String zipCode;
  final String city;
  final String country;
  final String pincode;
  final String businessDescription;
  final String businessType;
  final String businessCategory;
  final String booksBeginning;
  final String logoBase64;
  final String signatureBase64;
  final AppOptions options;

  String get displayName {
    final en = shopName.trim();
    final ar = shopNameAr.trim();
    if (ar.isEmpty) return en;
    if (en.isEmpty) return ar;
    if (en.contains(ar) || ar.contains(en)) return en.length >= ar.length ? en : ar;
    return '$en $ar';
  }

  String get zatcaSellerName => shopName.trim().isEmpty ? shopNameAr : shopName;

  bool get hasDistinctArabicName {
    final ar = shopNameAr.trim();
    if (ar.isEmpty) return false;
    final en = shopName.trim();
    return ar != en && !en.contains(ar);
  }

  /// Street / district only — never the composed print line.
  String get streetLine => _cleanStreet(
        address,
        buildingNo: buildingNo,
        city: city,
        zipCode: zipCode,
        pincode: pincode,
        country: country,
      );

  /// Single print line, e.g. "Bldg 7352, Al Makhwah, Al Baha 65312, Saudi Arabia".
  String get formattedAddress {
    final street = streetLine;
    final zip = zipCode.trim().isNotEmpty ? zipCode.trim() : pincode.trim();
    final cityZip = [
      if (city.trim().isNotEmpty) city.trim(),
      if (zip.isNotEmpty) zip,
    ].join(' ');
    return _uniqueJoin([
      if (buildingNo.trim().isNotEmpty) 'Bldg ${buildingNo.trim()}',
      if (street.isNotEmpty) street,
      if (cityZip.isNotEmpty) cityZip,
      if (country.trim().isNotEmpty) country.trim(),
    ]);
  }

  String get printAddress {
    final line = formattedAddress;
    return line.isNotEmpty ? line : streetLine;
  }

  String get bankPrintText {
    final lines = <String>[
      if (iban.trim().isNotEmpty) 'IBAN ${iban.trim()}',
      if (options.bankDetails.trim().isNotEmpty) options.bankDetails.trim(),
    ];
    return lines.join('\n');
  }

  bool get printBankDetails =>
      options.showBank || iban.trim().isNotEmpty || options.bankDetails.trim().isNotEmpty;

  bool get printTrnCr =>
      options.showTrnCr || vatTrn.trim().isNotEmpty || crNumber.trim().isNotEmpty;

  Uint8List? get logoBytes => _decode(logoBase64);
  Uint8List? get signatureBytes => _decode(signatureBase64);

  static Uint8List? _decode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return base64Decode(raw.trim());
    } catch (_) {
      return null;
    }
  }

  static final _addressLabels = RegExp(
    r'(Building Number|Building No\.?|Bldg\.?|Street Name|Street|District|'
    r'City|Zip Code|ZIP Code|Pincode|Pin Code|Country|'
    r'رقم المبنى|اسم الشارع|الحي|المدينة|الرمز البريدي|الدولة)\s*[:\-–]?\s*',
    caseSensitive: false,
  );

  static String _stripAddressLabels(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return '';
    t = t.replaceAll(_addressLabels, '');
    t = t.replaceAll(RegExp(r'\s*,\s*,+'), ', ');
    t = t.replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  static String _uniqueJoin(List<String> parts) {
    final seen = <String>{};
    final out = <String>[];
    for (final part in parts) {
      final v = part.trim();
      if (v.isEmpty) continue;
      final key = v.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(v);
    }
    return out.join(', ');
  }

  static String _cleanStreet(
    String raw, {
    required String buildingNo,
    required String city,
    required String zipCode,
    required String pincode,
    required String country,
  }) {
    var t = _stripAddressLabels(raw);
    final drop = <String>{
      for (final v in [
        buildingNo,
        'Bldg ${buildingNo.trim()}',
        'Bldg. ${buildingNo.trim()}',
        city,
        zipCode,
        pincode,
        country,
      ])
        if (v.trim().isNotEmpty) v.trim().toLowerCase(),
    };
    final seen = <String>{};
    final bits = <String>[];
    for (final part in t.split(RegExp(r'[,/|]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final key = p.toLowerCase();
      if (drop.contains(key) || seen.contains(key)) continue;
      seen.add(key);
      bits.add(p);
    }
    return bits.join(', ');
  }

  ShopSettings normalized() {
    final zip = zipCode.trim().isNotEmpty ? zipCode.trim() : pincode.trim();
    return copyWith(
      shopName: shopName.trim(),
      shopNameAr: shopNameAr.trim(),
      address: streetLine,
      phone: phone.trim(),
      phone2: phone2.trim(),
      email: email.trim(),
      vatTrn: vatTrn.trim(),
      crNumber: crNumber.trim(),
      buildingNo: buildingNo.trim(),
      zipCode: zip,
      pincode: pincode.trim() == zip ? '' : pincode.trim(),
      city: city.trim(),
      country: country.trim(),
    );
  }

  int get profileCompletion {
    const keys = 14;
    var filled = 0;
    bool ok(String v) => v.trim().isNotEmpty;
    if (ok(shopName)) filled++;
    if (ok(shopNameAr)) filled++;
    if (ok(phone)) filled++;
    if (ok(email)) filled++;
    if (ok(vatTrn)) filled++;
    if (ok(crNumber)) filled++;
    if (ok(city) || ok(address)) filled++;
    if (ok(country)) filled++;
    if (ok(buildingNo) || ok(pincode) || ok(zipCode)) filled++;
    if (ok(businessDescription) || ok(crNumber)) filled++;
    if (ok(businessType)) filled++;
    if (ok(businessCategory)) filled++;
    if (ok(logoBase64)) filled++;
    if (ok(signatureBase64)) filled++;
    return ((filled / keys) * 100).round().clamp(0, 100);
  }

  ShopSettings copyWith({
    String? shopName,
    String? shopNameAr,
    String? address,
    String? phone,
    String? phone2,
    String? vatTrn,
    String? crNumber,
    String? iban,
    String? footerNote,
    PaperProfile? paper,
    String? adminPin,
    double? vatRate,
    String? partnerPin,
    String? van1Pin,
    String? van2Pin,
    String? masterAdminPin,
    double? commissionRate,
    double? partnerSharePct,
    String? email,
    String? printerName,
    String? printerMac,
    bool? autoPrint,
    String? buildingNo,
    String? zipCode,
    String? city,
    String? country,
    String? pincode,
    String? businessDescription,
    String? businessType,
    String? businessCategory,
    String? booksBeginning,
    String? logoBase64,
    String? signatureBase64,
    AppOptions? options,
  }) {
    return ShopSettings(
      shopName: shopName ?? this.shopName,
      shopNameAr: shopNameAr ?? this.shopNameAr,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      vatTrn: vatTrn ?? this.vatTrn,
      crNumber: crNumber ?? this.crNumber,
      iban: iban ?? this.iban,
      footerNote: footerNote ?? this.footerNote,
      paper: paper ?? this.paper,
      adminPin: adminPin ?? this.adminPin,
      vatRate: vatRate ?? this.vatRate,
      partnerPin: partnerPin ?? this.partnerPin,
      van1Pin: van1Pin ?? this.van1Pin,
      van2Pin: van2Pin ?? this.van2Pin,
      masterAdminPin: masterAdminPin ?? this.masterAdminPin,
      commissionRate: commissionRate ?? this.commissionRate,
      partnerSharePct: partnerSharePct ?? this.partnerSharePct,
      email: email ?? this.email,
      printerName: printerName ?? this.printerName,
      printerMac: printerMac ?? this.printerMac,
      autoPrint: autoPrint ?? this.autoPrint,
      buildingNo: buildingNo ?? this.buildingNo,
      zipCode: zipCode ?? this.zipCode,
      city: city ?? this.city,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      businessDescription: businessDescription ?? this.businessDescription,
      businessType: businessType ?? this.businessType,
      businessCategory: businessCategory ?? this.businessCategory,
      booksBeginning: booksBeginning ?? this.booksBeginning,
      logoBase64: logoBase64 ?? this.logoBase64,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': 1,
        'shop_name': shopName,
        'shop_name_ar': shopNameAr,
        'address': address,
        'phone': phone,
        'phone2': phone2,
        'vat_trn': vatTrn,
        'gstin': vatTrn,
        'cr_number': crNumber,
        'iban': iban,
        'footer_note': footerNote,
        'paper': paper.name,
        'admin_pin': adminPin,
        'vat_rate': vatRate,
        'partner_pin': partnerPin,
        'van1_pin': van1Pin,
        'van2_pin': van2Pin,
        'master_admin_pin': masterAdminPin,
        'commission_rate': commissionRate,
        'partner_share_pct': partnerSharePct,
        'email': email,
        'printer_name': printerName,
        'printer_mac': printerMac,
        'auto_print': autoPrint,
        'building_no': buildingNo,
        'zip_code': zipCode,
        'city': city,
        'country': country,
        'pincode': pincode,
        'business_description': businessDescription,
        'business_type': businessType,
        'business_category': businessCategory,
        'books_beginning': booksBeginning,
        'logo_base64': logoBase64,
        'signature_base64': signatureBase64,
        'options': options.toJson(),
      };

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    final paperName = json['paper']?.toString();
    return ShopSettings(
      shopName: (json['shop_name'] ?? json['shopName'] ?? '').toString(),
      shopNameAr: (json['shop_name_ar'] ?? json['shopNameAr'] ?? '').toString(),
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      phone2: (json['phone2'] ?? json['phone_2'] ?? '').toString(),
      vatTrn: (json['vat_trn'] ?? json['vatTrn'] ?? json['gstin'] ?? '').toString(),
      crNumber: (json['cr_number'] ?? json['crNumber'] ?? '').toString(),
      iban: (json['iban'] ?? json['IBAN'] ?? '').toString(),
      footerNote: (json['footer_note'] ?? json['footerNote'] ?? 'شكراً | Thank you').toString(),
      paper: PaperProfileX.fromId(paperName),
      adminPin: (json['admin_pin'] ?? json['adminPin'] ?? '246810').toString(),
      vatRate: asDouble(json['vat_rate'] ?? 0.0),
      partnerPin: (json['partner_pin'] ?? json['partnerPin'] ?? '135790').toString(),
      van1Pin: (json['van1_pin'] ?? json['van1Pin'] ?? '112233').toString(),
      van2Pin: (json['van2_pin'] ?? json['van2Pin'] ?? '445566').toString(),
      masterAdminPin: (json['master_admin_pin'] ?? json['masterAdminPin'] ?? json['admin_pin'] ?? '246810').toString(),
      commissionRate: asDouble(json['commission_rate'] ?? json['commissionRate'] ?? 2),
      partnerSharePct: asDouble(json['partner_share_pct'] ?? json['partnerSharePct'] ?? 50),
      email: json['email']?.toString() ?? '',
      printerName: (json['printer_name'] ?? json['printerName'] ?? '').toString(),
      printerMac: (json['printer_mac'] ?? json['printerMac'] ?? '').toString(),
      autoPrint: json['auto_print'] == true || json['autoPrint'] == true,
      buildingNo: (json['building_no'] ?? json['buildingNo'] ?? '').toString(),
      zipCode: (json['zip_code'] ?? json['zipCode'] ?? '').toString(),
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      businessDescription: (json['business_description'] ?? json['businessDescription'] ?? '').toString(),
      businessType: (json['business_type'] ?? json['businessType'] ?? '').toString(),
      businessCategory: (json['business_category'] ?? json['businessCategory'] ?? '').toString(),
      booksBeginning: (json['books_beginning'] ?? json['booksBeginning'] ?? '').toString(),
      logoBase64: (json['logo_base64'] ?? json['logoBase64'] ?? '').toString(),
      signatureBase64: (json['signature_base64'] ?? json['signatureBase64'] ?? '').toString(),
      options: AppOptions.fromJson(
        json['options'] is Map ? Map<String, dynamic>.from(json['options'] as Map) : null,
      ),
    ).normalized();
  }

  static ShopSettings defaults() => ShopSettings(
        shopName: '',
        shopNameAr: '',
        address: '',
        phone: '',
        phone2: '',
        vatTrn: '',
        crNumber: '',
        iban: '',
        footerNote: 'شكراً | Thank you',
        paper: PaperProfile.thermal80,
        adminPin: '246810',
        partnerPin: '135790',
        van1Pin: '112233',
        van2Pin: '445566',
        masterAdminPin: '246810',
        commissionRate: 2,
        partnerSharePct: 50,
        email: '',
        printerName: '',
        printerMac: '',
        autoPrint: false,
        buildingNo: '',
        zipCode: '',
        city: '',
        country: '',
        pincode: '',
        businessDescription: '',
        businessType: '',
        businessCategory: '',
        booksBeginning: '',
      );
}

enum PaperProfile { a4, thermal80, thermal58 }

extension PaperProfileX on PaperProfile {
  bool get isThermal => this != PaperProfile.a4;

  String get label => switch (this) {
        PaperProfile.a4 => 'A4',
        PaperProfile.thermal80 => '80mm',
        PaperProfile.thermal58 => '58mm',
      };

  static PaperProfile fromId(String? value) {
    return switch (value) {
      'a4' => PaperProfile.a4,
      'thermal58' || '58mm' || 'roll57' => PaperProfile.thermal58,
      _ => PaperProfile.thermal80,
    };
  }
}
