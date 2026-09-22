import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

NumberFormat moneyFormat(String currency) =>
    NumberFormat.currency(locale: 'en', symbol: '${currency.trim().isEmpty ? 'SAR' : currency} ');

final sar = moneyFormat('SAR');
final sarAmount = NumberFormat('#,##0.00', 'en');
final dayTime = DateFormat('dd MMM yyyy, HH:mm');
final txnDate = DateFormat('dd MMM, yy');

String formatSarRs(num value) => '${sarAmount.format(moneyRound(value))} ر.س';

String displayInvoiceNo(String invoiceNo, {int icv = 0}) {
  if (icv > 0) return '#$icv';
  final matches = RegExp(r'(\d+)').allMatches(invoiceNo);
  if (matches.isNotEmpty) {
    final raw = matches.last.group(1)!;
    final stripped = raw.replaceFirst(RegExp(r'^0+'), '');
    return '#${stripped.isEmpty ? '0' : stripped}';
  }
  return invoiceNo.startsWith('#') ? invoiceNo : '#$invoiceNo';
}

const vatRate = 15.0;

String credentialStamp(String roleKey, String pin) {
  return sha256.convert(utf8.encode('united-kites/$roleKey/${pin.trim()}')).toString();
}

String generateAccessPin() {
  final random = Random();
  return List.generate(6, (_) => random.nextInt(10)).join();
}

String newId() {
  final random = Random();
  String hex(int count) =>
      List.generate(count, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}

double asDouble(dynamic value) {
  if (value is num) {
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite) return 0;
    return d;
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

/// Half-up to the nearest halala. Binary `toStringAsFixed` turns 1.005 into 1.00.
int toHalalas(num value) {
  final d = value.toDouble();
  if (d.isNaN || d.isInfinite) return 0;
  final sign = d.isNegative ? -1 : 1;
  final scaled = d.abs() * 100;
  final base = scaled.floor();
  final frac = scaled - base;
  final rounded = (frac + 1e-8) >= 0.5 ? base + 1 : base;
  return sign * rounded;
}

double fromHalalas(int halalas) {
  final neg = halalas < 0;
  final v = halalas.abs();
  final text = '${v ~/ 100}.${(v % 100).toString().padLeft(2, '0')}';
  final parsed = double.parse(text);
  return neg ? -parsed : parsed;
}

/// Integer division, half away from zero.
int roundDiv(int numerator, int denominator) {
  if (denominator <= 0) {
    throw ArgumentError.value(denominator, 'denominator');
  }
  final neg = numerator < 0;
  final n = numerator.abs();
  final q = n ~/ denominator;
  final r = n % denominator;
  final mag = r * 2 >= denominator ? q + 1 : q;
  return neg ? -mag : mag;
}

/// SAR amounts are always two decimal places (halalas).
double moneyRound(num value) => fromHalalas(toHalalas(value));

/// Two-decimal SAR text from integer halalas. Avoids `toStringAsFixed`, which
/// turns 1.005 into "1.00".
String moneyFixed(num value) {
  final halalas = toHalalas(value);
  final sign = halalas < 0 ? '-' : '';
  final abs = halalas.abs();
  final whole = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$sign$whole.$frac';
}

String shortRef(String id, [int max = 8]) {
  if (id.length <= max) return id;
  return id.substring(0, max);
}

String isoStamp(DateTime value) => value.toUtc().toIso8601String();

final invoiceDate = DateFormat('dd-MM-yyyy');

/// English amount-in-words for SAR (riyals and halalas).
String amountInWords(double amount) {
  final fils = toHalalas(amount);
  final riyals = (fils ~/ 100).clamp(0, 999999999);
  final halalas = (fils.abs() % 100).clamp(0, 99);
  final core = _enInt(riyals);
  if (halalas == 0) return '$core Saudi Riyals Only';
  return '$core Saudi Riyals and ${_enInt(halalas)} Halalas Only';
}

String _enInt(int n) {
  if (n == 0) return 'Zero';
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String chunk(int v) {
    if (v < 20) return ones[v];
    if (v < 100) {
      final rest = v % 10;
      return '${tens[v ~/ 10]}${rest == 0 ? '' : ' ${ones[rest]}'}';
    }
    final rest = v % 100;
    return '${ones[v ~/ 100]} Hundred${rest == 0 ? '' : ' ${chunk(rest)}'}';
  }

  final parts = <String>[];
  final million = n ~/ 1000000;
  final thousand = (n % 1000000) ~/ 1000;
  final rem = n % 1000;
  if (million > 0) parts.add('${chunk(million)} Million');
  if (thousand > 0) parts.add('${chunk(thousand)} Thousand');
  if (rem > 0) parts.add(chunk(rem));
  return parts.join(' ');
}

/// First-invoice PIH per ZATCA (SHA-256 of empty / 32 zero bytes as hex).
const zatcaZeroPih =
    '0000000000000000000000000000000000000000000000000000000000000000';

class ZatcaDigest {
  const ZatcaDigest(this.hex, this.bytes);
  final String hex;
  final Uint8List bytes;
}

/// ZATCA Phase 1 (TLV 1–5) + Phase 2 hash chain (ICV, UUID, PIH, tag 6).
class ZatcaQr {
  const ZatcaQr._();

  static String sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static ZatcaDigest digestOf({
    required String uuid,
    required String invoiceNo,
    required int icv,
    required String pih,
    required double totalWithVat,
    required double vatAmount,
    required DateTime timestamp,
  }) {
    final canonical = [
      uuid,
      invoiceNo,
      icv.toString(),
      pih,
      moneyFixed(totalWithVat),
      moneyFixed(vatAmount),
      isoStamp(timestamp),
    ].join('|');
    final bytes = Uint8List.fromList(sha256.convert(utf8.encode(canonical)).bytes);
    return ZatcaDigest(sha256Hex(canonical), bytes);
  }

  static String encode({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double totalWithVat,
    required double vatAmount,
    Uint8List? invoiceHash,
  }) {
    final payload = BytesBuilder(copy: false)
      ..add(_tlv(1, sellerName))
      ..add(_tlv(2, vatNumber))
      ..add(_tlv(3, isoStamp(timestamp)))
      ..add(_tlv(4, moneyFixed(totalWithVat)))
      ..add(_tlv(5, moneyFixed(vatAmount)));
    if (invoiceHash != null && invoiceHash.isNotEmpty) {
      payload.add(_tlvBytes(6, invoiceHash));
    }
    return base64Encode(payload.toBytes());
  }

  static Uint8List _tlv(int tag, String value) {
    final bytes = utf8.encode(value);
    if (bytes.length > 255) {
      return _tlv(tag, value.substring(0, 80));
    }
    return _tlvBytes(tag, bytes);
  }

  static Uint8List _tlvBytes(int tag, List<int> bytes) {
    final clipped = bytes.length > 255 ? bytes.sublist(0, 255) : bytes;
    return Uint8List.fromList([tag, clipped.length, ...clipped]);
  }
}
