import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/device_location.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_shop_pin.dart';
import '../widgets/hd_map.dart';

class PickedShopLocation {
  const PickedShopLocation({required this.point, required this.label});

  final LatLng point;
  final String label;
}

/// Full-screen HD map to drop or drag a shop pin.
class MapPinPickerScreen extends StatefulWidget {
  const MapPinPickerScreen({super.key, this.initial});

  final LatLng? initial;

  static Future<PickedShopLocation?> open(BuildContext context, {LatLng? initial}) {
    return Navigator.of(context).push<PickedShopLocation>(
      MaterialPageRoute(
        builder: (_) => MapPinPickerScreen(initial: initial),
      ),
    );
  }

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  final _map = MapController();
  late LatLng _pin;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial ?? HdMapTiles.riyadh;
  }

  PickedShopLocation get _result => PickedShopLocation(
        point: _pin,
        label: '${_pin.latitude.toStringAsFixed(6)}, ${_pin.longitude.toStringAsFixed(6)}',
      );

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final fix = await requestDevicePosition(context);
      final pos = fix.position;
      if (pos == null || !mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = point);
      _map.move(point, 18);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select on map'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _result),
            child: const Text('Use This Location', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pin,
              initialZoom: 16.4,
              minZoom: 3,
              maxZoom: HdMapTiles.maxZoomFor(MapImagery.road),
              backgroundColor: const Color(0xFFD4E4F0),
              interactionOptions: HdMapTiles.interaction,
              onTap: (_, point) {
                _map.move(point, _map.camera.zoom);
                setState(() => _pin = point);
              },
              onPositionChanged: (camera, hasGesture) {
                if (!hasGesture) setState(() => _pin = camera.center);
              },
            ),
            children: [
              ...HdMapTiles.layers(context, MapImagery.road),
            ],
          ),
          const IgnorePointer(
            child: Center(child: GlowShopPin(selected: true, size: 26)),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_pin.latitude.toStringAsFixed(6)}, ${_pin.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('Use Current Location'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
                        onPressed: () => Navigator.pop(context, _result),
                        child: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
