import 'dart:typed_data';

/// A photo ready to upload: already compressed, EXIF and location removed by
/// the app before it gets here. Shared by the ID upload (Mohan) and the
/// listing photos (Srijan).
class ImageUpload {
  const ImageUpload({
    required this.bytes,
    this.fileName = 'photo.jpg',
    this.contentType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String fileName;

  /// One of image/jpeg, image/png, image/webp (the only types the buckets accept).
  final String contentType;
}
