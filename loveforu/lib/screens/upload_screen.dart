import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.photoApiService});

  final PhotoApiService photoApiService;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  CameraController? _cameraController;
  Future<void>? _initializationFuture;
  XFile? _capturedFile;
  bool _isCapturing = false;
  bool _isUploading = false;
  String? _errorMessage;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera available on this device.';
        });
        return;
      }

      CameraDescription selected = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selected = camera;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      final initialization = controller.initialize();
      setState(() {
        _initializationFuture = initialization;
        _errorMessage = null;
      });
      await initialization;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to start the camera. Please check permissions.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to capture photo. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    final captured = _capturedFile;
    if (captured == null || _isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final caption = _captionController.text.trim();
      final response = await widget.photoApiService.uploadPhoto(
        image: File(captured.path),
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      Navigator.of(context).pop(response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Upload failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _captionController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildPreview(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_capturedFile != null)
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption (optional)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading
                            ? null
                            : _capturedFile != null
                                ? _retake
                                : () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_capturedFile != null ? 'Retake' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : _capturedFile != null
                                ? _uploadPhoto
                                : _capturePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_capturedFile != null ? 'Upload' : 'Capture'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_capturedFile != null) {
      return Image.file(
        File(_capturedFile!.path),
        fit: BoxFit.cover,
      );
    }

    final future = _initializationFuture;
    final controller = _cameraController;

    if (future == null || controller == null) {
      if (_errorMessage != null) {
        return _buildErrorPlaceholder();
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && controller.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (_isCapturing)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        } else if (snapshot.hasError) {
          return _buildErrorPlaceholder();
        } else {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Text(
          _errorMessage ?? 'Camera preview not available.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
