import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';

class UploadController extends ChangeNotifier {
  UploadController({
    required this.photoApiService,
    this.initialFile,
    this.friends = const <FriendListItem>[],
  }) : captionController = TextEditingController();

  final PhotoApiService photoApiService;
  final XFile? initialFile;
  final List<FriendListItem> friends;
  final TextEditingController captionController;

  CameraController? _cameraController;
  Future<void>? _initializationFuture;
  XFile? _capturedFile;
  bool _isCapturing = false;
  bool _isUploading = false;
  String? _errorMessage;
  bool _shareWithEveryone = true;
  final Set<String> _selectedFriendIds = <String>{};

  bool _initialized = false;
  bool _disposed = false;

  CameraController? get cameraController => _cameraController;
  Future<void>? get initializationFuture => _initializationFuture;
  XFile? get capturedFile => _capturedFile;
  bool get isCapturing => _isCapturing;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  bool get shareWithEveryone => _shareWithEveryone;
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (initialFile != null) {
      _capturedFile = initialFile;
      _notify();
      return;
    }
    await _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _errorMessage = 'No camera available on this device.';
        _notify();
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
      _initializationFuture = initialization;
      _errorMessage = null;
      _notify();
      await initialization;
      _notify();
    } catch (_) {
      _errorMessage = 'Unable to start the camera. Please check permissions.';
      _notify();
    }
  }

  Future<void> capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_isCapturing) {
      return;
    }

    _isCapturing = true;
    _errorMessage = null;
    _notify();

    try {
      final file = await controller.takePicture();
      _capturedFile = file;
      _notify();
    } catch (_) {
      _errorMessage = 'Failed to capture photo. Please try again.';
      _notify();
    } finally {
      _isCapturing = false;
      _notify();
    }
  }

  void toggleShareWithEveryone(bool value) {
    _shareWithEveryone = value;
    if (value) {
      _selectedFriendIds.clear();
    }
    _notify();
  }

  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    _notify();
  }

  void reset() {
    _capturedFile = null;
    captionController.clear();
    _errorMessage = null;
    _shareWithEveryone = true;
    _selectedFriendIds.clear();
    _notify();
    if (_cameraController == null) {
      _setupCamera();
    }
  }

  Future<UploadResult> uploadPhoto() async {
    final captured = _capturedFile;
    if (captured == null || _isUploading) {
      return const UploadResult(
        success: false,
        message: 'Capture a photo first.',
      );
    }

    List<String>? friendIds;
    if (!_shareWithEveryone) {
      friendIds = _selectedFriendIds.toList()..sort();
      if (friendIds.isEmpty) {
        _errorMessage = 'Select at least one friend to share with.';
        _notify();
        return const UploadResult(
          success: false,
          message: 'Select at least one friend to share with.',
        );
      }
    }

    _isUploading = true;
    _errorMessage = null;
    _notify();

    try {
      final caption = captionController.text.trim();
      final response = await photoApiService.uploadPhoto(
        image: File(captured.path),
        caption: caption.isEmpty ? null : caption,
        friendIds: friendIds,
      );
      return UploadResult(success: true, message: 'Upload successful.', photo: response);
    } catch (_) {
      _errorMessage = 'Upload failed. Please try again.';
      _notify();
      return const UploadResult(success: false, message: 'Upload failed. Please try again.');
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cameraController?.dispose();
    captionController.dispose();
    super.dispose();
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

class UploadResult {
  const UploadResult({
    required this.success,
    required this.message,
    this.photo,
  });

  final bool success;
  final String message;
  final PhotoResponse? photo;
}
