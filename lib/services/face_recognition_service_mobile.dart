import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  bool _isInitialized = false;
  String? _modelInitError;

  bool get isModelLoaded => _interpreter != null;
  String? get modelInitError => _modelInitError;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Face Detector ONLY on supported mobile platforms (Android/iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final options = FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.accurate,
        );
        _faceDetector = FaceDetector(options: options);
      } catch (e) {
        debugPrint('FaceRecognitionService: FaceDetector init error - $e');
      }
    }

    // Initialize TFLite Interpreter if available
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      debugPrint('FaceRecognitionService: TFLite MobileFaceNet model loaded successfully');
    } catch (e) {
      _modelInitError = e.toString();
      debugPrint('FaceRecognitionService: TFLite model load note ($e), using resilient biometric feature extractor');
    }
    _isInitialized = true;
  }

  Future<List<double>?> getFaceEmbedding(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      return await getFaceEmbeddingFromBytes(bytes, imagePath: imagePath);
    } catch (e) {
      debugPrint('FaceRecognitionService: Failed to read image file - $e');
      return null;
    }
  }

  Future<List<double>?> getFaceEmbeddingFromBytes(Uint8List bytes, {String? imagePath}) async {
    if (!_isInitialized) {
      await initialize();
    }

    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      debugPrint('FaceRecognitionService: Could not decode image bytes');
      return null;
    }

    // CRITICAL: On iOS (iPhone 14 Pro etc.), camera pictures are captured in landscape sensor buffer with EXIF orientation (tag 6).
    // Without bakeOrientation, the decoded pixels are rotated 90° sideways, causing:
    // 1) ML Kit bounding box coordinates to misalign with the pixel buffer.
    // 2) MobileFaceNet to receive a sideways face on iOS vs an upright face on Android, resulting in mismatched embeddings!
    originalImage = img.bakeOrientation(originalImage);

    img.Image faceCrop;

    // 1. Try ML Kit face detector on Android/iOS if available
    if (_faceDetector != null && imagePath != null) {
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final faces = await _faceDetector!.processImage(inputImage);
        if (faces.isNotEmpty) {
          final face = faces.first;
          final boundingBox = face.boundingBox;
          // Add 12% padding around the bounding box so the entire face (chin/forehead/cheeks) is captured
          final padX = (boundingBox.width * 0.12).toInt();
          final padY = (boundingBox.height * 0.12).toInt();
          final x = max(0, boundingBox.left.toInt() - padX);
          final y = max(0, boundingBox.top.toInt() - padY);
          final width = min(originalImage.width - x, boundingBox.width.toInt() + (padX * 2));
          final height = min(originalImage.height - y, boundingBox.height.toInt() + (padY * 2));
          if (width > 20 && height > 20) {
            faceCrop = img.copyCrop(originalImage, x: x, y: y, width: width, height: height);
          } else {
            faceCrop = _smartCenterCrop(originalImage);
          }
        } else {
          faceCrop = _smartCenterCrop(originalImage);
        }
      } catch (e) {
        debugPrint('FaceRecognitionService: ML Kit process error: $e');
        faceCrop = _smartCenterCrop(originalImage);
      }
    } else {
      faceCrop = _smartCenterCrop(originalImage);
    }

    // Resize to 112x112 as required by MobileFaceNet / feature extraction
    final img.Image resizedFace = img.copyResize(faceCrop, width: 112, height: 112);

    // 2. Try TFLite model inference if loaded
    if (_interpreter != null) {
      try {
        var inputTensor = _imageToNestedList(resizedFace, 112);
        var output = List.generate(1, (i) => List.filled(192, 0.0));
        _interpreter!.run(inputTensor, output);
        return _l2Normalize(output[0]);
      } catch (e) {
        debugPrint('FaceRecognitionService: TFLite run error ($e), fallback to spatial feature extraction');
      }
    }

    // 3. Fallback: Extract pure Dart 192-dimensional spatial & gradient biometric features
    debugPrint('FaceRecognitionService: WARNING - TFLite interpreter not available. Using pure Dart spatial biometric fallback.');
    return _extractSpatialGradientFeatures(resizedFace);
  }

  img.Image _smartCenterCrop(img.Image image) {
    final size = (min(image.width, image.height) * 0.85).toInt();
    final x = (image.width - size) ~/ 2;
    // Offset slightly higher for facial framing in selfies / portrait photos
    final y = max(0, ((image.height - size) * 0.35).toInt());
    return img.copyCrop(
      image,
      x: max(0, x),
      y: y,
      width: min(size, image.width - x),
      height: min(size, image.height - y),
    );
  }

  List<List<List<List<double>>>> _imageToNestedList(img.Image image, int size) {
    var nestedList = List.generate(1, (_) => 
      List.generate(size, (y) => 
        List.generate(size, (x) {
          var pixel = image.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        })
      )
    );
    return nestedList;
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

  // Calculate Euclidean Distance
  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length || e1.isEmpty) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  // Close resources
  void dispose() {
    _faceDetector?.close();
    _interpreter?.close();
  }
}
