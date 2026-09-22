import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Road, satellite, hybrid, and terrain imagery.
///
/// Tiles are requested at the screen's pixel density (`@2x` where the server
/// supports it, otherwise four native tiles combined) so a 4K display is not
/// painted from a single 256px image. The Google Maps JavaScript SDK is not
/// injected while [MapsConfig] still holds the placeholder key — that script
/// paints an API-key error over the canvas.
enum MapImagery { road, satellite, hybrid, terrain }

class HdMapTiles {
  const HdMapTiles._();

  static const ksaCenter = LatLng(23.8859, 45.0792);
  static const riyadh = LatLng(24.7136, 46.6753);
  static const initialZoom = 5.6;

  /// Pinch-zoom, pan, and two-finger rotation. Rotation stays on so mobile
  /// Safari can twist the map the same way the Google SDK does.
  static const interaction = InteractionOptions(
    flags: InteractiveFlag.all,
    enableMultiFingerGestureRace: true,
  );

  static double maxZoomFor(MapImagery imagery) =>
      imagery == MapImagery.terrain ? 17 : 20;

  static String attributionFor(MapImagery imagery) => switch (imagery) {
        MapImagery.road => '© OpenStreetMap contributors',
        MapImagery.satellite => 'Tiles © Esri',
        MapImagery.hybrid => 'Tiles © Esri © OpenStreetMap',
        MapImagery.terrain => '© OpenTopoMap © OpenStreetMap',
      };

  static List<Widget> layers(BuildContext context, MapImagery imagery) {
    final retina = RetinaMode.isHighDensity(context);
    return switch (imagery) {
      MapImagery.road => [_road(retina)],
      MapImagery.satellite => [_satellite(retina)],
      MapImagery.hybrid => [_satellite(retina), _labels(retina)],
      MapImagery.terrain => [_terrain(retina)],
    };
  }

  static TileLayer _road(bool retina) => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.unitedkites.billing',
        retinaMode: retina,
        maxZoom: 20,
        maxNativeZoom: 19,
        keepBuffer: 4,
        panBuffer: 2,
      );

  static TileLayer _labels(bool retina) => TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.unitedkites.billing',
        retinaMode: retina,
        maxZoom: 20,
        maxNativeZoom: 19,
        keepBuffer: 4,
        panBuffer: 2,
      );

  static TileLayer _satellite(bool retina) => TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.unitedkites.billing',
        retinaMode: retina,
        maxZoom: 20,
        maxNativeZoom: 19,
        keepBuffer: 4,
        panBuffer: 2,
      );

  static TileLayer _terrain(bool retina) => TileLayer(
        urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.unitedkites.billing',
        retinaMode: retina,
        maxZoom: 17,
        maxNativeZoom: 17,
        keepBuffer: 3,
        panBuffer: 1,
      );
}
