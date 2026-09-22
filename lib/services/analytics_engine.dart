import 'dart:math';

import '../models/crm.dart';
import '../models/item.dart';
import '../models/invoice.dart';
import '../models/enums.dart';
import '../utils/formatters.dart';

class StockSignal {
  StockSignal({
    required this.item,
    required this.sold,
    required this.onHand,
    required this.kind,
  });

  final CatalogItem item;
  final double sold;
  final double onHand;
  final String kind;
}

class ProfitSnapshot {
  ProfitSnapshot({
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.collections,
    required this.dues,
    required this.commission,
  });

  final double revenue;
  final double cogs;
  final double expenses;
  final double collections;
  final double dues;
  final double commission;

  double get gross => moneyRound(revenue - cogs);
  double get net => moneyRound(revenue - cogs - expenses - commission);
}

class DayCloseSnapshot {
  DayCloseSnapshot({
    required this.van,
    required this.salesTotal,
    required this.cashSales,
    required this.bankSales,
    required this.chequeCollected,
    required this.creditSales,
    required this.expenses,
    required this.vanStockSell,
    required this.vanStockCost,
    required this.cashCollected,
    required this.creditCollections,
    required this.netDeposit,
    required this.outstandingDues,
  });

  final StockLocation van;
  final double salesTotal;
  final double cashSales;
  final double bankSales;
  final double chequeCollected;
  final double creditSales;
  final double expenses;
  final double vanStockSell;
  final double vanStockCost;
  final double cashCollected;
  /// Cash received today against older invoices or an opening balance.
  final double creditCollections;
  final double netDeposit;
  final double outstandingDues;
}

class AnalyticsEngine {
  const AnalyticsEngine();

  List<StockSignal> movement({
    required List<CatalogItem> items,
    required List<Invoice> invoices,
    required double Function(String itemId) onHand,
    int days = 30,
  }) {
    final since = DateTime.now().subtract(Duration(days: days));
    final sold = <String, double>{};
    for (final inv in invoices) {
      if (inv.docType != DocType.taxInvoice || inv.createdAt.isBefore(since)) {
        continue;
      }
      for (final line in inv.lines) {
        final id = line.itemId;
        if (id == null) continue;
        sold[id] = (sold[id] ?? 0) + line.stockPieces;
      }
    }
    final signals = <StockSignal>[];
    for (final item in items) {
      final qtySold = sold[item.id] ?? 0;
      final hand = onHand(item.id);
      final kind = qtySold >= 8
          ? 'fast'
          : (qtySold <= 0 && hand > 0 ? 'dead' : 'steady');
      signals.add(StockSignal(item: item, sold: qtySold, onHand: hand, kind: kind));
    }
    signals.sort((a, b) => b.sold.compareTo(a.sold));
    return signals;
  }

  /// Nearest-neighbour path (warehouse/depot → shops with GPS).
  List<Customer> optimizeRoute(
    List<Customer> shops, {
    double startLat = 24.7136,
    double startLng = 46.6753,
  }) {
    final pending = shops.where((s) => s.hasGps).toList();
    if (pending.isEmpty) return shops;
    final ordered = <Customer>[];
    var lat = startLat;
    var lng = startLng;
    while (pending.isNotEmpty) {
      pending.sort((a, b) => _km(lat, lng, a.lat, a.lng).compareTo(_km(lat, lng, b.lat, b.lng)));
      final next = pending.removeAt(0);
      ordered.add(next);
      lat = next.lat;
      lng = next.lng;
    }
    return ordered;
  }

  double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;
}
