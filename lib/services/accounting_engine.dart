import '../utils/formatters.dart';

/// Phase 1 mathematical & accounting engine.
/// Every SAR amount is rounded to 2 decimal places (halalas).
class AccountingEngine {
  AccountingEngine._();

  static double sar(num value) => moneyRound(value);

  static double netAfterDiscount(double subtotal, double discount) =>
      sar((subtotal - discount).clamp(0, double.infinity).toDouble());

  /// Tax base = (subtotal − discount) + delivery.
  static double taxBase({
    required double subtotal,
    required double discount,
    required double delivery,
  }) =>
      sar(netAfterDiscount(subtotal, discount) + delivery);

  static int _percentMilli(double taxPercent) => (taxPercent * 1000).round();

  /// VAT on an exclusive base, in halalas. 15% of 1000.00 is 150.00.
  static int vatExclusiveHalalas(int base, double taxPercent) {
    if (taxPercent <= 0 || base == 0) return 0;
    final milli = _percentMilli(taxPercent);
    if (milli <= 0) return 0;
    return roundDiv(base * milli, 100000);
  }

  /// Exclusive net inside a VAT-inclusive gross, in halalas.
  /// 1000.00 at 15% → 869.57, and VAT is the remaining 130.43.
  static int netFromInclusiveHalalas(int gross, double taxPercent) {
    if (taxPercent <= 0 || gross == 0) return gross;
    final milli = _percentMilli(taxPercent);
    if (milli <= 0) return gross;
    return roundDiv(gross * 100000, 100000 + milli);
  }

  static double vatExclusive(double base, double taxPercent) =>
      fromHalalas(vatExclusiveHalalas(toHalalas(base), taxPercent));

  static double vatInclusiveExtract(double grossInclusive, double taxPercent) {
    final gross = toHalalas(grossInclusive);
    final net = netFromInclusiveHalalas(gross, taxPercent);
    return fromHalalas(gross - net);
  }

  /// Split an entered rate into exclusive net, VAT, and gross payable.
  /// With Tax (inclusive) at SAR 1000 / 15%: net 869.57, VAT 130.43, total 1000.
  /// Without Tax (exclusive) at SAR 1000 / 15%: net 1000, VAT 150, total 1150.
  static ({double net, double tax, double gross}) splitEnteredRate({
    required double amount,
    required double taxPercent,
    required bool inclusive,
  }) {
    final entered = toHalalas(amount < 0 ? 0 : amount);
    if (taxPercent <= 0 || entered == 0) {
      final value = fromHalalas(entered);
      return (net: value, tax: 0.0, gross: value);
    }
    if (inclusive) {
      final net = netFromInclusiveHalalas(entered, taxPercent);
      return (
        net: fromHalalas(net),
        tax: fromHalalas(entered - net),
        gross: fromHalalas(entered),
      );
    }
    final tax = vatExclusiveHalalas(entered, taxPercent);
    return (
      net: fromHalalas(entered),
      tax: fromHalalas(tax),
      gross: fromHalalas(entered + tax),
    );
  }

  /// Spread a bill discount across line nets so the shares sum exactly.
  static List<int> allocateDiscount(List<int> weights, int discount) {
    if (weights.isEmpty || discount <= 0) {
      return List<int>.filled(weights.length, 0);
    }
    final sum = weights.fold(0, (a, b) => a + b);
    if (sum <= 0) return List<int>.filled(weights.length, 0);
    final capped = discount > sum ? sum : discount;
    final out = List<int>.filled(weights.length, 0);
    var used = 0;
    for (var i = 0; i < weights.length; i++) {
      final last = i == weights.length - 1;
      var share = last ? capped - used : roundDiv(weights[i] * capped, sum);
      if (share > weights[i]) share = weights[i];
      if (share > capped - used) share = capped - used;
      if (share < 0) share = 0;
      out[i] = share;
      used += share;
    }
    var rem = capped - used;
    for (var i = weights.length - 1; i >= 0 && rem > 0; i--) {
      final room = weights[i] - out[i];
      final add = room < rem ? room : rem;
      out[i] += add;
      rem -= add;
    }
    return out;
  }

  /// Apply [payment] halalas across invoice dues without leaving a stray fil.
  static List<int> allocatePayment(List<int> dues, int payment) {
    var left = payment < 0 ? 0 : payment;
    final out = <int>[];
    for (final due in dues) {
      final room = due < 0 ? 0 : due;
      final take = room < left ? room : left;
      out.add(take);
      left -= take;
    }
    return out;
  }

  /// Exclusive VAT: payable = (subtotal − discount + delivery) + tax.
  static double payableExclusive(double base, double tax) => sar(base + tax);

  static double stockLineValue(double quantity, double unitPrice) =>
      sar(quantity * unitPrice);

  static double potentialProfit(double sellingValue, double purchaseValue) =>
      sar(sellingValue - purchaseValue);

  /// Realized goods profit excluding VAT: (subtotal − discount) − COGS.
  static double realizedProfit({
    required double subtotal,
    required double discount,
    required double cogs,
  }) =>
      sar(netAfterDiscount(subtotal, discount) - cogs);

  static double lineCogs({required double unitCost, required double pieces}) =>
      sar(unitCost * pieces);
}

class StockMetrics {
  StockMetrics({
    required this.quantity,
    required this.purchaseValue,
    required this.sellingValue,
  });

  final double quantity;
  final double purchaseValue;
  final double sellingValue;

  double get potentialProfit =>
      AccountingEngine.potentialProfit(sellingValue, purchaseValue);
}
