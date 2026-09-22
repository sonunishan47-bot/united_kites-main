import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:united_kites/models/crm.dart';
import 'package:united_kites/models/enums.dart';
import 'package:united_kites/models/inventory.dart';
import 'package:united_kites/models/invoice.dart';
import 'package:united_kites/models/item.dart';
import 'package:united_kites/models/shop_settings.dart';
import 'package:united_kites/services/billing_repository.dart';
import 'package:united_kites/services/pdf_service.dart';
import 'package:united_kites/state/billing_controller.dart';
import 'package:united_kites/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ZATCA QR carries seller, TRN, and halala-exact totals', () {
    expect(moneyFixed(1.005), '1.01');
    final qr = ZatcaQr.encode(
      sellerName: 'United Kites',
      vatNumber: '300000000000003',
      timestamp: DateTime.utc(2026, 9, 22, 12),
      totalWithVat: 1000,
      vatAmount: 130.43,
    );
    final tags = _tlvText(qr);
    expect(tags[1], 'United Kites');
    expect(tags[2], '300000000000003');
    expect(tags[4], '1000.00');
    expect(tags[5], '130.43');
  });

  test('A4, 80mm, and 58mm layouts build for B2B and B2C', () async {
    final settings = ShopSettings.defaults().copyWith(
      shopName: 'United Kites',
      vatTrn: '300000000000003',
      crNumber: '1010123456',
      address: 'Riyadh',
      phone: '0500000000',
    );
    final b2b = _invoice(trn: '311111111111113', inclusive: false);
    final b2c = _invoice(trn: '', inclusive: true, unitPrice: 10);
    final pdf = const PdfService();

    final a4 = await pdf.buildA4(b2b, settings.copyWith(paper: PaperProfile.a4));
    final roll80 = await pdf.buildThermal(
      b2b,
      settings.copyWith(paper: PaperProfile.thermal80),
    );
    final roll58 = await pdf.buildThermal(
      b2c,
      settings.copyWith(paper: PaperProfile.thermal58),
    );

    expect(a4.length, greaterThan(500));
    expect(roll80.length, greaterThan(500));
    expect(roll58.length, greaterThan(500));
    expect(pdf.thermalFormat(settings.copyWith(paper: PaperProfile.thermal80)).width, PdfPageFormat.roll80.width);
    expect(pdf.thermalFormat(settings.copyWith(paper: PaperProfile.thermal58)).width, PdfPageFormat.roll57.width);
    expect(b2b.customerTrn, isNotEmpty);
    expect(b2c.customerTrn, isEmpty);
    expect(b2b.taxTotal, 15);
    expect(b2b.grandTotal, 115);
    expect(b2c.grandTotal, 10);
  });

  test('net handover is cash sales plus credit collections minus expenses', () async {
    final controller = BillingController(BillingRepository.memory());
    await controller.load();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    controller.invoices = [
      _invoice(id: 'today-v1', location: StockLocation.van1, paid: 115, createdAt: now),
      _invoice(
        id: 'old-v1',
        location: StockLocation.van1,
        paid: 0,
        unitPrice: 200,
        createdAt: yesterday,
      ),
      _invoice(id: 'today-v2', location: StockLocation.van2, paid: 200, unitPrice: 200, createdAt: now),
    ];
    controller.payments = [
      LedgerPayment(id: 'p1', customerId: 'c', amount: 115, method: 'cash', invoiceId: 'today-v1', van: 'van1', createdAt: now),
      LedgerPayment(id: 'p2', customerId: 'c', amount: 40, method: 'cash', invoiceId: 'old-v1', van: 'van1', createdAt: now),
      LedgerPayment(id: 'p3', customerId: 'c', amount: 200, method: 'cash', invoiceId: 'today-v2', van: 'van2', createdAt: now),
    ];
    controller.expenses = [
      VanExpense(id: 'e', van: 'van1', category: 'fuel', amount: 10, createdAt: now),
    ];

    await controller.setSession(UserSession.salesmanVan1);
    final own = controller.dayClose(van: StockLocation.van2, day: now);
    expect(own.van, StockLocation.van1);
    expect(own.cashSales, 115);
    expect(own.creditCollections, 40);
    expect(own.expenses, 10);
    expect(own.netDeposit, 145);
    expect(own.cashCollected, 155);

    await controller.setSession(UserSession.admin);
    final other = controller.dayClose(van: StockLocation.van2, day: now);
    expect(other.cashSales, 200);
    expect(other.creditCollections, 0);
    expect(other.expenses, 0);
    expect(other.netDeposit, 200);
    controller.dispose();
  });

  test('salesman cannot change master price, approve, or reset books', () async {
    final controller = BillingController(BillingRepository.memory());
    await controller.load();
    final item = CatalogItem(
      id: 'kite',
      sku: 'KT-1',
      name: 'Delta',
      department: ProductDept.other,
      size: '',
      color: '',
      volume: '',
      unit: 'pcs',
      purchaseCost: 20,
      sellingPrice: 100,
      unitsPerCarton: 1,
      cartonPrice: 100,
    );
    controller.items = [item];
    await controller.setSession(UserSession.salesmanVan1);
    expect(controller.saveItem(item), throwsA(isA<RbacException>()));
    expect(
      controller.submitInvoice(
        _invoice(id: 'bad-price', location: StockLocation.van1, unitPrice: 80, itemId: 'kite'),
      ),
      throwsA(isA<RbacException>()),
    );
    expect(
      controller.factoryResetTransactions(pin: '246810'),
      throwsA(isA<RbacException>()),
    );
    expect(controller.items.single.name, 'Delta');
    controller.dispose();
  });

  test('admin reset clears invoices and ledgers and keeps the catalog', () async {
    final controller = BillingController(BillingRepository.memory());
    await controller.load();
    controller.items = [
      CatalogItem(
        id: 'kite',
        sku: 'KT-1',
        name: 'Delta',
        department: ProductDept.other,
        size: '',
        color: '',
        volume: '',
        unit: 'pcs',
        purchaseCost: 20,
        sellingPrice: 100,
        unitsPerCarton: 1,
        cartonPrice: 100,
      ),
    ];
    controller.inventory = {
      stockKey(StockLocation.van1, 'kite'): InventoryRow(
        itemId: 'kite',
        location: StockLocation.van1,
        quantity: 4,
        reorderLevel: 1,
      ),
    };
    controller.invoices = [_invoice()];
    controller.payments = [
      LedgerPayment(id: 'p', customerId: 'c', amount: 10, method: 'cash'),
    ];
    controller.expenses = [
      VanExpense(id: 'e', van: 'van1', category: 'fuel', amount: 3),
    ];
    await controller.setSession(UserSession.admin);
    expect(
      controller.factoryResetTransactions(pin: '000000'),
      throwsA(isA<RbacException>()),
    );
    expect(controller.invoices, isNotEmpty);

    await controller.factoryResetTransactions(pin: '246810');
    expect(controller.invoices, isEmpty);
    expect(controller.payments, isEmpty);
    expect(controller.expenses, isEmpty);
    expect(controller.items.single.name, 'Delta');
    expect(controller.items.single.sellingPrice, 100);
    expect(controller.inventory.values.single.quantity, 0);
    controller.dispose();
  });
}

Invoice _invoice({
  String id = 'inv',
  String trn = '',
  bool inclusive = false,
  StockLocation location = StockLocation.van1,
  double paid = 0,
  double unitPrice = 100,
  String? itemId,
  DateTime? createdAt,
}) {
  return Invoice(
    id: id,
    invoiceNo: '1',
    docType: DocType.taxInvoice,
    customerName: trn.isEmpty ? 'Walk-in' : 'Al Noor Trading',
    customerPhone: '0550000000',
    customerTrn: trn,
    notes: '',
    discount: 0,
    status: 'sold',
    lines: [
      InvoiceLine(
        id: '$id-l',
        itemId: itemId,
        itemName: 'Delta',
        sku: 'KT-1',
        quantity: 1,
        unitPrice: unitPrice,
        taxRate: 15,
        taxInclusive: inclusive,
      ),
    ],
    location: location,
    sellerName: 'United Kites',
    vatTrn: '300000000000003',
    crNumber: '1010123456',
    zatcaQr: ZatcaQr.encode(
      sellerName: 'United Kites',
      vatNumber: '300000000000003',
      timestamp: createdAt ?? DateTime.utc(2026, 9, 22),
      totalWithVat: inclusive ? unitPrice : unitPrice * 1.15,
      vatAmount: inclusive ? 0 : unitPrice * 0.15,
    ),
    amountPaid: paid,
    createdAt: createdAt,
    buyerCr: trn.isEmpty ? '' : '4030000000',
    paymentMethod: paid > 0 ? 'cash' : 'credit',
  );
}

Map<int, String> _tlvText(String qr) {
  final bytes = base64Decode(qr);
  final tags = <int, String>{};
  var i = 0;
  while (i + 2 <= bytes.length) {
    final tag = bytes[i];
    final len = bytes[i + 1];
    final end = i + 2 + len;
    if (end > bytes.length) break;
    if (tag <= 5) tags[tag] = utf8.decode(bytes.sublist(i + 2, end));
    i = end;
  }
  return tags;
}
