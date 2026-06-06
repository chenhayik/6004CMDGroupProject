import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  // ── Pick from Camera ──
  Future<Uint8List?> pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,   // Compress to reduce API payload
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return null;       // User cancelled
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Camera error: $e');
      return null;
    }
  }

  // ── Pick from Gallery ──
  Future<Uint8List?> pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return null;       // User cancelled
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Gallery error: $e');
      return null;
    }
  }

  // ── Show source selection bottom sheet ──
  Future<Uint8List?> showPickerDialog(BuildContext context) async {
    Uint8List? result;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.camera_alt, color: Color(0xFF22C55E)),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use your camera'),
              onTap: () async {
                Navigator.pop(context);
                result = await pickFromCamera();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.photo_library, color: Color(0xFF378ADD)),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing photo'),
              onTap: () async {
                Navigator.pop(context);
                result = await pickFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    return result;
  }
}