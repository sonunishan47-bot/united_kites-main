import '../models/crm.dart';

List<Customer> filterMappedCustomers(List<Customer> customers, String query) {
  final withGps = customers.where((c) => c.hasGps);
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return withGps.toList();
  return withGps.where((c) {
    final hay = '${c.shopName} ${c.name} ${c.address} ${c.phone}'.toLowerCase();
    return hay.contains(q);
  }).toList();
}

enum ShopPinStatus { paid, due, partial }

ShopPinStatus shopPinStatus({required double billed, required double paid}) {
  final due = billed - paid;
  if (due <= 0.05) return ShopPinStatus.paid;
  if (paid > 0.05) return ShopPinStatus.partial;
  return ShopPinStatus.due;
}

bool isShortMapsLink(String raw) {
  final t = raw.trim().toLowerCase();
  return t.contains('maps.app.goo.gl') || t.contains('goo.gl/maps') || t.contains('maps.app.goo.gl/');
}

/// Prefer a pasted Maps link or Plus Code, then the latitude and longitude fields.
({double lat, double lng, String? address})? resolveShopPoint({
  required String manual,
  String latText = '',
  String lngText = '',
  double refLat = 24.7136,
  double refLng = 46.6753,
}) {
  final raw = manual.trim();
  final linked = raw.contains('://') ||
      raw.toLowerCase().contains('goo.gl') ||
      raw.toLowerCase().contains('maps') ||
      raw.contains('+');
  if (linked) {
    final parsed = parseShopCoordinates(raw, refLat: refLat, refLng: refLng);
    if (parsed != null) return parsed;
    final urlLike = raw.contains('://') || raw.toLowerCase().contains('goo.gl');
    if (urlLike) return null;
  }
  final a = double.tryParse(latText.trim());
  final b = double.tryParse(lngText.trim());
  if (a != null && b != null && a.abs() <= 90 && b.abs() <= 180) {
    return (lat: a, lng: b, address: null);
  }
  return parseShopCoordinates(raw, refLat: refLat, refLng: refLng);
}

/// Parses coordinates, a Google Maps URL, or a Plus Code.
/// Place-pin `!3d` / `!4d` wins over the map camera `@lat,lng`.
({double lat, double lng, String? address})? parseShopCoordinates(
  String raw, {
  double refLat = 24.7136,
  double refLng = 46.6753,
}) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final place = _placeName(t);

  ({double lat, double lng, String? address})? pack(String latRaw, String lngRaw) {
    final hit = _validLatLng(latRaw, lngRaw);
    if (hit == null) return null;
    return (lat: hit.$1, lng: hit.$2, address: place);
  }

  final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (pin != null) {
    final hit = pack(pin.group(1)!, pin.group(2)!);
    if (hit != null) return hit;
  }

  final at = RegExp(r'@(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (at != null) {
    final hit = pack(at.group(1)!, at.group(2)!);
    if (hit != null) return hit;
  }

  final query = RegExp(
    r'[?&](?:q|query|ll|destination|daddr|sll|center)=(-?\d+(?:\.\d+)?)(?:[,+]|\s|%2[Cc])+(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(t);
  if (query != null) {
    final hit = pack(query.group(1)!, query.group(2)!);
    if (hit != null) return hit;
  }

  final placeCoords = RegExp(r'/place/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (placeCoords != null) {
    final hit = pack(placeCoords.group(1)!, placeCoords.group(2)!);
    if (hit != null) return hit;
  }

  final looksUrl = t.contains('://') || t.toLowerCase().contains('goo.gl') || t.toLowerCase().contains('maps.');
  if (!looksUrl) {
    final pair = RegExp(
      r'(-?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(t);
    if (pair != null) {
      final hit = pack(pair.group(1)!, pair.group(2)!);
      if (hit != null) return hit;
    }
    final plus = decodePlusCode(t, refLat: refLat, refLng: refLng);
    if (plus != null) {
      return (lat: plus.lat, lng: plus.lng, address: place ?? t);
    }
    return null;
  }

  final token = RegExp(
    r'([23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3})',
    caseSensitive: false,
  ).firstMatch(t);
  if (token != null) {
    final plus = decodePlusCode(token.group(1)!, refLat: refLat, refLng: refLng);
    if (plus != null) return (lat: plus.lat, lng: plus.lng, address: place);
  }
  return null;
}

(double, double)? _validLatLng(String latRaw, String lngRaw) {
  final a = double.tryParse(latRaw);
  final b = double.tryParse(lngRaw);
  if (a == null || b == null) return null;
  if (a.abs() <= 90 && b.abs() <= 180) return (a, b);
  if (b.abs() <= 90 && a.abs() <= 180) return (b, a);
  return null;
}

String? _placeName(String raw) {
  final match = RegExp(r'/place/([^/@?#]+)').firstMatch(raw);
  if (match == null) return null;
  var name = match.group(1)!;
  try {
    name = Uri.decodeComponent(name);
  } catch (_) {}
  name = name.replaceAll('+', ' ').trim();
  if (name.isEmpty || RegExp(r'^-?\d').hasMatch(name)) return null;
  return name;
}

String? encodePlusCode(double lat, double lng) => _olcEncode(lat, lng);

({double lat, double lng})? decodePlusCode(
  String raw, {
  double refLat = 24.7136,
  double refLng = 46.6753,
}) {
  var code = raw.trim().toUpperCase();
  final space = code.indexOf(' ');
  if (space > 0) code = code.substring(0, space);
  code = code.replaceAll(RegExp(r'[^2-9A-Z+]'), '');
  if (!code.contains('+')) return null;
  final plus = code.indexOf('+');
  if (plus < 8) {
    final recovered = _recoverNearest(code, refLat, refLng);
    if (recovered == null) return null;
    code = recovered;
  }
  return _olcDecodeCenter(code);
}

const _olcAlpha = '23456789CFGHJMPQRVWX';

({double lat, double lng})? _olcDecodeCenter(String code) {
  final clean = code.replaceAll('+', '');
  if (clean.length < 2) return null;
  var lat = 0.0;
  var lng = 0.0;
  var latPlace = 20.0;
  var lngPlace = 20.0;
  for (var i = 0; i + 1 < clean.length && i < 10; i += 2) {
    final dLat = _olcAlpha.indexOf(clean[i]);
    final dLng = _olcAlpha.indexOf(clean[i + 1]);
    if (dLat < 0 || dLng < 0) return null;
    lat += dLat * latPlace;
    lng += dLng * lngPlace;
    latPlace /= 20;
    lngPlace /= 20;
  }
  final cellLat = latPlace * 20;
  final cellLng = lngPlace * 20;
  return (
    lat: lat + cellLat / 2 - 90,
    lng: lng + cellLng / 2 - 180,
  );
}

String? _recoverNearest(String shortCode, double refLat, double refLng) {
  final plus = shortCode.indexOf('+');
  if (plus < 0 || plus >= 8) return shortCode;
  final fullRef = _olcEncode(refLat, refLng);
  if (fullRef == null) return null;
  final prefixLen = 8 - plus;
  return '${fullRef.substring(0, prefixLen)}$shortCode';
}

String? _olcEncode(double lat, double lng) {
  var latRemaining = (lat + 90).clamp(0.0, 180.0 - 1e-10);
  var lngRemaining = (lng + 180).clamp(0.0, 360.0 - 1e-10);
  final chars = StringBuffer();
  var latRes = 20.0;
  var lngRes = 20.0;
  for (var pair = 0; pair < 5; pair++) {
    final latD = (latRemaining / latRes).floor().clamp(0, 19);
    final lngD = (lngRemaining / lngRes).floor().clamp(0, 19);
    chars.write(_olcAlpha[latD]);
    chars.write(_olcAlpha[lngD]);
    latRemaining -= latD * latRes;
    lngRemaining -= lngD * lngRes;
    latRes /= 20;
    lngRes /= 20;
    if (pair == 3) chars.write('+');
  }
  return chars.toString();
}
