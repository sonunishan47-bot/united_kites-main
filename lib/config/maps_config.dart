/// Google Maps API key for Android, iOS, and Web.
///
/// The Maps JavaScript SDK is not loaded while this is still the placeholder.
/// A placeholder script paints "API key" over the page and can freeze the
/// canvas. Turn-by-turn still opens
/// `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG`.
/// Pass `--dart-define=GOOGLE_MAPS_API_KEY=AIza...` when a real key is ready.
class MapsConfig {
  const MapsConfig._();

  static const apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY',
  );

  static bool get hasKey {
    final key = apiKey.trim();
    return key.startsWith('AIza') && key != 'YOUR_GOOGLE_MAPS_API_KEY';
  }

  static const riyadh = (lat: 24.7136, lng: 46.6753);
  static const initialZoom = 5.85;
}
