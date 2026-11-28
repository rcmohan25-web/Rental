import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

enum PhotoSource { camera, gallery }

/// Takes or picks one photo and returns it compressed (about 1080 px, under
/// about 300 KB, JPEG, EXIF and location removed). Features use this through
/// [imageSelectorProvider], so tests can replace it. Owner: Mohan.
abstract class ImageSelector {
  /// Null when the user cancels. Throws AppException IMAGE_TOO_LARGE when the
  /// photo is still above the 5 MB upload limit after compression.
  Future<ImageUpload?> pick(PhotoSource source, {bool frontCamera = false});
}

class DeviceImageSelector implements ImageSelector {
  DeviceImageSelector({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<ImageUpload?> pick(
    PhotoSource source, {
    bool frontCamera = false,
  }) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice:
          frontCamera ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (file == null) return null;
    final bytes = await _compress(await file.readAsBytes());
    if (bytes.length > AppConstants.maxUploadBytes) {
      throw const AppException(
        'This photo is too large. Please choose a smaller one.',
        code: 'IMAGE_TOO_LARGE',
      );
    }
    return ImageUpload(bytes: bytes);
  }

  /// JPEG at falling quality until it is small enough. Re-encoding also drops
  /// the EXIF block, which holds the location.
  Future<Uint8List> _compress(Uint8List raw) async {
    var quality = 80;
    while (true) {
      final out = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: AppConstants.targetImageLongSide,
        minHeight: AppConstants.targetImageLongSide,
        quality: quality,
      );
      if (out.length <= AppConstants.targetImageBytes || quality <= 40) {
        return out;
      }
      quality -= 15;
    }
  }
}

final imageSelectorProvider = Provider<ImageSelector>(
  (ref) => DeviceImageSelector(),
);
