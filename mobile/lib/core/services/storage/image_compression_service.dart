import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Compresse une image vers une taille cible (par défaut ~40 Ko, pour les
/// photos de produits — jusqu'à 50 par boutique, donc on garde ça léger).
/// Réduit qualité + dimensions par paliers jusqu'à atteindre la cible ou
/// jusqu'à la qualité minimale acceptable.
class ImageCompressionService {
  Future<File> compress(File file, {int targetSizeBytes = 40 * 1024}) async {
    int quality = 80;
    int minSide = 900;
    File current = file;

    for (int attempt = 0; attempt < 6; attempt++) {
      final compressed = await _compressOnce(current, quality: quality, minSide: minSide);
      final size = await compressed.length();
      if (size <= targetSizeBytes || quality <= 20) return compressed;
      current = compressed;
      quality = (quality - 15).clamp(20, 100);
      minSide = (minSide * 0.8).round();
    }
    return current;
  }

  Future<File> _compressOnce(File file, {required int quality, required int minSide}) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/livra_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: minSide,
      minHeight: minSide,
      format: CompressFormat.jpeg,
    );
    return result != null ? File(result.path) : file;
  }
}
