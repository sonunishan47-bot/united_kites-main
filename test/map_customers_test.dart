import 'package:flutter_test/flutter_test.dart';
import 'package:united_kites/models/crm.dart';
import 'package:united_kites/services/map_customers.dart';

void main() {
  Customer party({
    required String id,
    required double lat,
    required double lng,
    String name = 'Shop',
  }) {
    return Customer(
      id: id,
      name: name,
      phone: '0550000000',
      shopName: name,
      crNumber: '',
      vatNumber: '',
      lat: lat,
      lng: lng,
    );
  }

  test('navigate URL uses the Google directions endpoint and exact coordinates', () {
    final shop = party(id: 'a', lat: 24.7136, lng: 46.6753);
    expect(
      shop.directionsUrl,
      'https://www.google.com/maps/dir/?api=1&destination=24.7136,46.6753',
    );
  });

  test('maps links, plus codes, and typed coordinates become a pin', () {
    final at = parseShopCoordinates(
      'https://www.google.com/maps/place/Harbor+Shop/@24.1000,46.1000,17z/data=!3d24.7136!4d46.6753',
    );
    expect(at!.lat, closeTo(24.7136, 0.00001));
    expect(at.lng, closeTo(46.6753, 0.00001));
    expect(at.address, 'Harbor Shop');

    final query = parseShopCoordinates('https://www.google.com/maps?q=21.5433,39.1728');
    expect(query!.lat, closeTo(21.5433, 0.00001));
    expect(query.lng, closeTo(39.1728, 0.00001));

    final destination = parseShopCoordinates(
      'https://www.google.com/maps/dir/?api=1&destination=24.7136,46.6753',
    );
    expect(destination!.lat, closeTo(24.7136, 0.00001));
    expect(destination.lng, closeTo(46.6753, 0.00001));

    final typed = parseShopCoordinates('24.7136, 46.6753');
    expect(typed!.lat, closeTo(24.7136, 0.00001));
    expect(typed.lng, closeTo(46.6753, 0.00001));

    final code = encodePlusCode(24.7136, 46.6753)!;
    final plus = parseShopCoordinates(code);
    expect(plus!.lat, closeTo(24.7136, 0.01));
    expect(plus.lng, closeTo(46.6753, 0.01));

    expect(parseShopCoordinates('https://maps.app.goo.gl/AbCdEfGh'), isNull);
    expect(isShortMapsLink('https://maps.app.goo.gl/AbCdEfGh'), isTrue);

    final resolved = resolveShopPoint(
      manual: 'https://www.google.com/maps?q=24.7136,46.6753',
      latText: '1',
      lngText: '2',
    );
    expect(resolved!.lat, closeTo(24.7136, 0.00001));
    expect(resolved.lng, closeTo(46.6753, 0.00001));
    expect(
      resolveShopPoint(
        manual: 'https://maps.app.goo.gl/AbCdEfGh',
        latText: '1',
        lngText: '2',
      ),
      isNull,
    );
  });

  test('every customer with coordinates is listed, and shops without GPS are not', () {
    final shops = [
      party(id: 'a', lat: 24.7, lng: 46.6, name: 'North'),
      party(id: 'b', lat: 0, lng: 0, name: 'No pin'),
      party(id: 'c', lat: 21.4, lng: 39.8, name: 'Jeddah'),
    ];
    final pins = filterMappedCustomers(shops, '');
    expect(pins.map((c) => c.id), ['a', 'c']);
  });
}
