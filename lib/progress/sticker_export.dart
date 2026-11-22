import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Receives the exported PNG bytes and a file name without extension.
typedef StickerAction = Future<void> Function(Uint8List png, String name);

class StickerExportException implements Exception {
  const StickerExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Saves the PNG to the photo library, asking for access only if needed.
Future<void> saveStickerToGallery(Uint8List png, String name) async {
  try {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw const StickerExportException(
        'Photo access was denied. Allow it in Settings to save stickers.',
      );
    }
    await Gal.putImageBytes(png, name: name);
  } on GalException catch (error) {
    throw StickerExportException(error.type.message);
  } on MissingPluginException {
    throw const StickerExportException(
      'Saving to photos is not supported on this device.',
    );
  } on UnsupportedError {
    throw const StickerExportException(
      'Saving to photos is not supported on this device.',
    );
  }
}

/// Opens the native share sheet with the PNG file. Instagram, WhatsApp and
/// other apps listed there let the user place it on a Story themselves.
/// share_plus writes the file to its own cache folder and clears it on the
/// next share.
Future<void> shareSticker(
  Uint8List png,
  String name, {
  Rect? origin,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['$name.png'],
        sharePositionOrigin: origin,
      ),
    );
  } on MissingPluginException {
    throw const StickerExportException(
      'Sharing is not supported on this device.',
    );
  } on PlatformException catch (error) {
    throw StickerExportException(error.message ?? 'Sharing failed.');
  }
}
