/// Browsers cannot read Google's short-link redirect (maps.app.goo.gl) because
/// that host does not allow cross-origin access. The full Maps URL still parses.
Future<String?> expandMapsUrl(String url) async => null;
