import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class FaceRecognitionService {
  Future<void> initialize() async {
    debugPrint('FaceRecognitionService: Web pure Dart engine initialized');
  }

  Future<List<double>?> getFaceEmbedding(String imagePath) async {
    try {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://') || imagePath.startsWith('blob:')) {
        final resp = await http.get(Uri.parse(imagePath));
        return await getFaceEmbeddingFromBytes(resp.bodyBytes);
      }
      return null;
    } catch (e) {
      debugPrint('FaceRecognitionService (Web): Error getting embedding from URL: $e');
      return null;
    }
  }

  Future<List<double>?> getFaceEmbeddingFromBytes(Uint8List bytes, {String? imagePath}) async {
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    final faceCrop = _smartCenterCrop(originalImage);
    final resizedFace = img.copyResize(faceCrop, width: 112, height: 112);
    return _extractSpatialGradientFeatures(resizedFace);
  }

  img.Image _smartCenterCrop(img.Image image) {
    final size = (min(image.width, image.height) * 0.85).toInt();
    final x = (image.width - size) ~/ 2;
    final y = max(0, ((image.height - size) * 0.35).toInt());
    return img.copyCrop(
      image,
      x: max(0, x),
      y: y,
      width: min(size, image.width - x),
      height: min(size, image.height - y),
    );
  }

  List<double> _extractSpatialGradientFeatures(img.Image faceImage) {
    const int gridSize = 8;
    final int cellW = faceImage.width ~/ gridSize;
    final int cellH = faceImage.height ~/ gridSize;
    List<double> features = [];

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        double sumLum = 0.0;
        double sumGradX = 0.0;
        double sumGradY = 0.0;
        int count = 0;

        final startX = gx * cellW;
        final startY = gy * cellH;

        for (int y = startY; y < startY + cellH && y < faceImage.height; y++) {
          for (int x = startX; x < startX + cellW && x < faceImage.width; x++) {
            final p = faceImage.getPixel(x, y);
            final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
            sumLum += lum;

            if (x > 0 && x < faceImage.width - 1) {
              final pLeft = faceImage.getPixel(x - 1, y);
              final pRight = faceImage.getPixel(x + 1, y);
              final lumL = (0.299 * pLeft.r + 0.587 * pLeft.g + 0.114 * pLeft.b) / 255.0;
              final lumR = (0.299 * pRight.r + 0.587 * pRight.g + 0.114 * pRight.b) / 255.0;
              sumGradX += (lumR - lumL).abs();
            }

            if (y > 0 && y < faceImage.height - 1) {
              final pUp = faceImage.getPixel(x, y - 1);
              final pDown = faceImage.getPixel(x, y + 1);
              final lumU = (0.299 * pUp.r + 0.587 * pUp.g + 0.114 * pUp.b) / 255.0;
              final lumD = (0.299 * pDown.r + 0.587 * pDown.g + 0.114 * pDown.b) / 255.0;
              sumGradY += (lumD - lumU).abs();
            }

            count++;
          }
        }

        if (count > 0) {
          features.add(sumLum / count);
          features.add(sumGradX / count);
          features.add(sumGradY / count);
        } else {
          features.addAll([0.0, 0.0, 0.0]);
        }
      }
    }

    return _l2Normalize(features);
  }

  List<double> _l2Normalize(List<double> vector) {
    double sumSq = 0.0;
    for (var v in vector) {
      sumSq += v * v;
    }
    final norm = sqrt(sumSq);
    if (norm < 1e-8) return vector;
    return vector.map((v) => v / norm).toList();
  }

  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length || e1.isEmpty) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  void dispose() {}
}
