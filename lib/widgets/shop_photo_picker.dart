import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ShopPhotoPicker extends StatelessWidget {
  const ShopPhotoPicker({
    super.key,
    required this.photoBase64,
    required this.onChanged,
  });

  final String photoBase64;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64);
      } catch (_) {
        bytes = null;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Shop Photo', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (bytes != null) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await _choose(source);
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      if (bytes.isEmpty) {
        _toast(context, 'That photo was empty. Try another.');
        return;
      }
      if (bytes.length > 900000) {
        _toast(context, 'Photo is too large. Take a smaller one.');
        return;
      }
      onChanged(base64Encode(bytes));
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, 'Camera or files are blocked. Allow camera access, or use Gallery.');
    }
  }

  Future<XFile?> _choose(ImageSource source) async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 60,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (source != ImageSource.camera) rethrow;
      if (kIsWeb) {
        return picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          imageQuality: 60,
          requestFullMetadata: false,
        );
      }
      rethrow;
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
