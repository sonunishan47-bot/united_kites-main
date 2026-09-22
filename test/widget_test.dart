import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/services/billing_repository.dart';
import 'package:united_kites/state/billing_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch has no catalog or invoices', () async {
    final controller = BillingController(BillingRepository.memory());
    await controller.load();
    expect(controller.items, isEmpty);
    expect(controller.invoices, isEmpty);
    expect(controller.settings.shopName, isEmpty);
  });
}
