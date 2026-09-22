import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../screens/map_pin_picker_screen.dart';
import '../services/device_location.dart';
import '../services/map_customers.dart';
import '../services/maps_link.dart';
import '../theme/app_theme.dart';

class CustomerLocationSection extends StatefulWidget {
  const CustomerLocationSection({
    super.key,
    required this.lat,
    required this.lng,
    required this.coordInput,
    required this.onChanged,
    this.address,
  });

  final TextEditingController lat;
  final TextEditingController lng;
  final TextEditingController coordInput;
  final TextEditingController? address;
  final VoidCallback onChanged;

  @override
  State<CustomerLocationSection> createState() => _CustomerLocationSectionState();
}

class _CustomerLocationSectionState extends State<CustomerLocationSection> {
  Timer? _parseTimer;
  bool _readingLink = false;

  LatLng get _current => LatLng(
        double.tryParse(widget.lat.text) ?? 24.7136,
        double.tryParse(widget.lng.text) ?? 46.6753,
      );

  @override
  void dispose() {
    _parseTimer?.cancel();
    super.dispose();
  }

  void _apply(double a, double b, {String? place}) {
    widget.lat.text = a.toStringAsFixed(6);
    widget.lng.text = b.toStringAsFixed(6);
    final coords = '${a.toStringAsFixed(6)}, ${b.toStringAsFixed(6)}';
    widget.coordInput.text = coords;
    final label = place?.trim() ?? '';
    final address = widget.address;
    if (address != null) {
      if (label.isNotEmpty) {
        address.text = label;
      } else if (address.text.trim().isEmpty) {
        address.text = coords;
      }
    }
    widget.onChanged();
  }

  Future<void> _gps() async {
    final fix = await requestDevicePosition(
      context,
      onSelectMap: _pickMap,
    );
    final pos = fix.position;
    if (pos == null || !mounted) return;
    _apply(pos.latitude, pos.longitude);
  }

  Future<void> _pickMap() async {
    final picked = await MapPinPickerScreen.open(context, initial: _current);
    if (picked == null || !mounted) return;
    _apply(picked.point.latitude, picked.point.longitude, place: picked.label);
  }

  void _scheduleParse(String value) {
    _parseTimer?.cancel();
    _parseTimer = Timer(
      const Duration(milliseconds: 400),
      () => _resolve(value, interactive: false),
    );
  }

  Future<void> _resolve(String raw, {bool interactive = true}) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    var parsed = parseShopCoordinates(text);
    if (parsed == null && isShortMapsLink(text)) {
      if (mounted) setState(() => _readingLink = true);
      final expanded = await expandMapsUrl(text);
      if (!mounted) return;
      setState(() => _readingLink = false);
      if (expanded != null) parsed = parseShopCoordinates(expanded);
      if (parsed == null) {
        await _linkHelp(
          'This short Google link cannot be read in the browser. Open it, copy the full maps address from the browser bar, and paste that. Or select the shop on the map.',
        );
        return;
      }
    }
    if (parsed == null) {
      if (interactive && text.contains('://') && mounted) {
        await _linkHelp(
          'No coordinates were found in that link. Paste a full Google Maps URL that contains the pin, or select the shop on the map.',
        );
      }
      return;
    }
    _apply(parsed.lat, parsed.lng, place: parsed.address);
  }

  Future<void> _linkHelp(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Maps link'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _pickMap();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'Shop location',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste a Google Maps link, Plus Code, or coordinates. Latitude, longitude, and address fill in automatically.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
            ),
            onPressed: _gps,
            icon: const Icon(Icons.my_location),
            label: const Text('Save Current Location'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _pickMap,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Select on Map'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.coordInput,
          decoration: InputDecoration(
            labelText: 'Manual location (Maps URL / pin / pincode)',
            hintText: 'https://maps.google.com/...  or  24.7136, 46.6753',
            suffixIcon: _readingLink
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Apply',
                    onPressed: () => _resolve(widget.coordInput.text, interactive: true),
                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.navy),
                  ),
          ),
          onChanged: _scheduleParse,
          onSubmitted: _resolve,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.lat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude'),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.lng,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude'),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
