import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../services/face_recognition_service.dart';
import '../providers/attendance_provider.dart';

class FaceAuthScreen extends StatefulWidget {
  final List<double>? targetEmbedding; // If provided, verify against this single embedding
  final List<CompanyEmployee>? matchEmployees; // If provided, identify and match against enrolled employees
  final String title;
  final bool checkForDuplicate; // If true, checks provider for duplicate face before returning
  final String? excludeEmployeeId; // Employee ID to exclude when checking duplicates

  const FaceAuthScreen({
    super.key,
    this.targetEmbedding,
    this.matchEmployees,
    this.title = 'Face Authentication',
    this.checkForDuplicate = false,
    this.excludeEmployeeId,
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  final FaceRecognitionService _faceService = FaceRecognitionService();

  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isErrorMessage = false;
  bool _isTorchOn = false;
  String? _initError;
  String _statusMessage = 'Position your face within the frame';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _initError = null;
        _statusMessage = 'Starting camera...';
      });

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _statusMessage = 'Please ensure a camera is available.';
        });
        return;
      }

      // Default to front camera if available
      int frontIdx = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _currentCameraIndex = frontIdx != -1 ? frontIdx : 0;

      await _setupCameraController(_availableCameras[_currentCameraIndex]);
      await _faceService.initialize();

      if (mounted) {
        setState(() {
          _statusMessage = 'Position your face within the frame';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Camera error: $e';
          _statusMessage = 'Please check camera permissions and retry.';
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<void> _toggleCamera() async {
    if (_availableCameras.length < 2 || _isProcessing || _isSuccess) return;
    HapticFeedback.lightImpact();
    final nextIdx = (_currentCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _currentCameraIndex = nextIdx;
      _isTorchOn = false;
      _statusMessage = 'Switching camera...';
    });
    try {
      await _setupCameraController(_availableCameras[_currentCameraIndex]);
      if (mounted) {
        setState(() {
          _statusMessage = 'Position your face within the frame';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isErrorMessage = true;
          _statusMessage = 'Could not switch camera: $e';
        });
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing ||
        _isSuccess) {
      return;
    }
    try {
      HapticFeedback.lightImpact();
      final targetMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(targetMode);
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      debugPrint('Torch toggle failed: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing ||
        _isSuccess) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isProcessing = true;
      _isErrorMessage = false;
      _statusMessage = 'Verifying face...';
    });

    try {
      final XFile file = await _controller!.takePicture();
      await _processImagePath(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isErrorMessage = true;
          _statusMessage = 'Error taking photo: $e';
          _isProcessing = false;
        });
        HapticFeedback.vibrate();
      }
    }
  }

  Future<void> _processImagePath(String imagePath) async {
    try {
      final embedding = await _faceService.getFaceEmbedding(imagePath);

      if (embedding == null) {
        if (mounted) {
          setState(() {
            _isErrorMessage = true;
            _statusMessage = 'No face detected. Please try again.';
            _isProcessing = false;
          });
          HapticFeedback.vibrate();
        }
        return;
      }

      // Case 1: Identification / Login Mode (Match against multiple enrolled employees)
      if (widget.matchEmployees != null && widget.matchEmployees!.isNotEmpty) {
        CompanyEmployee? bestMatch;
        double minDistance = 999.0;

        for (final emp in widget.matchEmployees!) {
          if (emp.faceEmbedding == null || emp.faceEmbedding!.isEmpty) continue;
          final dist =
              _faceService.calculateEuclideanDistance(emp.faceEmbedding!, embedding);
          debugPrint('Matching against ${emp.name}: distance = $dist');
          if (dist < minDistance) {
            minDistance = dist;
            bestMatch = emp;
          }
        }

        // Threshold for MobileFaceNet is ~1.05
        if (bestMatch != null && minDistance < 1.05) {
          final matchedEmployee = bestMatch;
          if (!mounted) return;
          setState(() {
            _isSuccess = true;
            _isProcessing = false;
            _statusMessage = 'Welcome, ${matchedEmployee.name}';
          });
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.pop(context, matchedEmployee);
          return;
        } else {
          if (mounted) {
            setState(() {
              _isErrorMessage = true;
              _statusMessage = 'Face not recognized. Please try again.';
              _isProcessing = false;
            });
            HapticFeedback.vibrate();
          }
          return;
        }
      }

      // Case 2: Verification Mode (Verify against target embedding)
      if (widget.targetEmbedding != null) {
        final double distance = _faceService.calculateEuclideanDistance(
          widget.targetEmbedding!,
          embedding,
        );
        debugPrint('Face verification distance: $distance');

        if (distance < 1.05) {
          if (!mounted) return;
          setState(() {
            _isSuccess = true;
            _isProcessing = false;
            _statusMessage = 'Identity verified';
          });
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.pop(context, true); // Verified successfully
          return;
        } else {
          if (mounted) {
            setState(() {
              _isErrorMessage = true;
              _statusMessage = 'Face did not match. Please try again.';
              _isProcessing = false;
            });
            HapticFeedback.vibrate();
          }
          return;
        }
      }

      // Case 3: Registration / Enrollment Mode (targetEmbedding == null and matchEmployees == null)
      if (widget.checkForDuplicate) {
        if (!mounted) return;
        final provider = Provider.of<AttendanceProvider>(context, listen: false);
        final duplicate = provider.findDuplicateFaceEmployee(
          embedding,
          excludeEmployeeId: widget.excludeEmployeeId,
        );
        if (duplicate != null) {
          if (mounted) {
            setState(() {
              _isErrorMessage = true;
              final template = provider.translate('duplicate_face_detected');
              _statusMessage = template.replaceAll('{name}', duplicate.name);
              _isProcessing = false;
            });
            HapticFeedback.vibrate();
          }
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _isProcessing = false;
        _statusMessage = 'Face enrolled successfully';
      });
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, embedding); // Return the List<double> face embedding
    } catch (e) {
      if (mounted) {
        setState(() {
          _isErrorMessage = true;
          _statusMessage = 'Authentication error: $e';
          _isProcessing = false;
        });
        HapticFeedback.vibrate();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (_isSuccess) return const Color(0xFF10B981); // Emerald green
    if (_isErrorMessage) return const Color(0xFFEF4444); // Red
    if (_isProcessing) return const Color(0xFF38BDF8); // Soft blue
    return Colors.white.withValues(alpha: 0.85); // Clean subtle white
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return _buildErrorState();
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Clean, proportional cutout dimensions
        final reticleWidth = (screenWidth * 0.72).clamp(240.0, 300.0);
        final reticleHeight = (screenHeight * 0.42).clamp(280.0, 370.0);
        const topBarHeight = 90.0;
        const bottomControlsHeight = 190.0;
        final availableHeight = screenHeight - topBarHeight - bottomControlsHeight;
        final reticleTop =
            topBarHeight + math.max(0.0, (availableHeight - reticleHeight) / 2);

        final reticleRect = Rect.fromLTWH(
          (screenWidth - reticleWidth) / 2,
          reticleTop,
          reticleWidth,
          reticleHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-screen Camera Viewfinder
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1,
                  height: _controller!.value.aspectRatio < 1
                      ? (1 / _controller!.value.aspectRatio)
                      : _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),

            // 2. Simple, Elegant Cutout Mask
            Positioned.fill(
              child: CustomPaint(
                painter: _SimpleCutoutPainter(
                  reticleRect: reticleRect,
                  borderColor: _borderColor,
                ),
              ),
            ),

            // 3. Clean Minimalist Top Navigation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back / Close Button
                      _buildCircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),

                      // Title
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),

                      // Right Action Controls (Flash & Camera Switch)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCircleButton(
                            icon: _isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
                            onTap: _toggleTorch,
                          ),
                          if (_availableCameras.length > 1) ...[
                            const SizedBox(width: 8),
                            _buildCircleButton(
                              icon: Icons.flip_camera_ios_rounded,
                              onTap: _toggleCamera,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Clean Bottom Status & Shutter Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status Text
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isErrorMessage
                              ? Colors.red.withValues(alpha: 0.25)
                              : (_isSuccess
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isErrorMessage
                                ? const Color(0xFFFCA5A5)
                                : (_isSuccess
                                    ? const Color(0xFF86EFAC)
                                    : Colors.white),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Minimalist Shutter Button
                      GestureDetector(
                        onTap: _captureAndProcess,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSuccess
                                  ? const Color(0xFF10B981)
                                  : Colors.white,
                            ),
                            child: Center(
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.black87),
                                      ),
                                    )
                                  : (_isSuccess
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.black87,
                                          size: 26,
                                        )),
                            ),
                          ),
                        ),
                      ),

                      // Optional Password link if login mode
                      if (widget.matchEmployees != null &&
                          widget.matchEmployees!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Sign in with password',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              _initError ?? 'Camera Unavailable',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry Camera'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple, elegant rounded cutout mask without sci-fi lasers or ticks
class _SimpleCutoutPainter extends CustomPainter {
  final Rect reticleRect;
  final Color borderColor;

  _SimpleCutoutPainter({
    required this.reticleRect,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRRect = RRect.fromRectAndRadius(
      reticleRect,
      const Radius.circular(44),
    );

    // 1. Soft dark overlay outside the face frame
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(cutoutRRect);
    final maskPath = Path.combine(PathOperation.difference, fullScreenPath, cutoutPath);

    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Clean, smooth border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SimpleCutoutPainter oldDelegate) {
    return oldDelegate.reticleRect != reticleRect ||
        oldDelegate.borderColor != borderColor;
  }
}
