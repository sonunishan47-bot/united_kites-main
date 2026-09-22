import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Phones block GPS on http://192.168... . localhost and https are allowed.
bool get deviceGpsAllowed {
  if (!kIsWeb) return true;
  final uri = Uri.base;
  final host = uri.host.toLowerCase();
  final local = host == 'localhost' || host == '127.0.0.1' || host == '[::1]' || host == '::1';
  return uri.scheme == 'https' || local;
}

enum LocationBlock { none, insecure, denied, off, failed }

class DeviceFix {
  const DeviceFix(this.position, this.block);

  final Position? position;
  final LocationBlock block;
}

/// Requests GPS. When [explain] is true, a blocked read shows a dialog instead
/// of failing quietly. [onSelectMap] is the fallback offered in that dialog.
Future<DeviceFix> requestDevicePosition(
  BuildContext context, {
  bool explain = true,
  Future<void> Function()? onSelectMap,
}) async {
  if (!deviceGpsAllowed) {
    if (explain && context.mounted) {
      await _explain(context, LocationBlock.insecure, onSelectMap);
    }
    return const DeviceFix(null, LocationBlock.insecure);
  }
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (explain && context.mounted) {
        await _explain(context, LocationBlock.off, onSelectMap);
      }
      return const DeviceFix(null, LocationBlock.off);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (explain && context.mounted) {
        await _explain(context, LocationBlock.denied, onSelectMap);
      }
      return const DeviceFix(null, LocationBlock.denied);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).timeout(const Duration(seconds: 12));
    return DeviceFix(pos, LocationBlock.none);
  } catch (_) {
    if (explain && context.mounted) {
      await _explain(context, LocationBlock.failed, onSelectMap);
    }
    return const DeviceFix(null, LocationBlock.failed);
  }
}

Future<void> _explain(
  BuildContext context,
  LocationBlock block,
  Future<void> Function()? onSelectMap,
) {
  final host = Uri.base.host;
  final message = switch (block) {
    LocationBlock.insecure =>
      'This phone opened the app at http://$host. Mobile browsers only share GPS on https:// or localhost. Select the shop on the map, or paste a Google Maps link.',
    LocationBlock.denied =>
      'Location permission is blocked. In the browser address bar, open site settings and allow Location. You can also select the shop on the map or paste a Maps link.',
    LocationBlock.off =>
      'Turn on GPS / location services, then try again. Or select the shop on the map.',
    LocationBlock.failed =>
      'Could not read GPS. Select the shop on the map, or paste a Google Maps link.',
    LocationBlock.none => '',
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Location unavailable'),
        content: Text(message),
        actions: [
          if (onSelectMap != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onSelectMap();
              },
              child: const Text('Select on Map'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
