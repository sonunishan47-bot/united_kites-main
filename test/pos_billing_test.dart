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

  test('dozen, box, and carton expand to pieces at the catalog rate', () {
    final item = CatalogItem(
      id: 'kite',
      sku: 'KT',
      name: 'Delta',
      department: ProductDept.other,
      size: '',
      color: '',
      volume: '',
      unit: 'pack',
      purchaseCost: 240,
      sellingPrice: 480,
      unitsPerCarton: 24,
      cartonPrice: 480,
    );
    expect(BillingUnit.dozen.piecesEach(item.cartonSize), 12);
    expect(BillingUnit.box.piecesEach(item.cartonSize), 24);
    expect(BillingUnit.carton.piecesEach(item.cartonSize), 24);
    expect(item.rateFor(BillingUnit.dozen), 240);
    expect(item.rateFor(BillingUnit.piece), 20);
  });

  test('credit sale keeps the amount received and the running ledger', () async {
    final billing = BillingController(BillingRepository.memory());
    await billing.load();
    await billing.setSession(UserSession.admin);
    await billing.saveItem(
      CatalogItem(
        id: 'kite',
        sku: 'KT',
        name: 'Delta',
        department: ProductDept.other,
        size: '',
        color: '',
        volume: '',
        unit: 'pcs',
        purchaseCost: 20,
        sellingPrice: 100,
        unitsPerCarton: 12,
        cartonPrice: 1200,
      ),
      opening: const {StockLocation.warehouse: 20},
    );
    await billing.loadVan(
      van: StockLocation.van1,
      lines: [
        VanLoadLine(
          itemId: 'kite',
          sku: 'KT',
          name: 'Delta',
          quantity: 20,
          purchaseCost: 20,
          sellingPrice: 100,
        ),
      ],
    );
    await billing.saveCustomer(Customer(
      id: 'shop',
      name: 'Shop',
      phone: '050',
      shopName: 'Shop',
      crNumber: '',
      vatNumber: '',
      lat: 0,
      lng: 0,
    ));
    final sale = await billing.submitInvoice(Invoice(
      id: 'sale-1',
      invoiceNo: 'INV-1',
      docType: DocType.taxInvoice,
      customerName: 'Shop',
      customerPhone: '050',
      customerTrn: '',
      notes: '',
      discount: 0,
      status: 'due',
      location: StockLocation.van1,
      sellerName: 'United Kites',
      vatTrn: '',
      crNumber: '',
      zatcaQr: '',
      customerId: 'shop',
      amountPaid: 200,
      paymentMethod: 'credit',
      paymentType: 'cash',
      shopPhotoBase64: 'cGhvdG8=',
      lines: [
        InvoiceLine(
          id: 'line',
          itemId: 'kite',
          itemName: 'Delta',
          sku: 'KT',
          quantity: 1,
          unitPrice: itemRate(),
          billingUnit: BillingUnit.dozen,
          pieces: 12,
          unitCost: 20,
        ),
      ],
    ));
    expect(sale.grandTotal, moneyRound(itemRate() * 1.15));
    expect(billing.customerPaid('shop'), 200);
    expect(billing.customerBalance('shop'), moneyRound(sale.grandTotal - 200));
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 8);
    final ledger = billing.customerLedger('shop');
    expect(ledger.first.balance, billing.customerBalance('shop'));
    expect(ledger.any((row) => row.kind == 'invoice' && row.invoiceId == sale.id), isTrue);
    expect(ledger.any((row) => row.kind == 'payment' && row.received == 200), isTrue);

    final again = Invoice.fromJson(sale.toLocalJson());
    expect(again.shopPhotoBase64, 'cGhvdG8=');
    expect(again.lines.first.billingUnit, BillingUnit.dozen);
    expect(again.lines.first.stockPieces, 12);
  });

  test('piece stock value is quantity times the purchase rate', () async {
    final billing = BillingController(BillingRepository.memory());
    await billing.load();
    await billing.setSession(UserSession.admin);
    await billing.saveItem(
      CatalogItem(
        id: 'kite',
        sku: 'KT',
        name: 'Delta',
        department: ProductDept.other,
        size: '',
        color: '',
        volume: '',
        unit: 'pcs',
        purchaseCost: 10,
        sellingPrice: 25,
        unitsPerCarton: 12,
        cartonPrice: 25,
      ),
      opening: const {StockLocation.warehouse: 96},
    );
    await billing.adjustStock(
      itemId: 'kite',
      location: StockLocation.warehouse,
      delta: 24,
      reason: 'Stock adjustment',
    );
    final item = billing.itemById('kite')!;
    expect(item.pricesArePerPack, isFalse);
    expect(item.stockValueOf(120), 1200);
    expect(billing.stockAt(StockLocation.warehouse, 'kite').quantity, 120);
    final txns = billing.itemTransactions('kite');
    expect(txns.firstWhere((row) => row.label == 'Opening Stock').amount, 960);
    expect(txns.firstWhere((row) => row.label == 'Stock adjustment').amount, 240);
    billing.dispose();
  });

  test('a repeated save updates the same customer and product', () async {
    final billing = BillingController(BillingRepository.memory());
    await billing.load();
    await billing.setSession(UserSession.admin);
    final customer = Customer(
      id: 'shop-1',
      name: 'Harbor',
      phone: '050',
      shopName: 'Harbor Shop',
      crNumber: '',
      vatNumber: '',
      lat: 24.7,
      lng: 46.7,
    );
    await billing.saveCustomer(customer);
    await billing.saveCustomer(customer.copyWith(phone: '051'));
    expect(billing.customers.where((row) => row.id == 'shop-1'), hasLength(1));
    expect(billing.customerById('shop-1')!.phone, '051');

    final item = CatalogItem(
      id: 'kite',
      sku: 'KT',
      name: 'Delta',
      department: ProductDept.other,
      size: '',
      color: '',
      volume: '',
      unit: 'pcs',
      purchaseCost: 10,
      sellingPrice: 20,
      unitsPerCarton: 1,
      cartonPrice: 20,
    );
    await billing.saveItem(item, opening: const {StockLocation.warehouse: 4});
    await billing.saveItem(item.copyWith(sellingPrice: 25));
    expect(billing.items.where((row) => row.id == 'kite'), hasLength(1));
    expect(billing.itemById('kite')!.sellingPrice, 25);
    billing.dispose();
  });

  test('piece stock value is quantity times purchase cost, and cash in hand follows cash received', () async {
    final billing = BillingController(BillingRepository.memory());
    await billing.load();
    await billing.setSession(UserSession.admin);
    await billing.saveItem(
      CatalogItem(
        id: 'shirt',
        sku: 'SH',
        name: 'Shirt',
        department: ProductDept.other,
        size: '',
        color: '',
        volume: '',
        unit: 'pack',
        purchaseCost: 10,
        sellingPrice: 20,
        unitsPerCarton: 12,
        cartonPrice: 120,
      ),
      opening: const {StockLocation.warehouse: 210},
    );
    final shirt = billing.itemById('shirt')!;
    expect(shirt.stockValueOf(210), 2100);
    final dozenPriced = CatalogItem(
      id: 'doz',
      sku: 'DZ',
      name: 'Dozen roll',
      department: ProductDept.other,
      size: '',
      color: '',
      volume: '',
      unit: 'dozen',
      purchaseCost: 10,
      sellingPrice: 20,
      unitsPerCarton: 12,
      cartonPrice: 10,
    );
    expect(dozenPriced.stockValueOf(96), 80);

    await billing.saveCustomer(Customer(
      id: 'shop',
      name: 'Khadeeja',
      phone: '050',
      shopName: 'Khadeeja Garments',
      crNumber: '',
      vatNumber: '',
      lat: 0,
      lng: 0,
    ));
    final sale = await billing.submitInvoice(Invoice(
      id: 'sale-cash',
      invoiceNo: '1',
      docType: DocType.taxInvoice,
      customerName: 'Khadeeja',
      customerPhone: '050',
      customerTrn: '',
      notes: '',
      discount: 0,
      status: 'sold',
      location: StockLocation.warehouse,
      sellerName: 'United Kites',
      vatTrn: '',
      crNumber: '',
      zatcaQr: '',
      customerId: 'shop',
      shopName: 'Khadeeja Garments',
      amountPaid: 100,
      paymentMethod: 'cash',
      lines: [
        InvoiceLine(
          id: 'line',
          itemId: 'shirt',
          itemName: 'Shirt',
          sku: 'SH',
          quantity: 1,
          unitPrice: 1000,
          pieces: 1,
          unitCost: 10,
          taxInclusive: true,
        ),
      ],
    ));
    expect(sale.grandTotal, 1000);
    expect(sale.balanceDue, 900);
    expect(billing.cashInHand, 100);
    expect(billing.customerDue('shop'), 900);

    await billing.collectOutstanding(customerId: 'shop', amount: 500, method: 'cash');
    expect(billing.cashInHand, 600);
    expect(billing.customerDue('shop'), 400);

    await billing.addExpense(VanExpense(
      id: 'fuel',
      van: 'van1',
      category: 'fuel',
      amount: 50,
    ));
    expect(billing.cashInHand, 550);
    expect(billing.itemTransactions('shirt').any((row) => row.party == 'Khadeeja Garments'), isTrue);
    billing.dispose();
  });

  test('a reduced piece rate discounts the line and profit uses cost times quantity', () async {
    final billing = BillingController(BillingRepository.memory());
    await billing.load();
    await billing.setSession(UserSession.admin);
    final shirt = CatalogItem(
      id: 'shirt',
      sku: 'SH',
      name: 'Shirt',
      department: ProductDept.other,
      size: '',
      color: '',
      volume: '',
      unit: 'pack',
      purchaseCost: 10,
      sellingPrice: 15,
      unitsPerCarton: 12,
      cartonPrice: 180,
    );
    expect(shirt.saleRateFor(BillingUnit.piece), 15);
    expect(shirt.cogsPerPiece, 10);
    await billing.saveItem(shirt, opening: const {StockLocation.warehouse: 100});
    await billing.saveCustomer(Customer(
      id: 'shop',
      name: 'Khadeeja',
      phone: '050',
      shopName: 'Khadeeja Garments',
      crNumber: '',
      vatNumber: '',
      lat: 0,
      lng: 0,
    ));
    final sale = await billing.submitInvoice(Invoice(
      id: 'sale-shirt',
      invoiceNo: '2',
      docType: DocType.taxInvoice,
      customerName: 'Khadeeja',
      customerPhone: '050',
      customerTrn: '',
      notes: '',
      discount: 0,
      status: 'sold',
      location: StockLocation.warehouse,
      sellerName: 'United Kites',
      vatTrn: '',
      crNumber: '',
      zatcaQr: '',
      customerId: 'shop',
      shopName: 'Khadeeja Garments',
      amountPaid: 400,
      paymentMethod: 'cash',
      lines: [
        InvoiceLine(
          id: 'line',
          itemId: 'shirt',
          itemName: 'Shirt',
          sku: 'SH',
          quantity: 100,
          unitPrice: 15,
          pieces: 100,
          lineDiscount: 100,
          unitCost: 10,
          taxInclusive: true,
        ),
      ],
    ));
    expect(sale.grandTotal, 1400);
    expect(sale.balanceDue, 1000);
    expect(billing.cashInHand, 400);
    expect(billing.customerDue('shop'), 1000);
    expect(billing.stockAt(StockLocation.warehouse, 'shirt').quantity, 0);
    final snap = billing.profit(todayOnly: false);
    expect(snap.revenue, 1400);
    expect(snap.cogs, 1000);
    expect(snap.commission, 8);
    expect(snap.net, 392);
    billing.dispose();
  });
}

double itemRate() => 100 * 12;
