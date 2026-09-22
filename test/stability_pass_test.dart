import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/services/sync_identity.dart';
import 'package:united_kites/utils/formatters.dart';
import 'package:united_kites/utils/search_text.dart';

void main() {
  test('search ignores null fields and empty queries', () {
    expect(matchesSearch(null, [null, '']), isTrue);
    expect(matchesSearch('  ', ['Harbor']), isTrue);
    expect(matchesSearch('har', [null, 'Harbor Shop']), isTrue);
    expect(matchesSearch('kite', [null, 'Harbor']), isFalse);
  });

  test('offline ids stay unique across a repeated sync', () {
    final first = newId();
    final second = newId();
    expect(first, isNot(second));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(first), isTrue);
    final kept = uniqueById(
      ['inv-1', 'inv-1', 'pay-9', '', 'pay-9'],
      (row) => row,
    );
    expect(kept, ['inv-1', 'pay-9']);
  });
}
