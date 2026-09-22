import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/models/crm.dart';
import 'package:united_kites/models/enums.dart';
import 'package:united_kites/models/inventory.dart';
import 'package:united_kites/models/invoice.dart';
import 'package:united_kites/models/item.dart';
import 'package:united_kites/models/shop_settings.dart';
import 'package:united_kites/services/billing_repository.dart';
import 'package:united_kites/services/pdf_service.dart';
import 'package:united_kites/state/billing_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('admin stock and price show on both vans and the partner view', () async {
    final billing = await _books();
    await billing.setSession(UserSession.admin);
    await _catalog(billing, price: 80);
    await _load(billing, StockLocation.van1, 10);
    await _load(billing, StockLocation.van2, 6);

    await billing.setSession(UserSession.salesmanVan1);
    expect(billing.itemById('kite')!.sellingPerPiece, 80);
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 10);
    expect(billing.scopedVan, StockLocation.van1);

    await billing.setSession(UserSession.salesmanVan2);
    expect(billing.itemById('kite')!.sellingPerPiece, 80);
    expect(billing.stockAt(StockLocation.van2, 'kite').quantity, 6);

    await billing.setSession(UserSession.partner);
    expect(billing.isPartner, isTrue);
    expect(billing.itemById('kite')!.sellingPerPiece, 80);
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 10);
    expect(billing.stockAt(StockLocation.van2, 'kite').quantity, 6);
    await expectLater(
      billing.submitInvoice(_sale(paid: 0, price: 80)),
      throwsA(isA<RbacException>()),
    );
  });

  test('van credit sale updates admin and partner stock and ledger', () async {
    final repo = BillingRepository.memory();
    final billing = await _books(repo);
    await billing.setSession(UserSession.admin);
    await _catalog(billing, price: 100);
    await _load(billing, StockLocation.van1, 20);
    await billing.saveCustomer(Customer(
      id: 'shop',
      name: 'Harbor',
      phone: '050',
      shopName: 'Harbor Shop',
      crNumber: '',
      vatNumber: '',
      lat: 24.7,
      lng: 46.7,
    ));

    await billing.setSession(UserSession.salesmanVan1);
    final sale = await billing.submitInvoice(_sale(paid: 200, price: 1200));
    expect(sale.zatcaQr, isNotEmpty);
    expect(sale.shopPhotoBase64, 'c2hvcA==');
    expect(sale.lines.first.billingUnit, BillingUnit.dozen);
    expect(sale.lines.first.stockPieces, 12);
    expect(sale.amountPaid, 200);
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 8);
    expect(billing.customerBalance('shop'), sale.grandTotal - 200);

    await billing.setSession(UserSession.admin);
    expect(billing.invoices.where((row) => row.id == sale.id), hasLength(1));
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 8);
    expect(billing.customerBalance('shop'), sale.grandTotal - 200);
    expect(billing.customerLedger('shop').first.balance, billing.customerBalance('shop'));

    await billing.setSession(UserSession.partner);
    expect(billing.stockAt(StockLocation.van1, 'kite').quantity, 8);
    expect(billing.customerDue('shop'), sale.grandTotal - 200);

    final settings = billing.settings;
    final narrow = await const PdfService().buildThermal(
      sale,
      settings.copyWith(paper: PaperProfile.thermal58),
    );
    final wide = await const PdfService().buildThermal(
      sale,
      settings.copyWith(paper: PaperProfile.thermal80),
    );
    expect(narrow.length, greaterThan(400));
    expect(wide.length, greaterThan(400));
  });

  test('offline reload keeps one invoice and drops a repeated id', () async {
    final repo = BillingRepository.memory();
    final billing = await _books(repo);
    await billing.setSession(UserSession.admin);
    await _catalog(billing, price: 100);
    await _load(billing, StockLocation.van1, 20);
    await billing.saveCustomer(Customer(
      id: 'shop',
      name: 'Harbor',
      phone: '050',
      shopName: 'Harbor Shop',
      crNumber: '',
      vatNumber: '',
      lat: 0,
      lng: 0,
    ));
    final sale = await billing.submitInvoice(_sale(paid: 0, price: 100, pieces: 1, unit: BillingUnit.piece));
    expect(billing.invoices.where((row) => row.id == sale.id), hasLength(1));

    final again = BillingController(repo);
    await again.load();
    await again.setSession(UserSession.admin);
    expect(again.invoices.where((row) => row.id == sale.id), hasLength(1));
    expect(again.stockAt(StockLocation.van1, 'kite').quantity, 19);
    expect(again.invoices.first.shopPhotoBase64, 'c2hvcA==');

    again.invoices = [again.invoices.first, again.invoices.first];
    await again.addExpense(VanExpense(
      id: 'exp-1',
      van: StockLocation.van1.name,
      category: 'Fuel',
      amount: 5,
    ));
    final third = BillingController(repo);
    await third.load();
    expect(third.invoices.where((row) => row.id == sale.id), hasLength(1));
    expect(third.expenses.where((row) => row.id == 'exp-1'), hasLength(1));
  });
}

Future<BillingController> _books([BillingRepository? repo]) async {
  final billing = BillingController(repo ?? BillingRepository.memory());
  await billing.load();
  return billing;
}

Future<void> _catalog(BillingController billing, {required double price}) {
  return billing.saveItem(
    CatalogItem(
      id: 'kite',
      sku: 'KT-1',
      name: 'Delta',
      department: ProductDept.other,
      size: 'M',
      color: 'Red',
      volume: '',
      unit: 'pcs',
      purchaseCost: 20,
      sellingPrice: price,
      unitsPerCarton: 1,
      cartonPrice: price,
    ),
    opening: const {StockLocation.warehouse: 40},
  );
}

Future<void> _load(BillingController billing, StockLocation van, double qty) {
  return billing.loadVan(
    van: van,
    lines: [
      VanLoadLine(
        itemId: 'kite',
        sku: 'KT-1',
        name: 'Delta',
        quantity: qty,
        purchaseCost: 20,
        sellingPrice: 100,
      ),
    ],
  );
}

Invoice _sale({
  required double paid,
  required double price,
  double pieces = 12,
  BillingUnit unit = BillingUnit.dozen,
}) {
  return Invoice(
    id: 'sale-van',
    invoiceNo: 'INV-VAN',
    docType: DocType.taxInvoice,
    customerName: 'Harbor',
    customerPhone: '050',
    customerTrn: '',
    notes: '',
    discount: 0,
    status: 'due',
    location: StockLocation.van1,
    sellerName: 'United Kites',
    vatTrn: '300000000000003',
    crNumber: '1010',
    zatcaQr: '',
    customerId: 'shop',
    amountPaid: paid,
    paymentMethod: paid > 0 && paid < price ? 'credit' : (paid <= 0 ? 'credit' : 'cash'),
    paymentType: 'cash',
    shopPhotoBase64: 'c2hvcA==',
    lines: [
      InvoiceLine(
        id: 'line-1',
        itemId: 'kite',
        itemName: 'Delta',
        sku: 'KT-1',
        quantity: unit == BillingUnit.piece ? pieces : 1,
        unitPrice: price,
        billingUnit: unit,
        pieces: pieces,
        unitCost: 20,
      ),
    ],
  );
}
