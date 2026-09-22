import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/models/crm.dart';
import 'package:united_kites/models/enums.dart';
import 'package:united_kites/models/inventory.dart';
import 'package:united_kites/models/invoice.dart';
import 'package:united_kites/models/item.dart';
import 'package:united_kites/services/billing_repository.dart';
import 'package:united_kites/state/billing_controller.dart';
import 'package:united_kites/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ledgers, stock, and daybook stay in balance', () async {
    final repo = BillingRepository.memory();
    final billing = BillingController(repo);
    await billing.load();
    await billing.setSession(UserSession.admin);

    const itemId = 'kite-1';
    await billing.saveItem(
      CatalogItem(
        id: itemId,
        sku: 'KT-1',
        name: 'Delta',
        department: ProductDept.other,
        size: 'M',
        color: 'Red',
        volume: '',
        unit: 'pcs',
        purchaseCost: 20,
        sellingPrice: 100,
        unitsPerCarton: 1,
        cartonPrice: 100,
      ),
      opening: const {StockLocation.warehouse: 10},
    );
    await billing.loadVan(
      van: StockLocation.van1,
      lines: [
        VanLoadLine(
          itemId: itemId,
          sku: 'KT-1',
          name: 'Delta',
          quantity: 4,
          purchaseCost: 20,
          sellingPrice: 100,
        ),
      ],
    );
    expect(billing.stockAt(StockLocation.warehouse, itemId).quantity, 6);
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, 4);
    expect(_moved(billing, StockLocation.warehouse, itemId), 6);
    expect(_moved(billing, StockLocation.van1, itemId), 4);

    await billing.saveCustomer(_customer('shop-a', opening: 0));
    final sale = await billing.submitInvoice(_sale(
      id: 'sale-a',
      no: 'INV-A',
      customerId: 'shop-a',
      itemId: itemId,
      paid: 0,
    ));
    expect(sale.grandTotal, 115);
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, 3);
    expect(billing.customerDue('shop-a'), 115);
    expect(billing.cogsFor(), 20);

    await billing.collectOutstanding(customerId: 'shop-a', amount: 40, method: 'cash');
    expect(billing.customerPaid('shop-a'), 40);
    expect(billing.customerDue('shop-a'), 75);
    expect(billing.customerLedger('shop-a').first.balance, billing.customerBalance('shop-a'));

    await billing.submitInvoice(_sale(
      id: 'cn-a',
      no: 'CN-A',
      customerId: 'shop-a',
      itemId: itemId,
      paid: 0,
      credit: true,
      originalId: sale.id,
      originalNo: sale.invoiceNo,
    ));
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, 4);
    expect(_moved(billing, StockLocation.van1, itemId), 4);
    expect(billing.cogsFor(), 0);
    expect(billing.customerDue('shop-a'), 0);
    expect(billing.customerPayable('shop-a'), 40);
    expect(billing.customerLedger('shop-a').first.balance, -40);

    final beforeExpense = billing.customerBalance('shop-a');
    await billing.addExpense(VanExpense(
      id: 'exp-1',
      van: StockLocation.van1.name,
      category: 'Fuel',
      amount: 10,
    ));
    expect(billing.customerBalance('shop-a'), beforeExpense);

    await billing.saveCustomer(_customer('shop-b', opening: 20));
    await billing.collectOutstanding(customerId: 'shop-b', amount: 20, method: 'cash');
    await billing.submitInvoice(_sale(
      id: 'sale-b',
      no: 'INV-B',
      customerId: 'shop-b',
      itemId: itemId,
      paid: 100,
    ));
    billing.invoices = [
      _sale(
        id: 'sale-gap',
        no: 'INV-GAP',
        customerId: 'shop-b',
        itemId: null,
        paid: 50,
        unitCost: 0,
      ),
      ...billing.invoices,
    ];
    expect(billing.customerPaid('shop-b'), 170);
    expect(billing.customerBalance('shop-b'), 80);
    expect(billing.customerDue('shop-b'), 80);
    expect(billing.customerLedger('shop-b').first.balance, billing.customerBalance('shop-b'));

    final beforeVoid = billing.stockAt(StockLocation.van1, itemId).quantity;
    final voided = await billing.submitInvoice(_sale(
      id: 'sale-void',
      no: 'INV-VOID',
      customerId: 'shop-a',
      itemId: itemId,
      paid: 0,
    ));
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, beforeVoid - 1);
    await billing.deleteInvoice(voided.id);
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, beforeVoid);
    expect(_moved(billing, StockLocation.van1, itemId), beforeVoid);

    final actions = billing.daybook.map((row) => row.action).toSet();
    expect(actions, containsAll(['Sale', 'Payment received', 'Credit note', 'Expense', 'Stock transfer', 'Void']));
    expect(billing.daybook.every((row) => row.actor == 'Admin'), isTrue);
    expect(billing.daybook.every((row) => row.reference.isNotEmpty), isTrue);

    final again = BillingController(repo);
    await again.load();
    expect(again.daybook.length, billing.daybook.length);
    expect(again.daybook.first.actor, 'Admin');
    expect(again.customerBalance('shop-b'), 80);
    expect(again.stockAt(StockLocation.van1, itemId).quantity, beforeVoid);

    await billing.setSession(UserSession.salesmanVan1);
    await billing.addExpense(VanExpense(
      id: 'exp-v1',
      van: StockLocation.van2.name,
      category: 'Toll',
      amount: 5,
    ));
    expect(billing.daybook.first.actor, 'V1');
    expect(billing.expenses.first.van, StockLocation.van1.name);

    await billing.setSession(UserSession.admin);
    await billing.factoryResetTransactions(pin: billing.settings.adminPin);
    expect(billing.daybook, isEmpty);
    expect(billing.invoices, isEmpty);
    expect(billing.items, isNotEmpty);
    expect(billing.stockAt(StockLocation.warehouse, itemId).quantity, 0);
    expect(billing.stockAt(StockLocation.van1, itemId).quantity, 0);
  });
}

double _moved(BillingController billing, StockLocation location, String itemId) {
  var total = 0.0;
  for (final row in billing.movements) {
    if (row.location == location && row.itemId == itemId) total += row.delta;
  }
  return moneyRound(total);
}

Customer _customer(String id, {required double opening}) {
  return Customer(
    id: id,
    name: id,
    phone: '0500000000',
    shopName: id,
    crNumber: '',
    vatNumber: '',
    lat: 0,
    lng: 0,
    openingBalance: opening,
  );
}

Invoice _sale({
  required String id,
  required String no,
  required String customerId,
  required String? itemId,
  required double paid,
  bool credit = false,
  String? originalId,
  String? originalNo,
  double unitCost = 20,
}) {
  return Invoice(
    id: id,
    invoiceNo: no,
    docType: credit ? DocType.creditNote : DocType.taxInvoice,
    customerName: customerId,
    customerPhone: '0500000000',
    customerTrn: '',
    notes: '',
    discount: 0,
    status: 'sold',
    location: StockLocation.van1,
    sellerName: 'United Kites',
    vatTrn: '',
    crNumber: '',
    zatcaQr: '',
    customerId: customerId,
    amountPaid: paid,
    originalInvoiceId: originalId,
    originalInvoiceNo: originalNo,
    returnKind: credit ? 'salable' : '',
    lines: [
      InvoiceLine(
        id: '$id-line',
        itemId: itemId,
        itemName: 'Delta',
        sku: 'KT-1',
        quantity: 1,
        unitPrice: 100,
        unitCost: unitCost,
      ),
    ],
  );
}
