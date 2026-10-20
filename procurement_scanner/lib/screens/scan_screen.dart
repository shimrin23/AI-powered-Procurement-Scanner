import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:gap/gap.dart';
import '../theme.dart';
import 'verify_screen.dart';

/// Screen 2 — Camera viewfinder → capture → crop → proceed to Verify.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialising = true;
  bool _capturing = false;
  bool _cropping = false;
  String? _errorMessage;
  File? _capturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (_cropping) return;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initialising = true;
      _errorMessage = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device.';
          _initialising = false;
        });
        return;
      }
      final ctrl = CameraController(
        _cameras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _initialising = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not access camera: $e';
        _initialising = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final xFile = await ctrl.takePicture();
      final original = File(xFile.path);
      if (!mounted) return;
      setState(() {
        _capturedFile = original;
        _capturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not capture photo: $e';
        _capturing = false;
      });
    }
  }

  Future<void> _cropAndContinue() async {
    final original = _capturedFile;
    if (original == null || _cropping) return;

    setState(() => _cropping = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: original.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Document',
            toolbarColor: AppTheme.surface,
            toolbarWidgetColor: AppTheme.textPrimary,
            backgroundColor: AppTheme.background,
            activeControlsWidgetColor: AppTheme.primary,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
        ],
      );

      if (cropped == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyScreen(
            originalImage: original,
            croppedImage: File(cropped.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not crop document: $e')),
      );
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  void _retake() => setState(() => _capturedFile = null);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan Document'),
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _capturedFile != null ? _previewBody() : _cameraBody(),
    );
  }

  // ── Camera viewfinder ──────────────────────────────────────────────────────

  Widget _cameraBody() {
    if (_initialising) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            Gap(16),
            Text('Initialising camera…',
                style: TextStyle(color: AppTheme.textSecond)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.textMuted, size: 64),
              const Gap(16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textSecond, fontSize: 14),
              ),
              const Gap(24),
              ElevatedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final ctrl = _controller!;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview fills the available space.
              CameraPreview(ctrl),

              // Document guide overlay.
              _DocumentGuideOverlay(),

              // Capturing indicator.
              if (_capturing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
            ],
          ),
        ),

        // Bottom controls.
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            children: [
              Text(
                'Position the document within the guide and capture.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const Gap(20),
              GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_rounded,
                      color: AppTheme.primaryDark, size: 34),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Preview after capture ──────────────────────────────────────────────────

  Widget _previewBody() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: Image.file(
              _capturedFile!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cropping ? null : _retake,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Retake Photo'),
                ),
              ),
              const Gap(12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cropping ? null : _cropAndContinue,
                  icon: const Icon(Icons.crop_rounded),
                  label: const Text('Crop & Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Document Guide Overlay ─────────────────────────────────────────────────────

class _DocumentGuideOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GuideLinePainter());
  }
}

class _GuideLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const margin = 24.0;
    const cornerLen = 24.0;
    final rect = Rect.fromLTRB(
      margin,
      margin * 2,
      size.width - margin,
      size.height - margin * 2,
    );
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw four corner brackets.
    final List<List<Offset>> corners = [
      [
        rect.topLeft,
        Offset(rect.left + cornerLen, rect.top),
        Offset(rect.left, rect.top + cornerLen)
      ],
      [
        rect.topRight,
        Offset(rect.right - cornerLen, rect.top),
        Offset(rect.right, rect.top + cornerLen)
      ],
      [
        rect.bottomLeft,
        Offset(rect.left + cornerLen, rect.bottom),
        Offset(rect.left, rect.bottom - cornerLen)
      ],
      [
        rect.bottomRight,
        Offset(rect.right - cornerLen, rect.bottom),
        Offset(rect.right, rect.bottom - cornerLen)
      ],
    ];

    for (final c in corners) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
