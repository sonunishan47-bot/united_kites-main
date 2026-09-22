import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/models/crm.dart';
import 'package:united_kites/models/enums.dart';
import 'package:united_kites/models/inventory.dart';
import 'package:united_kites/services/accounting_engine.dart';
import 'package:united_kites/services/billing_repository.dart';
import 'package:united_kites/state/billing_controller.dart';
import 'package:united_kites/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('half-up halala rounding does not use binary toStringAsFixed', () {
    expect(moneyRound(1.005), 1.01);
    expect(moneyRound(1.004), 1.00);
    expect(moneyRound(10.1), 10.10);
    expect(toHalalas(0.015), 2);
    expect(toHalalas(0.004), 0);
  });

  test('15% VAT inclusive and exclusive reconcile to the halala', () {
    final exclusive = AccountingEngine.splitEnteredRate(
      amount: 1000,
      taxPercent: 15,
      inclusive: false,
    );
    expect(exclusive.net, 1000);
    expect(exclusive.tax, 150);
    expect(exclusive.gross, 1150);
    expect(moneyRound(exclusive.net + exclusive.tax), exclusive.gross);

    final inclusive = AccountingEngine.splitEnteredRate(
      amount: 1000,
      taxPercent: 15,
      inclusive: true,
    );
    expect(inclusive.gross, 1000);
    expect(inclusive.net, 869.57);
    expect(inclusive.tax, 130.43);
    expect(moneyRound(inclusive.net + inclusive.tax), inclusive.gross);

    final ten = AccountingEngine.splitEnteredRate(
      amount: 10,
      taxPercent: 15,
      inclusive: true,
    );
    expect(ten.gross, 10);
    expect(moneyRound(ten.net + ten.tax), 10);
  });

  test('bill discount shares and partial payments leave no stray halala', () {
    final shares = AccountingEngine.allocateDiscount([10001, 10001, 10001], 100);
    expect(shares.fold(0, (a, b) => a + b), 100);

    final takes = AccountingEngine.allocatePayment([333, 333, 334], 1000);
    expect(takes, [333, 333, 334]);
    expect(takes.fold(0, (a, b) => a + b), 1000);

    final capped = AccountingEngine.allocatePayment([400, 400], 500);
    expect(capped, [400, 100]);
  });

  test('newest local copy wins when one storage write is stale', () {
    final best = pickNewestJson([
      '{"revision":1,"items":[]}',
      '{not json',
      '{"revision":4,"items":[1]}',
      '{"revision":2,"items":[]}',
    ]);
    expect(best?['revision'], 4);
    expect(pickNewestJson(['{bad', null, '']), isNull);
  });

  test('van salesman cannot approve returns or post another van expense', () async {
    final controller = BillingController(BillingRepository.memory());
    await controller.load();
    await controller.setSession(UserSession.salesmanVan1);

    expect(
      controller.reviewReturnRequest('missing', approve: true),
      throwsA(isA<RbacException>()),
    );
    expect(
      controller.loadVan(van: StockLocation.van2, lines: <VanLoadLine>[]),
      throwsA(isA<RbacException>()),
    );

    await controller.addExpense(
      VanExpense(id: 'e1', van: 'van2', category: 'fuel', amount: 12.5),
    );
    expect(controller.expenses.single.van, 'van1');
    expect(controller.scopedExpenses.single.amount, 12.5);

    await controller.setSession(UserSession.salesmanVan2);
    expect(controller.scopedExpenses, isEmpty);
    expect(controller.expenses, isNotEmpty);

    await controller.setSession(UserSession.partner);
    expect(
      controller.addExpense(
        VanExpense(id: 'e2', van: 'van1', category: 'fuel', amount: 1),
      ),
      throwsA(isA<RbacException>()),
    );
    controller.dispose();
  });
}
