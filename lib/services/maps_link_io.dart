import 'dart:io';

/// Follows a short Google Maps link and returns the final URL.
Future<String?> expandMapsUrl(String url) async {
  final client = HttpClient();
  try {
    final start = Uri.tryParse(url.trim());
    if (start == null || !start.hasScheme) return null;
    var current = start;
    for (var hop = 0; hop < 5; hop++) {
      final request = await client.getUrl(current).timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 8));
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.trim().isEmpty) return current.toString();
      final parsed = Uri.tryParse(location);
      current = (parsed != null && parsed.hasScheme) ? parsed : current.resolve(location);
    }
    return current.toString();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
